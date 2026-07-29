import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/data/repositories/trip_photo_repository.dart';
import 'package:tripnest_ph/domain/models/trip_photo.dart';

TripPhoto _photo({
  required String userId,
  required String photoUrl,
  DateTime? takenAt,
  String? placeName,
  String? matchTier,
  String? destinationId,
}) {
  return TripPhoto(
    id: '',
    userId: userId,
    photoUrl: photoUrl,
    createdAt: DateTime.now(),
    takenAt: takenAt,
    placeName: placeName,
    matchTier: matchTier,
    destinationId: destinationId,
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late TripPhotoRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = TripPhotoRepository(firestore: firestore);
  });

  test('create() adds a doc that streamForUser() picks up', () async {
    await repository.create(_photo(userId: 'user-1', photoUrl: 'https://example.com/a.jpg'));

    final result = await repository.streamForUser('user-1').first;

    expect(result, hasLength(1));
    expect(result.single.photoUrl, 'https://example.com/a.jpg');
  });

  test('streamForUser() only returns that user\'s photos', () async {
    await repository.create(_photo(userId: 'user-1', photoUrl: 'https://example.com/a.jpg'));
    await repository.create(_photo(userId: 'user-2', photoUrl: 'https://example.com/b.jpg'));

    final result = await repository.streamForUser('user-1').first;

    expect(result, hasLength(1));
    expect(result.single.photoUrl, 'https://example.com/a.jpg');
  });

  test('streamForUser() orders newest takenAt first', () async {
    await repository.create(
      _photo(userId: 'user-1', photoUrl: 'older.jpg', takenAt: DateTime(2026, 1, 1)),
    );
    await repository.create(
      _photo(userId: 'user-1', photoUrl: 'newer.jpg', takenAt: DateTime(2026, 6, 1)),
    );

    final result = await repository.streamForUser('user-1').first;

    expect(result.map((p) => p.photoUrl).toList(), ['newer.jpg', 'older.jpg']);
  });

  test('a tagged photo round-trips its place fields', () async {
    await repository.create(
      _photo(
        userId: 'user-1',
        photoUrl: 'tagged.jpg',
        placeName: 'Chocolate Hills',
        matchTier: 'curated',
        destinationId: 'chocolate-hills-1',
      ),
    );

    final result = await repository.streamForUser('user-1').first;

    expect(result.single.placeName, 'Chocolate Hills');
    expect(result.single.matchTier, 'curated');
    expect(result.single.destinationId, 'chocolate-hills-1');
    expect(result.single.isTagged, isTrue);
  });

  test('an untagged photo has null place fields', () async {
    await repository.create(_photo(userId: 'user-1', photoUrl: 'untagged.jpg'));

    final result = await repository.streamForUser('user-1').first;

    expect(result.single.placeName, isNull);
    expect(result.single.isTagged, isFalse);
  });

  test('delete() removes the photo so streamForUser() no longer includes it', () async {
    final id = await repository.create(_photo(userId: 'user-1', photoUrl: 'a.jpg'));
    await repository.delete(id);

    final result = await repository.streamForUser('user-1').first;

    expect(result, isEmpty);
  });
}
