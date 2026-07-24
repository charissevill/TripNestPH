import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/data/repositories/favorites_repository.dart';

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
}
