import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/content_report.dart';

/// Firestore access for the `content_reports` collection — traveler flags on
/// a destination/restaurant/festival listing itself, surfaced to admins as
/// a moderation queue. Same shape as [ReviewReportRepository], kept
/// separate rather than generalized into one class since the two moderate
/// entirely different underlying content.
class ContentReportRepository {
  ContentReportRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection(FirestorePaths.contentReports);

  /// Deterministic `{targetType}_{targetId}_{userId}` doc id — a second
  /// report from the same user against the same listing lands on a doc that
  /// already exists, so `firestore.rules`' `allow update: if false` blocks
  /// it outright instead of letting one user file unlimited reports.
  Future<void> report({required String targetId, required ContentTargetType targetType, required String userId, required String reason}) async {
    final ref = _collection.doc('${targetType.name}_${targetId}_$userId');
    try {
      final existing = await ref.get();
      if (existing.exists) {
        throw const AppException('You\'ve already reported this listing.');
      }
      await ref.set(
        ContentReport(id: '', targetId: targetId, targetType: targetType, userId: userId, reason: reason, createdAt: DateTime.now()).toMap(),
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Admin-only moderation queue, newest first.
  Stream<List<ContentReport>> streamAllForAdmin() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ContentReport.fromMap(d.id, d.data())).toList());
  }

  /// Clears a report once an admin has acted (or deliberately not acted) on
  /// the underlying listing — reports don't auto-resolve.
  Future<void> dismiss(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
