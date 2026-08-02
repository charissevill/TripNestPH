import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tripnest_ph/core/providers/auth_provider.dart';
import 'package:tripnest_ph/core/providers/favorites_provider.dart';
import 'package:tripnest_ph/core/services/auth_service.dart';
import 'package:tripnest_ph/core/services/location_service.dart';
import 'package:tripnest_ph/core/services/places_service.dart';
import 'package:tripnest_ph/core/utils/function_caller.dart';
import 'package:tripnest_ph/core/widgets/details/place_details_sheet.dart';
import 'package:tripnest_ph/data/repositories/destination_repository.dart';
import 'package:tripnest_ph/data/repositories/favorites_repository.dart';
import 'package:tripnest_ph/data/repositories/festival_repository.dart';
import 'package:tripnest_ph/data/repositories/notification_repository.dart';
import 'package:tripnest_ph/data/repositories/travel_tip_repository.dart';
import 'package:tripnest_ph/data/repositories/user_repository.dart';
import 'package:tripnest_ph/presentation/home/home_screen.dart';

import '../support/fake_image_http_overrides.dart';

/// Fakes the `placesSearchText` Cloud Function, keyed by exact `textQuery` —
/// same seam `test/widgets/search_screen_test.dart`/`explore_screen_test.dart`
/// already established.
FunctionCaller _fakePlacesSearchText(
  Map<String, List<Map<String, dynamic>>> responsesByQuery,
) {
  return (name, data) async {
    expect(name, 'placesSearchText');
    final query = data['textQuery'] as String;
    if (!responsesByQuery.containsKey(query)) {
      fail('Unexpected placesSearchText query: "$query"');
    }
    return {'places': responsesByQuery[query]!};
  };
}

/// Avoids touching the real Geolocator platform channel (not available in
/// `flutter_test`) — reports location as unavailable, so Home's "Nearby
/// You" section takes its normal no-location path instead of throwing.
class _FakeLocationService extends LocationService {
  @override
  Future<LocationResult> resolveCurrentPosition() async =>
      const LocationResult(status: LocationAccessStatus.unavailable);
}

/// `pumpAndSettle()` never converges while any card's `CachedNetworkImage`
/// placeholder shimmer is still animating (a deliberately non-terminating
/// `..repeat()`) — see the identical note in `explore_screen_test.dart`.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = FakeImageHttpOverrides();
  });

  // Per-test, not setUpAll: `PlacesService` caches results in
  // SharedPreferences keyed only by request signature, and that mock store
  // persists across tests in the same file — without resetting it, two
  // tests faking the same textQuery with different responses (e.g. "best
  // restaurants in the Philippines") would have the second test silently
  // served the first test's cached result instead of hitting its own fake.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> buildScreen({
    required WidgetTester tester,
    required FakeFirebaseFirestore firestore,
    required PlacesService placesService,
  }) async {
    final authProvider = AuthProvider(
      authService: AuthService(auth: MockFirebaseAuth()),
      userRepository: UserRepository(firestore: firestore, destinationRepository: DestinationRepository(firestore: firestore)),
    );
    final favoritesProvider = FavoritesProvider(repository: FavoritesRepository(firestore: firestore));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<FavoritesProvider>.value(value: favoritesProvider),
        ],
        child: MaterialApp(
          home: HomeScreen(
            placesService: placesService,
            festivalRepository: FestivalRepository(firestore: firestore),
            travelTipRepository: TravelTipRepository(firestore: firestore),
            notificationRepository: NotificationRepository(firestore: firestore),
            locationService: _FakeLocationService(),
          ),
        ),
      ),
    );
    await _settle(tester);
  }

  testWidgets(
    'shows live Places results as Featured Destinations — no curated tourist_spots, no Hidden Gems',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final placesService = PlacesService(
        caller: _fakePlacesSearchText({
          'top tourist attractions in the Philippines': [
            {
              'id': 'places/banaue',
              'displayName': {'text': 'Banaue Rice Terraces'},
              'formattedAddress': 'Banaue, Ifugao',
              'location': {'latitude': 16.9, 'longitude': 121.05},
              'photos': [
                {'name': 'places/banaue/photos/abc'},
              ],
            },
          ],
          'best restaurants in the Philippines': [],
        }),
      );

      await buildScreen(
        tester: tester,
        firestore: firestore,
        placesService: placesService,
      );

      expect(find.text('Banaue Rice Terraces'), findsWidgets);
      // "Featured Destinations" is below the fold in a plain `ListView`'s
      // element tree until scrolled into view (same gotcha handled in
      // `admin_analytics_screen_test.dart`).
      await tester.scrollUntilVisible(
        find.text('Featured Destinations'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Featured Destinations'), findsOneWidget);
      // The old curated-only sections are gone entirely — no Places analog
      // exists for either, so they're removed rather than faked.
      expect(find.text('Hidden Gems'), findsNothing);
      expect(find.text('Popular Tourist Spots'), findsNothing);
    },
  );

  testWidgets('tapping a Featured Destinations tile opens the place details sheet', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final placesService = PlacesService(
      caller: _fakePlacesSearchText({
        'top tourist attractions in the Philippines': [
          {
            'id': 'places/banaue',
            'displayName': {'text': 'Banaue Rice Terraces'},
            'formattedAddress': 'Banaue, Ifugao',
            'location': {'latitude': 16.9, 'longitude': 121.05},
          },
        ],
        'best restaurants in the Philippines': [],
      }),
    );

    await buildScreen(
      tester: tester,
      firestore: firestore,
      placesService: placesService,
    );

    // The hero banner's `onTap` is wired to its "Explore now" CTA, not the
    // title text itself — see `HeroBanner`'s `GestureDetector`.
    await tester.tap(find.text('Explore now'));
    await _settle(tester);

    expect(find.byType(PlaceDetailsSheet), findsOneWidget);
  });

  testWidgets(
    'Popular Restaurants shows only live Places results — the business-owner catalog never renders there; Upcoming Festivals stays curated',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      // Seeded to prove a business-owner restaurant is never shown in
      // Popular Restaurants anymore, not to assert it renders.
      await firestore.collection('restaurants').doc('lantaw').set({
        'name': 'Lantaw Native Restaurant',
        'nameLower': 'lantaw native restaurant',
        'cuisine': 'Filipino',
        'provinceId': 'cebu',
        'provinceName': 'Cebu',
        'regionId': 'region-7',
        'heroImageUrl': '',
        'galleryImageUrls': <String>[],
        'rating': 4.5,
        'reviewCount': 80,
        'priceRange': '₱₱',
        'description': '',
        'openingHours': '',
        'menuHighlights': <String>[],
        'isPopular': true,
        'status': 'published',
      });
      await firestore.collection('festivals').doc('sinulog').set({
        'name': 'Sinulog Festival',
        'provinceId': 'cebu',
        'provinceName': 'Cebu',
        'regionId': 'region-7',
        'heroImageUrl': '',
        'galleryImageUrls': <String>[],
        'dateLabel': 'January 2027',
        'month': 'JAN',
        'description': '',
        'highlights': <String>[],
        'rating': 4.8,
        'reviewCount': 200,
        'isUpcoming': true,
        'status': 'published',
      });
      final placesService = PlacesService(
        caller: _fakePlacesSearchText({
          'top tourist attractions in the Philippines': [],
          'best restaurants in the Philippines': [
            {
              'id': 'places/abaca',
              'displayName': {'text': 'Abaca Baking Company'},
              'formattedAddress': 'Boracay, Aklan',
              'location': {'latitude': 11.96, 'longitude': 121.92},
            },
          ],
        }),
      );

      await buildScreen(
        tester: tester,
        firestore: firestore,
        placesService: placesService,
      );

      await tester.scrollUntilVisible(
        find.text('Abaca Baking Company'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Abaca Baking Company'), findsOneWidget);
      expect(find.text('Lantaw Native Restaurant'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Sinulog Festival'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Sinulog Festival'), findsOneWidget);
    },
  );
}
