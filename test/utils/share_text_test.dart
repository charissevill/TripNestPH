import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/utils/itinerary_export.dart';
import 'package:tripnest_ph/core/utils/share_text.dart';
import 'package:tripnest_ph/data/mock/mock_destinations.dart';
import 'package:tripnest_ph/data/mock/mock_festivals.dart';
import 'package:tripnest_ph/data/mock/mock_itinerary.dart';
import 'package:tripnest_ph/data/mock/mock_restaurants.dart';

void main() {
  group('ShareText', () {
    test('forDestination() includes the name, province and rating', () {
      final destination = mockDestinations.first;
      final text = ShareText.forDestination(destination);

      expect(text, contains(destination.name));
      expect(text, contains(destination.provinceName));
      expect(text, contains(destination.rating.toStringAsFixed(1)));
      expect(text, contains('TripNest PH'));
      expect(text, isNot(contains('http')));
    });

    test('forRestaurant() includes the name and cuisine', () {
      final restaurant = mockRestaurants.first;
      final text = ShareText.forRestaurant(restaurant);

      expect(text, contains(restaurant.name));
      expect(text, contains(restaurant.cuisine));
    });

    test('forFestival() includes the name and date label', () {
      final festival = mockFestivals.first;
      final text = ShareText.forFestival(festival);

      expect(text, contains(festival.name));
      expect(text, contains(festival.dateLabel));
    });
  });

  group('ItineraryExport', () {
    test('buildShareText() lists every day and travel tip', () {
      final text = ItineraryExport.buildShareText(mockItinerary);

      expect(text, contains(mockItinerary.destinationName));
      for (final day in mockItinerary.days) {
        expect(text, contains('Day ${day.dayNumber}'));
      }
      for (final tip in mockItinerary.travelTips) {
        expect(text, contains(tip));
      }
    });

    test('buildPdfBytes() produces a non-empty PDF document', () async {
      final bytes = await ItineraryExport.buildPdfBytes(mockItinerary);

      expect(bytes, isNotEmpty);
      // "%PDF" magic bytes — confirms this is actually a PDF, not garbage.
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });
}
