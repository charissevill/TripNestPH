import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/data/repositories/favorites_repository.dart';
import 'package:tripnest_ph/domain/models/place.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FavoritesRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FavoritesRepository(firestore: firestore);
  });

  test('add() creates a favorite doc that streamFavorites() picks up', () async {
    await repository.add('user-1', FavoriteType.destination, 'dest-1');

    final result = await repository.streamFavorites('user-1').first;

    expect(result[FavoriteType.destination], contains('dest-1'));
    expect(result[FavoriteType.restaurant], isEmpty);
  });

  test('add() is idempotent for the same (user, type, item)', () async {
    await repository.add('user-1', FavoriteType.restaurant, 'rest-1');
    await repository.add('user-1', FavoriteType.restaurant, 'rest-1');

    final snapshot = await firestore.collection('favorites').get();
    expect(snapshot.docs.length, 1);
  });

  test('remove() deletes the favorite so streamFavorites() no longer includes it', () async {
    await repository.add('user-1', FavoriteType.festival, 'fest-1');
    await repository.remove('user-1', FavoriteType.festival, 'fest-1');

    final result = await repository.streamFavorites('user-1').first;
    expect(result[FavoriteType.festival], isEmpty);
  });

  test('streamFavorites() only returns the given user\'s favorites', () async {
    await repository.add('user-1', FavoriteType.destination, 'dest-1');
    await repository.add('user-2', FavoriteType.destination, 'dest-2');

    final result = await repository.streamFavorites('user-1').first;
    expect(result[FavoriteType.destination], {'dest-1'});
  });

  test('deleteAllForUser() removes every favorite for that user only', () async {
    await repository.add('user-1', FavoriteType.destination, 'dest-1');
    await repository.add('user-1', FavoriteType.restaurant, 'rest-1');
    await repository.add('user-2', FavoriteType.destination, 'dest-2');

    await repository.deleteAllForUser('user-1');

    final remaining = await firestore.collection('favorites').get();
    expect(remaining.docs.length, 1);
    expect(remaining.docs.first.data()['userId'], 'user-2');
  });

  test('add() with a snapshot persists the extra fields alongside the usual ones', () async {
    await repository.add(
      'user-1',
      FavoriteType.place,
      'places/abc',
      snapshot: {'name': 'Banaue Rice Terraces', 'address': 'Banaue, Ifugao'},
    );

    final doc = await firestore.collection('favorites').doc('user-1_place_places_abc').get();
    expect(doc.data()!['name'], 'Banaue Rice Terraces');
    expect(doc.data()!['address'], 'Banaue, Ifugao');
    expect(doc.data()!['userId'], 'user-1');
    expect(doc.data()!['itemType'], 'place');
  });

  test('streamSavedPlaces() round-trips a real Place through toJson()/add()/fromCacheJson()', () async {
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
      // Deliberately not persisted — see FavoritesProvider.togglePlace's
      // doc comment on why this is stripped before saving.
      distanceMeters: 1234,
    );
    final snapshot = Map<String, dynamic>.from(place.toJson())..remove('distanceMeters');
    await repository.add('user-1', FavoriteType.place, place.id, snapshot: snapshot);

    final result = await repository.streamSavedPlaces('user-1').first;

    expect(result, hasLength(1));
    expect(result.single.id, 'places/abc');
    expect(result.single.name, 'Banaue Rice Terraces');
    expect(result.single.address, 'Banaue, Ifugao');
    expect(result.single.latitude, 16.9);
    expect(result.single.longitude, 121.05);
    expect(result.single.distanceMeters, isNull);
  });

  test('streamSavedPlaces() only returns the given user\'s place favorites, never other types', () async {
    await repository.add('user-1', FavoriteType.place, 'places/abc', snapshot: {'id': 'places/abc', 'name': 'A', 'address': ''});
    await repository.add('user-1', FavoriteType.destination, 'dest-1');
    await repository.add('user-2', FavoriteType.place, 'places/xyz', snapshot: {'id': 'places/xyz', 'name': 'B', 'address': ''});

    final result = await repository.streamSavedPlaces('user-1').first;

    expect(result, hasLength(1));
    expect(result.single.id, 'places/abc');
  });
}
