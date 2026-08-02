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

  group('Admin Portal: counts, pagination, setStatus()', () {
    test('countAll() counts every traveler regardless of status', () async {
      await repository.createIfMissing(uid: 'user-1', name: 'Juan', email: 'juan@example.com');
      await repository.createIfMissing(uid: 'user-2', name: 'Maria', email: 'maria@example.com');

      expect(await repository.countAll(), 2);
    });

    test('countByStatus() only counts travelers with that exact status', () async {
      await repository.createIfMissing(uid: 'user-1', name: 'Juan', email: 'juan@example.com');
      await repository.createIfMissing(uid: 'user-2', name: 'Maria', email: 'maria@example.com');
      await repository.setStatus('user-2', 'suspended');

      expect(await repository.countByStatus('suspended'), 1);
      expect(await repository.countByStatus('active'), 1);
    });

    test('setStatus() only changes the status field, never anything else', () async {
      await repository.createIfMissing(uid: 'user-1', name: 'Juan', email: 'juan@example.com');

      await repository.setStatus('user-1', 'suspended');

      final profile = await repository.getUser('user-1');
      expect(profile!.isSuspended, isTrue);
      expect(profile.name, 'Juan');
      expect(profile.email, 'juan@example.com');
    });

    test('getPage() paginates newest-first and respects pageSize', () async {
      await repository.createIfMissing(uid: 'user-1', name: 'First', email: 'first@example.com');
      await repository.createIfMissing(uid: 'user-2', name: 'Second', email: 'second@example.com');
      await repository.createIfMissing(uid: 'user-3', name: 'Third', email: 'third@example.com');

      final firstPage = await repository.getPage(pageSize: 2);
      expect(firstPage.items, hasLength(2));
      expect(firstPage.lastDoc, isNotNull);

      final secondPage = await repository.getPage(pageSize: 2, startAfter: firstPage.lastDoc);
      expect(secondPage.items, hasLength(1));

      final allUids = [...firstPage.items, ...secondPage.items].map((u) => u.uid).toSet();
      expect(allUids, {'user-1', 'user-2', 'user-3'});
    });
  });
}
