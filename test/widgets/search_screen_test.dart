import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:tripnest_ph/data/repositories/search_trend_repository.dart';
import 'package:tripnest_ph/presentation/search/search_screen.dart';

/// Fakes the `placesSearchText` Cloud Function, keyed by exact `textQuery` —
/// same seam `test/ai/ai_repository_test.dart` already established. Fails
/// the test outright if a query outside [responsesByQuery] is attempted, so
/// a test asserting "no live search fired" catches an unexpected call
/// instead of silently returning an empty list for it.
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

// PlaceDetailsSheet's bookmark button needs a FavoritesProvider ancestor,
// same as DestinationCard/RestaurantCard elsewhere.
Widget _wrap(Widget child, FakeFirebaseFirestore firestore) {
  return ChangeNotifierProvider<FavoritesProvider>(
    create: (_) => FavoritesProvider(repository: FavoritesRepository(firestore: firestore)),
    child: MaterialApp(home: child),
  );
}

/// `find.text()` also matches the search field's own `EditableText` when
/// its typed value happens to equal the string being searched for (e.g.
/// typing "Loboc River" then asserting a result tile shows "Loboc River")
/// — this scopes the match to an actual rendered `Text` widget only.
Finder _findTileText(String text) =>
    find.byWidgetPredicate((w) => w is Text && w.data == text);

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SearchScreen> buildScreen({
    required WidgetTester tester,
    required FakeFirebaseFirestore firestore,
    required PlacesService placesService,
  }) async {
    final screen = SearchScreen(
      restaurantRepository: RestaurantRepository(firestore: firestore),
      festivalRepository: FestivalRepository(firestore: firestore),
      regionRepository: RegionRepository(firestore: firestore),
      provinceRepository: ProvinceRepository(firestore: firestore),
      placesService: placesService,
      searchTrendRepository: SearchTrendRepository(firestore: firestore),
    );
    await tester.pumpWidget(_wrap(screen, firestore));
    await tester.pumpAndSettle();
    return screen;
  }

  testWidgets(
    'shows a live Places result in a "More places" section for a non-empty query',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final placesService = PlacesService(
        caller: _fakePlacesSearchText({
          'Alona Beach, Philippines': [
            {
              'id': 'places/alona-beach',
              'displayName': {'text': 'Alona Beach'},
              'formattedAddress': 'Panglao, Bohol',
              'location': {'latitude': 9.5488, 'longitude': 123.7729},
            },
          ],
        }),
      );
      await buildScreen(
        tester: tester,
        firestore: firestore,
        placesService: placesService,
      );

      await tester.enterText(find.byType(TextField), 'Alona Beach');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('More places'), findsOneWidget);
      expect(_findTileText('Alona Beach'), findsOneWidget);
      expect(find.text('Panglao, Bohol'), findsOneWidget);
    },
  );

  testWidgets(
    'does not fire a live Places search for a query shorter than 3 characters',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      // Any call here fails the test — asserts the length gate actually
      // prevents a billed API call on very short prefixes.
      final placesService = PlacesService(
        caller: _fakePlacesSearchText(const {}),
      );
      await buildScreen(
        tester: tester,
        firestore: firestore,
        placesService: placesService,
      );

      await tester.enterText(find.byType(TextField), 'Al');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('More places'), findsNothing);
    },
  );

  testWidgets(
    'suppresses a live Places result that duplicates an already-matched curated restaurant',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('restaurants').doc('bee-farm').set({
        'name': 'Bohol Bee Farm',
        'nameLower': 'bohol bee farm',
        'cuisine': 'Filipino',
        'provinceId': 'bohol',
        'provinceName': 'Bohol',
        'regionId': 'region-7',
        'heroImageUrl': '',
        'galleryImageUrls': <String>[],
        'rating': 4.7,
        'reviewCount': 100,
        'priceRange': '₱₱',
        'description': '',
        'openingHours': '',
        'menuHighlights': <String>[],
        'status': 'published',
      });
      final placesService = PlacesService(
        caller: _fakePlacesSearchText({
          'Bohol Bee Farm, Philippines': [
            {
              'id': 'places/bee-farm',
              'displayName': {'text': 'Bohol Bee Farm'},
              'location': {'latitude': 9.5372, 'longitude': 123.7517},
            },
          ],
        }),
      );
      await buildScreen(
        tester: tester,
        firestore: firestore,
        placesService: placesService,
      );

      await tester.enterText(find.byType(TextField), 'Bohol Bee Farm');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // The curated restaurant tile shows once; no separate "More places"
      // section duplicates the same real place.
      expect(_findTileText('Bohol Bee Farm'), findsOneWidget);
      expect(find.text('More places'), findsNothing);
    },
  );

  testWidgets(
    'shows a province-guide tile when the query matches a province name',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('provinces').doc('cebu').set({
        'name': 'Cebu',
        'regionId': 'region-7',
        'regionName': 'Central Visayas',
        'islandGroup': 'Visayas',
      });
      // Neither destinations/restaurants/festivals nor a live Places lookup
      // ever match a bare province name — this asserts the province tile is
      // what actually surfaces "Cebu", not a coincidental Places result.
      final placesService = PlacesService(
        caller: _fakePlacesSearchText({'Cebu, Philippines': []}),
      );
      await buildScreen(
        tester: tester,
        firestore: firestore,
        placesService: placesService,
      );

      await tester.enterText(find.byType(TextField), 'Cebu');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Province Guide'), findsOneWidget);
      expect(_findTileText('Cebu'), findsOneWidget);
      expect(find.text('Central Visayas'), findsOneWidget);
      expect(find.text('No results for "Cebu"'), findsNothing);
    },
  );

  testWidgets(
    'shows a typo-tolerant province match when the query is misspelled',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('provinces').doc('cebu').set({
        'name': 'Cebu',
        'regionId': 'region-7',
        'regionName': 'Central Visayas',
        'islandGroup': 'Visayas',
      });
      final placesService = PlacesService(
        caller: _fakePlacesSearchText({'Cebo, Philippines': []}),
      );
      await buildScreen(
        tester: tester,
        firestore: firestore,
        placesService: placesService,
      );

      await tester.enterText(find.byType(TextField), 'Cebo');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Province Guide'), findsOneWidget);
      expect(_findTileText('Cebu'), findsOneWidget);
    },
  );

  testWidgets(
    'shows provinces in a matching region when the query is a region name',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
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
      await firestore.collection('provinces').doc('bohol').set({
        'name': 'Bohol',
        'regionId': 'region-7',
        'regionName': 'Central Visayas',
        'islandGroup': 'Visayas',
      });
      final placesService = PlacesService(
        caller: _fakePlacesSearchText({'Central Visayas, Philippines': []}),
      );
      await buildScreen(
        tester: tester,
        firestore: firestore,
        placesService: placesService,
      );

      await tester.enterText(find.byType(TextField), 'Central Visayas');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Provinces in Central Visayas'), findsOneWidget);
      expect(_findTileText('Cebu'), findsOneWidget);
      expect(_findTileText('Bohol'), findsOneWidget);
    },
  );

  testWidgets(
    'follows up a bare city-name match with real nearby places, not just the city itself',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      // Mirrors what Google actually returns for a bare city/town name: a
      // single locality-type match, never a rich list of businesses (the
      // same limitation already handled for bare province names).
      final placesService = PlacesService(
        caller: (name, data) async {
          if (name == 'placesSearchText') {
            expect(data['textQuery'], 'Bacolod, Philippines');
            return {
              'places': [
                {
                  'id': 'places/bacolod-city',
                  'displayName': {'text': 'Bacolod'},
                  'types': ['locality', 'political'],
                  'location': {'latitude': 10.6765, 'longitude': 122.9509},
                },
              ],
            };
          }
          if (name == 'placesSearchNearby') {
            expect(data['latitude'], 10.6765);
            expect(data['longitude'], 122.9509);
            return {
              'places': [
                {
                  'id': 'places/manokan-country',
                  'displayName': {'text': 'Manokan Country'},
                  'types': ['restaurant'],
                  'formattedAddress': 'Bacolod City',
                  'location': {'latitude': 10.68, 'longitude': 122.95},
                },
              ],
            };
          }
          fail('Unexpected function call: $name');
        },
      );
      await buildScreen(
        tester: tester,
        firestore: firestore,
        placesService: placesService,
      );

      await tester.enterText(find.byType(TextField), 'Bacolod');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(_findTileText('Bacolod'), findsOneWidget);
      expect(_findTileText('Manokan Country'), findsOneWidget);
    },
  );

  testWidgets(
    'follows up a bare province-name match (administrative_area_level_2) with real nearby places too',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      // Mirrors what Google actually returns for a bare province name like
      // "Guimaras": a single administrative_area_level_2 match, not the
      // `locality` type the city-name case above uses — the fix has to
      // catch both granularities, and use a wider radius for a province
      // (it covers far more ground than a single city/town).
      final placesService = PlacesService(
        caller: (name, data) async {
          if (name == 'placesSearchText') {
            expect(data['textQuery'], 'Guimaras, Philippines');
            return {
              'places': [
                {
                  'id': 'places/guimaras-province',
                  'displayName': {'text': 'Guimaras'},
                  'types': ['administrative_area_level_2', 'political'],
                  'location': {'latitude': 10.5929, 'longitude': 122.6325},
                },
              ],
            };
          }
          if (name == 'placesSearchNearby') {
            expect(data['latitude'], 10.5929);
            expect(data['longitude'], 122.6325);
            expect(data['radiusMeters'], 15000);
            return {
              'places': [
                {
                  'id': 'places/trappist-monastery',
                  'displayName': {'text': 'Trappist Monastery'},
                  'types': ['tourist_attraction'],
                  'formattedAddress': 'Buenavista, Guimaras',
                  'location': {'latitude': 10.6, 'longitude': 122.63},
                },
              ],
            };
          }
          fail('Unexpected function call: $name');
        },
      );
      await buildScreen(
        tester: tester,
        firestore: firestore,
        placesService: placesService,
      );

      await tester.enterText(find.byType(TextField), 'Guimaras');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(_findTileText('Guimaras'), findsOneWidget);
      expect(_findTileText('Trappist Monastery'), findsOneWidget);
    },
  );

  testWidgets(
    'filters out a nearby result whose address leaks into a neighboring city/province',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      // Guimaras is a narrow island a few km across a strait from Iloilo
      // City — a fixed-radius nearby search around it genuinely picks up
      // real Iloilo City hotels too. A hotel addressed in "Iloilo City" is
      // not a real answer to someone who searched "Guimaras", so it must be
      // dropped even though the raw Places API happily returned it.
      final placesService = PlacesService(
        caller: (name, data) async {
          if (name == 'placesSearchText') {
            expect(data['textQuery'], 'Guimaras, Philippines');
            return {
              'places': [
                {
                  'id': 'places/guimaras-province',
                  'displayName': {'text': 'Guimaras'},
                  'types': ['administrative_area_level_2', 'political'],
                  'location': {'latitude': 10.5929, 'longitude': 122.6325},
                },
              ],
            };
          }
          if (name == 'placesSearchNearby') {
            return {
              'places': [
                {
                  'id': 'places/trappist-monastery',
                  'displayName': {'text': 'Trappist Monastery'},
                  'types': ['tourist_attraction'],
                  'formattedAddress': 'Buenavista, Guimaras',
                  'location': {'latitude': 10.6, 'longitude': 122.63},
                },
                {
                  'id': 'places/robertos',
                  'displayName': {'text': "Roberto's"},
                  'types': ['restaurant'],
                  'formattedAddress':
                      '61 JM Basa St, Iloilo City Proper, Iloilo City, Iloilo',
                  'location': {'latitude': 10.7, 'longitude': 122.56},
                },
              ],
            };
          }
          fail('Unexpected function call: $name');
        },
      );
      await buildScreen(
        tester: tester,
        firestore: firestore,
        placesService: placesService,
      );

      await tester.enterText(find.byType(TextField), 'Guimaras');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(_findTileText('Trappist Monastery'), findsOneWidget);
      expect(_findTileText("Roberto's"), findsNothing);
    },
  );

  testWidgets(
    'does not fire a nearby-places follow-up for a whole-region match (administrative_area_level_1)',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      // The area-match detection is deliberately general (any `political`
      // place, to catch every granularity from barangay to province) — this
      // guards that a whole region doesn't slip through that generality:
      // it's still excluded, since a fixed-radius search can't meaningfully
      // cover an entire region, and _matchingRegion already lists its
      // provinces instead. `placesSearchNearby` must never be called here.
      final placesService = PlacesService(
        caller: (name, data) async {
          if (name == 'placesSearchText') {
            expect(data['textQuery'], 'Ilocos Region, Philippines');
            return {
              'places': [
                {
                  'id': 'places/ilocos-region',
                  'displayName': {'text': 'Ilocos Region'},
                  'types': ['administrative_area_level_1', 'political'],
                  'location': {'latitude': 17.5, 'longitude': 120.5},
                },
              ],
            };
          }
          fail('Unexpected function call: $name');
        },
      );
      await buildScreen(
        tester: tester,
        firestore: firestore,
        placesService: placesService,
      );

      await tester.enterText(find.byType(TextField), 'Ilocos Region');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(_findTileText('Ilocos Region'), findsOneWidget);
    },
  );

  testWidgets('tapping a live place tile opens the place details sheet', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final placesService = PlacesService(
      caller: _fakePlacesSearchText({
        'Loboc River, Philippines': [
          {
            'id': 'places/loboc-river',
            'displayName': {'text': 'Loboc River'},
            'formattedAddress': 'Loboc, Bohol',
            'location': {'latitude': 9.6382, 'longitude': 124.0181},
          },
        ],
      }),
    );
    await buildScreen(
      tester: tester,
      firestore: firestore,
      placesService: placesService,
    );

    await tester.enterText(find.byType(TextField), 'Loboc River');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(_findTileText('Loboc River'));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceDetailsSheet), findsOneWidget);
    expect(find.text('Get Directions'), findsOneWidget);
  });
}
