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
import 'package:tripnest_ph/data/repositories/destination_repository.dart';
import 'package:tripnest_ph/data/repositories/favorites_repository.dart';
import 'package:tripnest_ph/data/repositories/festival_repository.dart';
import 'package:tripnest_ph/data/repositories/notification_repository.dart';
import 'package:tripnest_ph/data/repositories/province_repository.dart';
import 'package:tripnest_ph/data/repositories/region_repository.dart';
import 'package:tripnest_ph/data/repositories/restaurant_repository.dart';
import 'package:tripnest_ph/data/repositories/search_trend_repository.dart';
import 'package:tripnest_ph/data/repositories/travel_tip_repository.dart';
import 'package:tripnest_ph/data/repositories/user_repository.dart';
import 'package:tripnest_ph/presentation/explore/explore_screen.dart';
import 'package:tripnest_ph/presentation/festivals/upcoming_festivals_screen.dart';
import 'package:tripnest_ph/presentation/home/home_screen.dart';
import 'package:tripnest_ph/presentation/search/search_screen.dart';

import '../support/fake_image_http_overrides.dart';
import 'layout_harness.dart';

class _NoLocation extends LocationService {
  @override
  Future<LocationResult> resolveCurrentPosition() async =>
      const LocationResult(status: LocationAccessStatus.unavailable);
}

const _longNames = [
  'Banaue Rice Terraces',
  'Church of the Immaculate Conception and Museum of the Municipality',
  'Sunset View Boutique Hotel & Wellness Spa Resort by the Bay',
  'Cloud 9',
  'Mount Pinatubo Crater Lake Trek and Hot Spring Adventure Park',
  'Chocolate Hills Natural Monument Viewing Deck',
  'Kermit Surf Resort & Restaurant',
  'Puerto Princesa Subterranean River National Park',
];

List<Map<String, dynamic>> _places({String suffix = ''}) => [
      for (var i = 0; i < _longNames.length; i++)
        {
          'id': 'places/p$i$suffix',
          'displayName': {'text': _longNames[i]},
          'formattedAddress': 'Barangay Very Long Address Name $i, Some Municipality, Camarines Norte',
          'location': {'latitude': 10.0 + i * 0.1, 'longitude': 122.0 + i * 0.1},
          'rating': 4.0 + (i % 10) / 10,
          'userRatingCount': 100 + i,
          'types': i.isEven ? ['tourist_attraction'] : ['restaurant'],
        },
    ];

PlacesService _fakePlaces() => PlacesService(
      caller: (name, data) async => {'places': _places(suffix: (data['textQuery'] as String).hashCode.toString())},
    );

Future<void> _seed(FakeFirebaseFirestore firestore) async {
  await firestore.collection('regions').doc('region-7').set({'name': 'Central Visayas', 'islandGroup': 'Visayas'});
  await firestore.collection('provinces').doc('cebu').set({
    'name': 'Cebu',
    'regionId': 'region-7',
    'regionName': 'Central Visayas',
    'islandGroup': 'Visayas',
  });
  for (var i = 0; i < 6; i++) {
    await firestore.collection('restaurants').doc('r$i').set({
      'name': 'Lantaw Native Restaurant and Floating Bar Number $i',
      'nameLower': 'lantaw native restaurant $i',
      'cuisine': 'Filipino Seafood and Grill',
      'provinceId': 'cebu',
      'provinceName': 'Camarines Norte and Surigao',
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
      'businessId': 'biz$i',
      'status': 'published',
    });
    await firestore.collection('festivals').doc('f$i').set({
      'name': 'Sinulog Festival Grand Parade and Street Dancing Competition $i',
      'provinceId': 'cebu',
      'provinceName': 'Cebu',
      'regionId': 'region-7',
      'heroImageUrl': '',
      'galleryImageUrls': <String>[],
      'dateLabel': 'January 11–17, 2027',
      'month': 'JAN',
      'description': '',
      'highlights': <String>[],
      'rating': 4.8,
      'reviewCount': 200,
      'isUpcoming': true,
      'status': 'published',
    });
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = FakeImageHttpOverrides();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final firestore = FakeFirebaseFirestore();
  var seeded = false;

  Widget Function(Widget) providers() {
    return (app) {
      final auth = AuthProvider(
        authService: AuthService(auth: MockFirebaseAuth()),
        userRepository: UserRepository(
          firestore: firestore,
          destinationRepository: DestinationRepository(firestore: firestore),
        ),
      );
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<FavoritesProvider>.value(
            value: FavoritesProvider(repository: FavoritesRepository(firestore: firestore)),
          ),
        ],
        child: app,
      );
    };
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Widget home() => HomeScreen(
        placesService: _fakePlaces(),
        festivalRepository: FestivalRepository(firestore: firestore),
        travelTipRepository: TravelTipRepository(firestore: firestore),
        notificationRepository: NotificationRepository(firestore: firestore),
        locationService: _NoLocation(),
      );

  Widget explore({String? category}) => ExploreScreen(
        initialCategoryId: category,
        restaurantRepository: RestaurantRepository(firestore: firestore),
        festivalRepository: FestivalRepository(firestore: firestore),
        regionRepository: RegionRepository(firestore: firestore),
        provinceRepository: ProvinceRepository(firestore: firestore),
        placesService: _fakePlaces(),
      );

  Widget search() => SearchScreen(
        restaurantRepository: RestaurantRepository(firestore: firestore),
        festivalRepository: FestivalRepository(firestore: firestore),
        regionRepository: RegionRepository(firestore: firestore),
        provinceRepository: ProvinceRepository(firestore: firestore),
        placesService: _fakePlaces(),
        searchTrendRepository: SearchTrendRepository(firestore: firestore),
      );

  Future<void> prepare() async {
    if (!seeded) {
      seeded = true;
      await _seed(firestore);
    }
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await settle(tester);
    // The tab strip is the horizontal list holding "Destinations" — later tabs aren't built
    // until they're scrolled into view on a narrow screen.
    final strip = find
        .ancestor(
          of: find.text('Destinations').first,
          matching: find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.horizontal),
        )
        .first;
    // Pinned to the widget itself: 'Destinations' itself scrolls out of the
    // (lazily built) list once the strip is dragged.
    final stripWidget = find.byWidget(tester.widget(strip));
    final tab = find.descendant(of: stripWidget, matching: find.text(label));
    for (var i = 0; i < 8 && tab.evaluate().isEmpty; i++) {
      await tester.drag(stripWidget, const Offset(-120, 0));
      await tester.pump();
    }
    await tester.ensureVisible(tab);
    await tester.pump();
    await tester.tap(tab);
    await settle(tester);
  }

  layoutMatrix(
    'Home',
    home,
    wrap: providers(),
    setup: prepare,
    act: settle,
    verify: (_) => expect(find.byType(HomeScreen), findsOneWidget),
  );

  layoutMatrix(
    'Explore: destinations',
    explore,
    wrap: providers(),
    setup: prepare,
    act: settle,
    // Guards against a vacuous pass: the seeded Places results must render.
    verify: (_) => expect(find.text('Cloud 9'), findsWidgets),
  );

  layoutMatrix(
    'Explore: restaurants (food)',
    () => explore(category: 'food'),
    wrap: providers(),
    setup: prepare,
    act: settle,
    verify: (_) => expect(find.text('Cloud 9'), findsWidgets),
  );

  layoutMatrix(
    'Explore: festivals tab',
    explore,
    wrap: providers(),
    setup: prepare,
    act: (tester) => openTab(tester, 'Festivals'),
    verify: (_) => expect(find.textContaining('Sinulog Festival'), findsWidgets),
  );

  layoutMatrix(
    'Explore: restaurants tab',
    explore,
    wrap: providers(),
    setup: prepare,
    act: (tester) => openTab(tester, 'Restaurants'),
    verify: (_) => expect(find.textContaining('Lantaw Native'), findsWidgets),
  );

  layoutMatrix(
    'Explore: local finds tab',
    explore,
    wrap: providers(),
    setup: prepare,
    act: (tester) => openTab(tester, 'Local Finds'),
  );

  layoutMatrix('Search: empty', search, wrap: providers(), setup: prepare, act: settle);

  layoutMatrix(
    'Search: results',
    search,
    wrap: providers(),
    setup: prepare,
    act: (tester) async {
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Lantaw');
      await tester.pump(const Duration(milliseconds: 500));
      await settle(tester);
    },
    verify: (_) => expect(find.textContaining('Lantaw'), findsWidgets),
  );

  layoutMatrix(
    'Upcoming festivals (with data)',
    () => UpcomingFestivalsScreen(festivalRepository: FestivalRepository(firestore: firestore)),
    wrap: providers(),
    setup: prepare,
    act: settle,
    verify: (_) => expect(find.textContaining('Sinulog Festival'), findsWidgets),
  );
}
