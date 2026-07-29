import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:tripnest_ph/core/services/places_service.dart';
import 'package:tripnest_ph/core/services/storage_service.dart';
import 'package:tripnest_ph/data/repositories/destination_repository.dart';
import 'package:tripnest_ph/data/repositories/restaurant_repository.dart';
import 'package:tripnest_ph/data/repositories/trip_photo_repository.dart';
import 'package:tripnest_ph/domain/models/trip_photo.dart';
import 'package:tripnest_ph/presentation/profile/my_photos_screen.dart';

/// Tracks calls instead of touching real Firebase Storage — same reasoning
/// `test/widgets/search_screen_test.dart`'s fake-injection pattern uses for
/// Firestore/Cloud Functions, just for the one plugin that has no fake
/// package available.
class _FakeStorageService extends StorageService {
  int deleteCallCount = 0;
  String? lastDeletedUrl;

  @override
  Future<void> deleteByUrl(String url) async {
    deleteCallCount++;
    lastDeletedUrl = url;
  }
}

const String _uid = 'traveler-1';
const String _photoUrl = 'https://example.com/photo.jpg';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  Future<
    ({
      FakeFirebaseFirestore firestore,
      _FakeStorageService storage,
      TripPhotoRepository photoRepository,
    })
  >
  seed(WidgetTester tester) async {
    final firestore = FakeFirebaseFirestore();
    final photoRepository = TripPhotoRepository(firestore: firestore);
    await photoRepository.create(
      TripPhoto(
        id: '',
        userId: _uid,
        photoUrl: _photoUrl,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    final storage = _FakeStorageService();

    await tester.pumpWidget(
      _wrap(
        MyPhotosScreen(
          uidOverride: _uid,
          photoRepository: photoRepository,
          destinationRepository: DestinationRepository(firestore: firestore),
          restaurantRepository: RestaurantRepository(firestore: firestore),
          placesService: PlacesService(
            caller: (name, data) async {
              fail('Unexpected Places call: $name');
            },
          ),
          storageService: storage,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return (
      firestore: firestore,
      storage: storage,
      photoRepository: photoRepository,
    );
  }

  testWidgets(
    'confirming the delete dialog removes the photo and cleans up storage',
    (tester) async {
      final env = await seed(tester);

      expect(find.byIcon(Symbols.delete_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Symbols.delete_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Delete this photo?'), findsOneWidget);

      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(env.storage.deleteCallCount, 1);
      expect(env.storage.lastDeletedUrl, _photoUrl);
      expect(find.byIcon(Symbols.delete_rounded), findsNothing);
    },
  );

  testWidgets('cancelling the delete dialog keeps the photo', (tester) async {
    final env = await seed(tester);

    await tester.tap(find.byIcon(Symbols.delete_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(env.storage.deleteCallCount, 0);
    expect(find.byIcon(Symbols.delete_rounded), findsOneWidget);
  });
}
