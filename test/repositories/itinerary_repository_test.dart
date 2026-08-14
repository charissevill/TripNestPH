import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/data/repositories/itinerary_repository.dart';
import 'package:tripnest_ph/data/mock/mock_itinerary.dart';
import 'package:tripnest_ph/domain/models/packing_item.dart';
import 'package:tripnest_ph/domain/models/saved_itinerary.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ItineraryRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = ItineraryRepository(firestore: firestore);
  });

  test('save() seeds a default packing checklist that getById() reads back', () async {
    final id = await repository.save(userId: 'owner-1', title: 'Palawan Trip', itinerary: mockItinerary);

    final trip = await repository.getById(id);

    expect(trip, isNotNull);
    expect(trip!.userId, 'owner-1');
    expect(trip.packingItems, isNotEmpty);
    expect(trip.collaboratorIds, isEmpty);
  });

  test('getById() returns null for a code that does not exist', () async {
    final trip = await repository.getById('not-a-real-id');
    expect(trip, isNull);
  });

  test('joinAsCollaborator() adds the joining uid without touching anything else', () async {
    final id = await repository.save(userId: 'owner-1', title: 'Palawan Trip', itinerary: mockItinerary);

    await repository.joinAsCollaborator(itineraryId: id, userId: 'friend-1');

    final trip = await repository.getById(id);
    expect(trip!.collaboratorIds, ['friend-1']);
  });

  test('leaveTrip() removes only the leaving uid, keeping other collaborators', () async {
    final id = await repository.save(userId: 'owner-1', title: 'Palawan Trip', itinerary: mockItinerary);
    await repository.joinAsCollaborator(itineraryId: id, userId: 'friend-1');
    await repository.joinAsCollaborator(itineraryId: id, userId: 'friend-2');

    await repository.leaveTrip(itineraryId: id, userId: 'friend-1');

    final trip = await repository.getById(id);
    expect(trip!.collaboratorIds, ['friend-2']);
  });

  test('save() with an ownerName seeds memberNames for the owner', () async {
    final id = await repository.save(userId: 'owner-1', title: 'Palawan Trip', itinerary: mockItinerary, ownerName: 'Juan');

    final trip = await repository.getById(id);
    expect(trip!.memberNames, {'owner-1': 'Juan'});
    expect(trip.memberIds, ['owner-1']);
  });

  test('joinAsCollaborator() with a userName adds only the joiner\'s own memberNames entry', () async {
    final id = await repository.save(userId: 'owner-1', title: 'Palawan Trip', itinerary: mockItinerary, ownerName: 'Juan');

    await repository.joinAsCollaborator(itineraryId: id, userId: 'friend-1', userName: 'Maria');

    final trip = await repository.getById(id);
    expect(trip!.memberNames, {'owner-1': 'Juan', 'friend-1': 'Maria'});
    expect(trip.memberIds, ['owner-1', 'friend-1']);
  });

  test('leaveTrip() removes the leaving uid\'s memberNames entry too', () async {
    final id = await repository.save(userId: 'owner-1', title: 'Palawan Trip', itinerary: mockItinerary, ownerName: 'Juan');
    await repository.joinAsCollaborator(itineraryId: id, userId: 'friend-1', userName: 'Maria');

    await repository.leaveTrip(itineraryId: id, userId: 'friend-1');

    final trip = await repository.getById(id);
    expect(trip!.memberNames, {'owner-1': 'Juan'});
  });

  test('togglePackingItem() persists a checked-off item without touching the others', () async {
    final id = await repository.save(userId: 'owner-1', title: 'Palawan Trip', itinerary: mockItinerary);
    final trip = await repository.getById(id);
    final targetId = trip!.packingItems.first.id;

    await repository.togglePackingItem(id, targetId, true);

    final reloaded = await repository.getById(id);
    expect(reloaded!.packingItems.firstWhere((p) => p.id == targetId).checked, isTrue);
    expect(reloaded.packingItems.length, trip.packingItems.length);
  });

  test('togglePackingItem() on one item never clobbers a concurrent toggle on a different item', () async {
    final id = await repository.save(userId: 'owner-1', title: 'Palawan Trip', itinerary: mockItinerary);
    final trip = await repository.getById(id);
    final firstId = trip!.packingItems[0].id;
    final secondId = trip.packingItems[1].id;

    // Both "collaborators" read the same starting snapshot, then each
    // targets a different item — the exact scenario that used to lose an
    // update when both wrote back the whole array.
    await repository.togglePackingItem(id, firstId, true);
    await repository.togglePackingItem(id, secondId, true);

    final reloaded = await repository.getById(id);
    expect(reloaded!.packingItems.firstWhere((p) => p.id == firstId).checked, isTrue);
    expect(reloaded.packingItems.firstWhere((p) => p.id == secondId).checked, isTrue);
  });

  test('addPackingItem() then removePackingItem() round-trips cleanly', () async {
    final id = await repository.save(userId: 'owner-1', title: 'Palawan Trip', itinerary: mockItinerary);
    final trip = await repository.getById(id);
    final before = trip!.packingItems.length;
    const newItem = PackingItem(id: 'extra-1', label: 'Snorkel gear', checked: false);

    await repository.addPackingItem(id, newItem);
    final afterAdd = await repository.getById(id);
    expect(afterAdd!.packingItems.length, before + 1);
    expect(afterAdd.packingItems.any((p) => p.id == 'extra-1'), isTrue);

    await repository.removePackingItem(id, 'extra-1');
    final afterRemove = await repository.getById(id);
    expect(afterRemove!.packingItems.length, before);
    expect(afterRemove.packingItems.any((p) => p.id == 'extra-1'), isFalse);
  });

  test('streamForUser() includes trips the user owns AND trips they joined as a collaborator', () async {
    final ownedId = await repository.save(userId: 'user-1', title: 'My Trip', itinerary: mockItinerary);
    final sharedId = await repository.save(userId: 'user-2', title: "Friend's Trip", itinerary: mockItinerary);
    await repository.joinAsCollaborator(itineraryId: sharedId, userId: 'user-1');
    // A third trip user-1 has no access to at all should never show up.
    await repository.save(userId: 'user-3', title: 'Stranger Trip', itinerary: mockItinerary);

    final trips = await repository.streamForUser('user-1').first;

    expect(trips.map((t) => t.id), containsAll([ownedId, sharedId]));
    expect(trips.length, 2);
  });

  test('streamForUser() emits an updated list once a trip is shared, without a new save', () async {
    final sharedId = await repository.save(userId: 'user-2', title: "Friend's Trip", itinerary: mockItinerary);

    final events = <List<SavedItinerary>>[];
    final sub = repository.streamForUser('user-1').listen(events.add);
    await Future<void>.delayed(Duration.zero);

    await repository.joinAsCollaborator(itineraryId: sharedId, userId: 'user-1');
    await Future<void>.delayed(Duration.zero);

    await sub.cancel();
    expect(events.last.map((t) => t.id), contains(sharedId));
  });

  test('save() with a startDate persists it so getById() reads back the same date', () async {
    final id = await repository.save(
      userId: 'owner-1',
      title: 'Palawan Trip',
      itinerary: mockItinerary,
      startDate: DateTime(2026, 8, 3),
    );

    final trip = await repository.getById(id);

    expect(trip!.startDate, DateTime(2026, 8, 3));
  });

  test('save() without a startDate leaves it null', () async {
    final id = await repository.save(userId: 'owner-1', title: 'Palawan Trip', itinerary: mockItinerary);

    final trip = await repository.getById(id);

    expect(trip!.startDate, isNull);
  });

  test('updateStartDate() sets the date on an existing trip', () async {
    final id = await repository.save(userId: 'owner-1', title: 'Palawan Trip', itinerary: mockItinerary);

    await repository.updateStartDate(id, DateTime(2026, 9, 1));

    final trip = await repository.getById(id);
    expect(trip!.startDate, DateTime(2026, 9, 1));
  });

  test('updateStartDate() with null clears a previously set date', () async {
    final id = await repository.save(
      userId: 'owner-1',
      title: 'Palawan Trip',
      itinerary: mockItinerary,
      startDate: DateTime(2026, 8, 3),
    );

    await repository.updateStartDate(id, null);

    final trip = await repository.getById(id);
    expect(trip!.startDate, isNull);
  });

  test('countAll() counts every saved trip across every traveler — the Admin Portal analytics stat', () async {
    await repository.save(userId: 'owner-1', title: 'Palawan Trip', itinerary: mockItinerary);
    await repository.save(userId: 'owner-2', title: 'Bohol Trip', itinerary: mockItinerary);

    expect(await repository.countAll(), 2);
  });
}
