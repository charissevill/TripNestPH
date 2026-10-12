import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/domain/models/destination.dart';
import 'package:tripnest_ph/domain/models/festival.dart';
import 'package:tripnest_ph/domain/models/province.dart';
import 'package:tripnest_ph/presentation/admin/admin_province_list_screen.dart';

import '../support/fake_image_http_overrides.dart';
import 'layout_harness.dart';

/// The Provinces table/list on its own — the screen around it builds
/// Firestore-backed repositories and can't run without a live Firebase app —
/// with enough rows to page and names long enough to stress every column.
void main() {
  setUpAll(() {
    HttpOverrides.global = FakeImageHttpOverrides();
  });

  final provinces = [
    for (var i = 0; i < 82; i++)
      Province(
        id: 'prov$i',
        name: i % 3 == 0 ? 'Province of Camarines Norte and Sur Number $i' : 'Province $i',
        regionId: i.isEven ? 'barmm' : 'car',
        regionName: i.isEven ? 'Bangsamoro Autonomous Region in Muslim Mindanao' : 'Cordillera Administrative Region',
        islandGroup: i.isEven ? 'Mindanao' : 'Luzon',
        hasContent: i % 4 != 0,
        heroImageUrl: i % 5 == 0 ? 'https://example.com/province-$i.jpg' : '',
      ),
  ];

  Widget view(List<Province> rows) => Scaffold(
        appBar: AppBar(title: const Text('Provinces')),
        body: AdminProvinceListView(provinces: rows, onOpen: (_) {}),
      );

  layoutMatrix(
    'Admin: provinces',
    () => view(provinces),
    verify: (_) => expect(find.textContaining('Province'), findsWidgets),
  );

  layoutMatrix(
    'Admin: provinces, no match',
    () => view(const []),
    verify: (_) => expect(find.text('No provinces found'), findsOneWidget),
  );

  final spots = [
    for (var i = 0; i < 5; i++)
      Destination(
        id: 'spot$i',
        name: i == 0 ? 'National Shrine of the Divine Mercy and Pilgrimage Gardens' : 'Tourist Spot $i',
        provinceId: 'prov0',
        provinceName: 'Province 0',
        regionId: 'barmm',
        categoryId: 'historical',
        heroImageUrl: i.isEven ? 'https://example.com/spot-$i.jpg' : '',
        galleryImageUrls: const [],
        rating: 0,
        reviewCount: 0,
        shortDescription: '',
        longDescription: '',
        entranceFee: 'Free',
        bestTimeToVisit: '',
        travelTips: const [],
        highlights: const [],
      ),
  ];
  final festivals = [
    for (var i = 0; i < 6; i++)
      Festival(
        id: 'fest$i',
        name: i == 0 ? 'Feast of the Kneeling Carabaos and Harvest Thanksgiving Parade' : 'Festival $i',
        provinceId: 'prov0',
        provinceName: 'Province 0',
        regionId: 'barmm',
        heroImageUrl: i.isEven ? 'https://example.com/festival-$i.jpg' : '',
        galleryImageUrls: const [],
        dateLabel: 'May 14–15, 2099',
        month: 'MAY',
        description: '',
        highlights: const [],
        rating: 0,
        reviewCount: 0,
        venue: i.isOdd ? 'San Isidro Labrador Parish Church, Pulilan' : '',
        // One already over, so it must be left out of "upcoming".
        startDate: i == 5 ? DateTime(2000) : DateTime(2099, 5, 14 + i),
        endDate: i == 5 ? DateTime(2000, 1, 2) : DateTime(2099, 5, 15 + i),
      ),
  ];

  // An LGU account's view of its own one province.
  Widget ownProvince(Province province) => Scaffold(
        appBar: AppBar(title: const Text('My Province')),
        body: AdminProvinceListView(
          provinces: [province],
          singleProvince: true,
          spots: Future.value(spots),
          festivals: Future.value(festivals),
          onOpenTouristSpots: () {},
          onOpenFestivals: () {},
          onOpen: (_) {},
        ),
      );

  layoutMatrix(
    'Admin: own province, empty',
    () => ownProvince(provinces[0]),
    verify: (_) {
      expect(find.text('Edit province details'), findsOneWidget);
      expect(find.text('Search provinces...'), findsNothing);
    },
  );

  layoutMatrix(
    'Admin: own province, filled',
    () => ownProvince(
      const Province(
        id: 'bulacan',
        name: 'Bulacan',
        regionId: 'region-3',
        regionName: 'Central Luzon',
        islandGroup: 'Luzon',
        hasContent: true,
        overview: 'Overview',
        bestTimeToVisit: 'November to February',
        estimatedDailyBudgetMin: 1500,
        estimatedDailyBudgetMax: 3000,
        travelTips: ['Bring cash'],
      ),
    ),
    // The checklist card can sit below the fold of a short window.
    verify: (_) => expect(find.text('Bulacan'), findsOneWidget),
  );

  layoutMatrix(
    'Admin: provinces, last page',
    () => view(provinces),
    act: (tester) async {
      // Only the table (wide enough for its columns) has a pager.
      final next = find.byTooltip('Next page');
      for (var i = 0; i < 40 && next.evaluate().isNotEmpty; i++) {
        if (tester.widget<IconButton>(find.ancestor(of: next, matching: find.byType(IconButton))).onPressed == null) {
          break;
        }
        await tester.tap(next);
        await tester.pump();
      }
    },
    verify: (tester) {
      if (find.byTooltip('Next page').evaluate().isEmpty) return;
      expect(find.textContaining('of 82 provinces'), findsOneWidget);
      expect(find.textContaining('–82 of 82'), findsOneWidget);
    },
  );
}
