import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/analytics_snapshot.dart';

/// Firestore access for the `analytics_snapshots` collection — written only
/// by the scheduled `snapshotDailyAnalytics` Cloud Function, read only by
/// `AdminAnalyticsScreen`'s trend chart.
class AnalyticsSnapshotRepository {
  AnalyticsSnapshotRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection(FirestorePaths.analyticsSnapshots);

  /// The most recent [days] snapshots, oldest first — the order a line
  /// chart's x-axis expects, opposite of the descending query used to pick
  /// which [days] to fetch in the first place.
  Future<List<AnalyticsSnapshot>> getRecent({int days = 14}) async {
    try {
      final snapshot = await _collection.orderBy('date', descending: true).limit(days).get();
      final list = snapshot.docs.map((d) => AnalyticsSnapshot.fromMap(d.id, d.data())).toList();
      return list.reversed.toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
