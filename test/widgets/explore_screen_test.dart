import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tripnest_ph/core/providers/favorites_provider.dart';
import 'package:tripnest_ph/core/services/places_service.dart';
import 'package:tripnest_ph/core/utils/function_caller.dart';
import 'package:tripnest_ph/core/widgets/details/place_details_sheet.dart';
import 'package:tripnest_ph/data/repositories/favorites_repository.dart';
import 'package:tripnest_ph/data/repositories/festival_repository.dart';
import 'package:tripnest_ph/data/repositories/province_repository.dart';
import 'package:tripnest_ph/data/repositories/region_repository.dart';
import 'package:tripnest_ph/data/repositories/restaurant_repository.dart';
import 'package:tripnest_ph/presentation/explore/explore_screen.dart';

import '../support/fake_image_http_overrides.dart';

/// Fakes the `placesSearchText` Cloud Function, keyed by exact `textQuery` —
/// same seam `test/widgets/search_screen_test.dart` already established.
/// Fails the test outright if a query outside [responsesByQuery] is
/// attempted, so a test asserting "Explore never calls Places here" (the
/// Festivals-tab case) catches an unexpected call instead of silently
/// returning an empty list for it.
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

// DestinationCard/RestaurantCard both call `context.watch<FavoritesProvider>()`
// for their bookmark toggle — needs a real provider ancestor, backed by the
// same fake Firestore instance, or the grid throws on build.
Widget _wrap(Widget child, FakeFirebaseFirestore firestore) {
  return ChangeNotifierProvider<FavoritesProvider>(
    create: (_) => FavoritesProvider(repository: FavoritesRepository(firestore: firestore)),
    child: MaterialApp(home: child),
  );
}

/// `pumpAndSettle()` never converges even with `FakeImageHttpOverrides`
/// installed (`TravelImageFrame`'s `Shimmer.fromColors` placeholder runs a
/// deliberately non-terminating `..repeat()` animation controller that
/// outlives the fake image request completing) — pump a bounded number of
/// frames instead so async work (fake Firestore reads, fake Places calls,
/// debounce timers) gets a real chance to resolve without waiting on an
/// animation that never goes idle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = FakeImageHttpOverrides();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> seedGeography(FakeFirebaseFirestore firestore) async {
    await firestore.collection('regions').doc('region-7').set({
      'name': 'Central Visayas',
      'islandGroup': 'Visayas',
    });
    await firestore.collection('provinces').doc('cebu').set({
      'name': 'Cebu',
      'regionId': 'region-7',
      'regionName': 'Central Visayas',
      'islandGroup': 'Visayas',
    });
  }

  Future<ExploreScreen> buildScreen({
    required WidgetTester tester,
    required FakeFirebaseFirestore firestore,
    required PlacesService placesService,
    String? initialCategoryId,
  }) async {
    final screen = ExploreScreen(
      initialCategoryId: initialCategoryId,
      restaurantRepository: RestaurantRepository(firestore: firestore),
      festivalRepository: FestivalRepository(firestore: firestore),
      regionRepository: RegionRepository(firestore: firestore),
      provinceRepository: ProvinceRepository(firestore: firestore),
      placesService: placesService,
    );
    // Pinned to a phone-sized surface — same reasoning as
    // `home_screen_test.dart`'s identical pin: the default 800×600 test
    // surface would otherwise land in the responsive shell's "medium" tier
    // instead of "compact".
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(screen, firestore));
    await _settle(tester);
    return screen;
  }

  testWidgets(
    'Destinations tab shows only live Places results — LGU-curated tourist_spots never render',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await seedGeography(firestore);
      // Seeded to prove a curated destination is never shown anymore, not
      // to assert it renders — this is the whole point of the change.
      await firestore.collection('tourist_spots').doc('chocolate-hills').set({
        'name': 'Chocolate Hills',
        'status': 'published',
        'heroImageUrl': 'https://example.com/chocolate-hills.jpg',
      });
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
        }),
      );

      await buildScreen(
        tester: tester,
        firestore: firestore,
        placesService: placesService,
      );

      expect(find.text('Banaue Rice Terraces'), findsOneWidget);
      expect(find.text('Chocolate Hills'), findsNothing);
      // Never queried against the curated collection at all — DestinationRepository
      // isn't even constructed by ExploreScreen anymore, but assert on the
      // rendered widget type too as a belt-and-suspenders check.
      expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == 'DestinationCard'), findsNothing);
      // Google's 20-result cap means there's nothing to paginate — no
      // "Load More" button for this tab anymore.
      expect(find.text('Load More'), findsNothing);
    },
  );

  testWidgets(
    'tapping the Beaches category chip re-queries Places for that category',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await seedGeography(firestore);
      final placesService = PlacesService(
        caller: _fakePlacesSearchText({
          'top tourist attractions in the Philippines': [],
          'beaches in the Philippines': [
            {
              'id': 'places/alona',
              'displayName': {'text': 'Alona Beach'},
              'formattedAddress': 'Panglao, Bohol',
              'location': {'latitude': 9.55, 'longitude': 123.77},
            },
          ],
        }),
      );

      await buildScreen(
        tester: tester,
        firestore: firestore,
        placesService: placesService,
      );

      await tester.tap(find.text('Beaches'));
      // The category-chip tap is debounced (~350ms) before it re-queries.
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester);

      expect(find.text('Alona Beach'), findsOneWidget);
    },
  );

  testWidgets(
    'filters out a live result whose address leaks into a neighboring province when a province filter is applied',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await seedGeography(firestore);
      final placesService = PlacesService(
        caller: _fakePlacesSearchText({
          'top tourist attractions in the Philippines': [],
          'top tourist attractions in Cebu, Philippines': [
            {
              'id': 'places/cebu-heritage',
              'displayName': {'text': 'Cebu Heritage Monument'},
              'formattedAddress': 'Cebu City, Cebu',
              'location': {'latitude': 10.29, 'longitude': 123.9},
            },
            {
              'id': 'places/other-province-spot',
              'displayName': {'text': 'Some Other Province Spot'},
              'formattedAddress': 'Dumaguete, Negros Oriental',
              'location': {'latitude': 9.3, 'longitude': 123.3},
            },
          ],
        }),
      );

      await buildScreen(
        tester: tester,
        firestore: firestore,
        placesService: placesService,
      );

      await tester.tap(find.byIcon(Symbols.tune_rounded));
      await _settle(tester);

      await tester.tap(find.text('Central Visayas'));
      await _settle(tester);
      await tester.tap(find.text('Cebu'));
      await _settle(tester);
      await tester.tap(find.text('Apply'));
      await _settle(tester);

      expect(find.text('Cebu Heritage Monument'), findsOneWidget);
      expect(find.text('Some Other Province Spot'), findsNothing);
    },
  );

  testWidgets('tapping a live Places grid tile opens the place details sheet', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await seedGeography(firestore);
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
      }),
    );

    await buildScreen(
      tester: tester,
      firestore: firestore,
      placesService: placesService,
    );

    await tester.tap(find.text('Banaue Rice Terraces'));
    await _settle(tester);

    expect(find.byType(PlaceDetailsSheet), findsOneWidget);
    expect(find.text('Get Directions'), findsOneWidget);
  });

  testWidgets('map mode renders a GoogleMap without throwing', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await seedGeography(firestore);
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
      }),
    );

    await buildScreen(
      tester: tester,
      firestore: firestore,
      placesService: placesService,
    );

    await tester.tap(find.byTooltip('Show as map'));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(GoogleMap), findsOneWidget);
  });

  testWidgets(
    'the Festivals tab never calls PlacesService and still shows curated festivals',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await seedGeography(firestore);
      await firestore.collection('festivals').doc('sinulog').set({
        'name': 'Sinulog Festival',
        'status': 'published',
      });
      final placesService = PlacesService(
        caller: (name, data) async {
          fail('Festivals tab must never call a Places Cloud Function, got: $name');
        },
      );

      await buildScreen(
        tester: tester,
        firestore: firestore,
        placesService: placesService,
        initialCategoryId: 'festivals',
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Sinulog Festival'), findsOneWidget);
    },
  );

  testWidgets('the Restaurants tab also shows live Places results', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await seedGeography(firestore);
    await firestore.collection('restaurants').doc('lantaw').set({
      'name': 'Lantaw Native Restaurant',
      'status': 'published',
    });
    final placesService = PlacesService(
      caller: _fakePlacesSearchText({
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
      initialCategoryId: 'food',
    );

    expect(find.text('Abaca Baking Company'), findsOneWidget);
    expect(find.text('Lantaw Native Restaurant'), findsOneWidget);
  });
}
