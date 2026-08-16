import 'package:flutter_test/flutter_test.dart';
import 'package:tripnest_ph/domain/models/itinerary.dart';

Itinerary _itinerary({required List<ItineraryDay> days}) {
  return Itinerary(
    destinationName: 'Bohol',
    coverImageUrl: '',
    totalDays: days.length,
    travelers: 2,
    totalBudget: 5000,
    days: days,
    budgetBreakdown: const [],
    weather: const [],
    travelTips: const [],
    recommendedRestaurantIds: const [],
    nearbyAttractionIds: const [],
    accommodationName: 'Test Resort',
  );
}

void main() {
  group('Itinerary.copyWith()', () {
    test('replaces only days, leaving every other field untouched', () {
      final original = _itinerary(
        days: const [
          ItineraryDay(dayNumber: 1, dateLabel: 'Day 1', activities: []),
        ],
      );
      final newDays = const [
        ItineraryDay(
          dayNumber: 1,
          dateLabel: 'Day 1',
          activities: [
            ItineraryActivity(time: 'Morning', title: 'Beach', description: 'Relax', iconKey: 'beach_access', location: 'Alona'),
          ],
        ),
      ];

      final updated = original.copyWith(days: newDays);

      expect(updated.days, newDays);
      expect(updated.destinationName, original.destinationName);
      expect(updated.totalBudget, original.totalBudget);
      expect(updated.accommodationName, original.accommodationName);
      expect(updated.travelers, original.travelers);
    });

    test('with no argument returns the same days, unchanged', () {
      final original = _itinerary(
        days: const [ItineraryDay(dayNumber: 1, dateLabel: 'Day 1', activities: [])],
      );

      final updated = original.copyWith();

      expect(updated.days, original.days);
    });
  });
}
