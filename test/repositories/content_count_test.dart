import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/data/repositories/destination_repository.dart';
import 'package:tripnest_ph/data/repositories/festival_repository.dart';
import 'package:tripnest_ph/data/repositories/restaurant_repository.dart';

/// Covers the `countPublished()` method added to all three curated-content
/// repositories for the Admin Portal analytics dashboard — grouped in one
/// file since the three repositories share the exact same
/// `status == 'published'` counting shape.
void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  test('DestinationRepository.countPublished() only counts published tourist spots', () async {
    await firestore.collection('tourist_spots').add({'name': 'A', 'status': 'published'});
    await firestore.collection('tourist_spots').add({'name': 'B', 'status': 'published'});
    await firestore.collection('tourist_spots').add({'name': 'C', 'status': 'draft'});

    final repository = DestinationRepository(firestore: firestore);
    expect(await repository.countPublished(), 2);
  });

  test('RestaurantRepository.countPublished() only counts published restaurants', () async {
    await firestore.collection('restaurants').add({'name': 'A', 'status': 'published'});
    await firestore.collection('restaurants').add({'name': 'B', 'status': 'pending'});

    final repository = RestaurantRepository(firestore: firestore);
    expect(await repository.countPublished(), 1);
  });

  test('FestivalRepository.countPublished() only counts published festivals', () async {
    await firestore.collection('festivals').add({'name': 'A', 'status': 'published'});
    await firestore.collection('festivals').add({'name': 'B', 'status': 'published'});
    await firestore.collection('festivals').add({'name': 'C', 'status': 'published'});
    await firestore.collection('festivals').add({'name': 'D', 'status': 'draft'});

    final repository = FestivalRepository(firestore: firestore);
    expect(await repository.countPublished(), 3);
  });
}
