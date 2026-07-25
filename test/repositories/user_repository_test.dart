import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/data/repositories/destination_repository.dart';
import 'package:tripnest_ph/data/repositories/user_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late UserRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = UserRepository(firestore: firestore, destinationRepository: DestinationRepository(firestore: firestore));
  });

  group('recordVisit() / hasVisited()', () {
    test('hasVisited() is false before any visit is recorded', () async {
      final visited = await repository.hasVisited(uid: 'user-1', targetType: 'destination', targetId: 'palawan');
      expect(visited, isFalse);
    });

    test('recordVisit() makes hasVisited() true for that exact target', () async {
      await repository.recordVisit(uid: 'user-1', targetType: 'destination', targetId: 'palawan');

      final visited = await repository.hasVisited(uid: 'user-1', targetType: 'destination', targetId: 'palawan');
      expect(visited, isTrue);
    });

    test('a visit is scoped to its targetType — a restaurant visit does not verify a destination with the same id', () async {
      await repository.recordVisit(uid: 'user-1', targetType: 'restaurant', targetId: 'shared-id');

      final asDestination = await repository.hasVisited(uid: 'user-1', targetType: 'destination', targetId: 'shared-id');
      final asRestaurant = await repository.hasVisited(uid: 'user-1', targetType: 'restaurant', targetId: 'shared-id');
      expect(asDestination, isFalse);
      expect(asRestaurant, isTrue);
    });

    test('a visit is scoped to the visiting user — another user is unaffected', () async {
      await repository.recordVisit(uid: 'user-1', targetType: 'festival', targetId: 'ati-atihan');

      final visited = await repository.hasVisited(uid: 'user-2', targetType: 'festival', targetId: 'ati-atihan');
      expect(visited, isFalse);
    });
  });

  test('deleteAccountData() removes visited records along with the profile doc', () async {
    await repository.createIfMissing(uid: 'user-1', name: 'Juan', email: 'juan@example.com');
    await repository.recordVisit(uid: 'user-1', targetType: 'destination', targetId: 'palawan');

    await repository.deleteAccountData('user-1');

    final profile = await repository.getUser('user-1');
    expect(profile, isNull);
    final visited = await repository.hasVisited(uid: 'user-1', targetType: 'destination', targetId: 'palawan');
    expect(visited, isFalse);
  });
}
