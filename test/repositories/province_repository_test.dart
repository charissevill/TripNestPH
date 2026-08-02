import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/data/repositories/province_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProvinceRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = ProvinceRepository(firestore: firestore);
  });

  test('getAll() returns every seeded province', () async {
    await firestore.collection('provinces').doc('bohol').set({
      'name': 'Bohol',
      'regionId': 'region-7',
      'regionName': 'Central Visayas',
      'islandGroup': 'Visayas',
    });
    await firestore.collection('provinces').doc('cebu').set({
      'name': 'Cebu',
      'regionId': 'region-7',
      'regionName': 'Central Visayas',
      'islandGroup': 'Visayas',
    });

    final provinces = await repository.getAll();

    expect(provinces, hasLength(2));
    expect(provinces.map((p) => p.id), containsAll(['bohol', 'cebu']));
  });

  test(
    'updateContent() fills in overview/culture/budget and flips hasContent to true — the "content coming soon" fix',
    () async {
      await firestore.collection('provinces').doc('bohol').set({
        'name': 'Bohol',
        'regionId': 'region-7',
        'regionName': 'Central Visayas',
        'islandGroup': 'Visayas',
        'hasContent': false,
        'heroImageUrl': 'https://example.com/existing-hero.jpg',
      });

      await repository.updateContent(
        'bohol',
        overview: 'A province known for the Chocolate Hills and tarsiers.',
        localCulture:
            'Boholano hospitality and the Loboc River cruise tradition.',
        bestTimeToVisit: 'December to May',
        estimatedDailyBudgetMin: 1500,
        estimatedDailyBudgetMax: 4000,
        travelTips: const [
          'Bring cash — many rural spots do not accept cards.',
        ],
        emergencyHotlines: const [],
        heroImageUrl: 'https://example.com/existing-hero.jpg',
        galleryImageUrls: const [],
      );

      final updated = await repository.getById('bohol');
      expect(updated!.hasContent, isTrue);
      expect(
        updated.overview,
        'A province known for the Chocolate Hills and tarsiers.',
      );
      expect(updated.estimatedDailyBudgetMin, 1500);
      expect(updated.estimatedDailyBudgetMax, 4000);
      expect(updated.travelTips, [
        'Bring cash — many rural spots do not accept cards.',
      ]);
      // The hero image passed straight through unchanged — bulk-filling text
      // content must never blank out an already-set photo.
      expect(updated.heroImageUrl, 'https://example.com/existing-hero.jpg');
    },
  );
}
