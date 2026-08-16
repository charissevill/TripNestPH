import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripnest_ph/data/repositories/analytics_snapshot_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late AnalyticsSnapshotRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = AnalyticsSnapshotRepository(firestore: firestore);
  });

  test('getRecent() returns snapshots oldest first, capped to the requested count', () async {
    for (final date in ['2026-01-01', '2026-01-02', '2026-01-03']) {
      await firestore.collection('analytics_snapshots').doc(date).set({'date': date, 'travelerCount': int.parse(date.split('-').last)});
    }

    final result = await repository.getRecent(days: 2);

    expect(result.map((s) => s.date.day), [2, 3]);
    expect(result.map((s) => s.travelerCount), [2, 3]);
  });

  test('getRecent() returns an empty list when no snapshots exist yet', () async {
    expect(await repository.getRecent(), isEmpty);
  });
}
