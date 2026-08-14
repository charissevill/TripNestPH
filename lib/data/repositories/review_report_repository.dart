import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/review_report.dart';

/// Firestore access for the `review_reports` collection — traveler flags on
/// a review, surfaced to admins as a moderation queue.
class ReviewReportRepository {
  ReviewReportRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection(FirestorePaths.reviewReports);

  /// Deterministic `{reviewId}_{userId}` doc id rather than an auto-id — a
  /// second report from the same user against the same review lands on a
  /// doc that already exists, so firestore.rules' `allow update: if false`
  /// blocks it outright instead of letting one user file unlimited reports
  /// against the same review.
  Future<void> report({required String reviewId, required String userId, required String reason}) async {
    final ref = _collection.doc('${reviewId}_$userId');
    try {
      // Checked explicitly rather than letting the second write hit
      // firestore.rules' `allow update: if false` and surface as a generic
      // "you don't have permission to do that" — which reads like a bug,
      // not confirmation the report already went through.
      final existing = await ref.get();
      if (existing.exists) {
        throw const AppException('You\'ve already reported this review.');
      }
      await ref.set(ReviewReport(id: '', reviewId: reviewId, userId: userId, reason: reason, createdAt: DateTime.now()).toMap());
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Admin-only moderation queue, newest first.
  Stream<List<ReviewReport>> streamAllForAdmin() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ReviewReport.fromMap(d.id, d.data())).toList());
  }

  /// Clears a report once an admin has acted (or deliberately not acted) on
  /// the underlying review — reports don't auto-resolve.
  Future<void> dismiss(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
