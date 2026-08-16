import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripnest_ph/domain/models/restaurant.dart';

void main() {
  group('Restaurant.fromMap()', () {
    test('accessibilityTags defaults to empty when absent', () {
      final restaurant = Restaurant.fromMap('r1', const {
        'name': 'Test',
        'provinceId': 'p1',
        'provinceName': 'Test Province',
        'regionId': 'r1',
        'heroImageUrl': '',
        'galleryImageUrls': [],
        'rating': 0,
        'reviewCount': 0,
        'priceRange': '₱',
        'description': '',
        'openingHours': '',
        'menuHighlights': [],
      });

      expect(restaurant.accessibilityTags, isEmpty);
      expect(restaurant.reviewDigest, isNull);
    });

    test('parses accessibilityTags and reviewDigest when present', () {
      final restaurant = Restaurant.fromMap('r1', {
        'name': 'Test',
        'provinceId': 'p1',
        'provinceName': 'Test Province',
        'regionId': 'r1',
        'heroImageUrl': '',
        'galleryImageUrls': <String>[],
        'rating': 0,
        'reviewCount': 5,
        'priceRange': '₱',
        'description': '',
        'openingHours': '',
        'menuHighlights': <Map<String, dynamic>>[],
        'accessibilityTags': ['Step-free entrance', 'Accessible restroom'],
        'reviewDigest': {
          'summary': 'Travelers generally praise the food, though a few mention slow service.',
          'reviewCountAtGeneration': 5,
          'generatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        },
      });

      expect(restaurant.accessibilityTags, ['Step-free entrance', 'Accessible restroom']);
      expect(restaurant.reviewDigest, isNotNull);
      expect(restaurant.reviewDigest!.summary, contains('praise the food'));
      expect(restaurant.reviewDigest!.reviewCountAtGeneration, 5);
      expect(restaurant.reviewDigest!.generatedAt, DateTime(2026, 1, 1));
    });

    test('copyWith() preserves accessibilityTags and reviewDigest', () {
      final original = Restaurant.fromMap('r1', {
        'name': 'Test',
        'provinceId': 'p1',
        'provinceName': 'Test Province',
        'regionId': 'r1',
        'heroImageUrl': '',
        'galleryImageUrls': <String>[],
        'rating': 4.0,
        'reviewCount': 5,
        'priceRange': '₱',
        'description': '',
        'openingHours': '',
        'menuHighlights': <Map<String, dynamic>>[],
        'accessibilityTags': ['Step-free entrance'],
      });

      final updated = original.copyWith(rating: 4.5);

      expect(updated.accessibilityTags, ['Step-free entrance']);
      expect(updated.rating, 4.5);
    });
  });
}
