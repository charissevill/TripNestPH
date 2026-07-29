import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/data/repositories/search_trend_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late SearchTrendRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = SearchTrendRepository(firestore: firestore);
  });

  test('record() creates a new term at count 1', () async {
    await repository.record('Cebu');

    final doc = await firestore.collection('search_trends').doc('cebu').get();
    expect(doc.data()!['term'], 'Cebu');
    expect(doc.data()!['count'], 1);
  });

  test(
    'record() increments an existing term instead of overwriting it',
    () async {
      await repository.record('Cebu');
      await repository.record('cebu');
      await repository.record('CEBU');

      final doc = await firestore.collection('search_trends').doc('cebu').get();
      expect(doc.data()!['count'], 3);
      // The doc keeps the first-seen casing rather than flipping per search.
      expect(doc.data()!['term'], 'Cebu');
    },
  );

  test('record() ignores queries shorter than the 3-character floor', () async {
    await repository.record('Ce');

    final snapshot = await firestore.collection('search_trends').get();
    expect(snapshot.docs, isEmpty);
  });

  test('getTopTrending() orders by count, descending', () async {
    await repository.record('Cebu');
    await repository.record('Bohol');
    await repository.record('Bohol');
    await repository.record('Palawan');
    await repository.record('Palawan');
    await repository.record('Palawan');

    final top = await repository.getTopTrending(limit: 2);

    expect(top, ['Palawan', 'Bohol']);
  });
}
