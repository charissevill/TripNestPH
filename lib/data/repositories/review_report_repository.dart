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

  Future<void> report({required String reviewId, required String userId, required String reason}) async {
    try {
      await _collection.add(ReviewReport(id: '', reviewId: reviewId, userId: userId, reason: reason, createdAt: DateTime.now()).toMap());
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
