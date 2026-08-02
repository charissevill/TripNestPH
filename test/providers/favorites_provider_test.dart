import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/providers/favorites_provider.dart';
import 'package:tripnest_ph/data/repositories/favorites_repository.dart';
import 'package:tripnest_ph/domain/models/place.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FavoritesProvider provider;

  const place = Place(
    id: 'places/abc',
    name: 'Banaue Rice Terraces',
    types: ['tourist_attraction'],
    photoNames: ['places/abc/photos/1'],
    rating: 4.8,
    userRatingCount: 500,
    address: 'Banaue, Ifugao',
    latitude: 16.9,
    longitude: 121.05,
    distanceMeters: 1234,
  );

  setUp(() {
    firestore = FakeFirebaseFirestore();
    provider = FavoritesProvider(repository: FavoritesRepository(firestore: firestore));
  });

  test('togglePlace() saves a place, marks it saved, and streams it back into savedPlaces', () async {
    provider.bindToUser('user-1');

    provider.togglePlace(place);
    expect(provider.isPlaceSaved(place.id), isTrue);
    expect(provider.savedPlaces.map((p) => p.id), contains(place.id));

    // Let the live Firestore stream catch up and reconcile the optimistic update.
    await Future<void>.delayed(Duration.zero);

    expect(provider.isPlaceSaved(place.id), isTrue);
    expect(provider.savedPlaces.single.name, 'Banaue Rice Terraces');
    // Never persisted — stale once saved (see togglePlace's doc comment).
    expect(provider.savedPlaces.single.distanceMeters, isNull);
  });

  test('togglePlace() called again removes the place', () async {
    provider.bindToUser('user-1');
    provider.togglePlace(place);
    await Future<void>.delayed(Duration.zero);
    expect(provider.isPlaceSaved(place.id), isTrue);

    provider.togglePlace(place);
    expect(provider.isPlaceSaved(place.id), isFalse);
    expect(provider.savedPlaces, isEmpty);

    await Future<void>.delayed(Duration.zero);
    expect(provider.isPlaceSaved(place.id), isFalse);
    expect(provider.savedPlaces, isEmpty);
  });

  test('togglePlace() is a no-op when no user is bound', () async {
    provider.togglePlace(place);
    expect(provider.isPlaceSaved(place.id), isFalse);
    expect(provider.savedPlaces, isEmpty);
  });

  test('bindToUser(null) clears saved places from view', () async {
    provider.bindToUser('user-1');
    provider.togglePlace(place);
    await Future<void>.delayed(Duration.zero);
    expect(provider.savedPlaces, isNotEmpty);

    provider.bindToUser(null);
    expect(provider.savedPlaces, isEmpty);
    expect(provider.isPlaceSaved(place.id), isFalse);
  });

  test('totalSavedCount includes saved places', () async {
    provider.bindToUser('user-1');
    expect(provider.totalSavedCount, 0);

    provider.togglePlace(place);
    expect(provider.totalSavedCount, 1);
  });
}
