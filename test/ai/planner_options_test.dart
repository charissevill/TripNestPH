import 'package:flutter_test/flutter_test.dart';
import 'package:tripnest_ph/ai/planner_options.dart';
import 'package:tripnest_ph/core/theme/app_colors.dart';
import 'package:tripnest_ph/core/utils/icon_registry.dart';

void main() {
  group('inferBudgetTier()', () {
    test('returns Budget below the Mid-range threshold', () {
      expect(inferBudgetTier(0), ('Budget', '₱5k – ₱15k'));
      expect(inferBudgetTier(14999), ('Budget', '₱5k – ₱15k'));
    });

    test('returns Mid-range at and above its threshold, below Luxury\'s', () {
      expect(inferBudgetTier(15000), ('Mid-range', '₱15k – ₱40k'));
      expect(inferBudgetTier(39999), ('Mid-range', '₱15k – ₱40k'));
    });

    test('returns Luxury at and above its threshold', () {
      expect(inferBudgetTier(40000), ('Luxury', '₱40k+'));
      expect(inferBudgetTier(100000), ('Luxury', '₱40k+'));
    });
  });

  group('planner option lists', () {
    test('every tier/transport/interest/traveler-type/pace option has a distinct label', () {
      expect(budgetTiers.map((t) => t.label).toSet(), hasLength(budgetTiers.length));
      expect(transportOptions.map((o) => o.$1).toSet(), hasLength(transportOptions.length));
      expect(interestOptions.map((o) => o.$1).toSet(), hasLength(interestOptions.length));
      expect(travelerTypeOptions.map((o) => o.$1).toSet(), hasLength(travelerTypeOptions.length));
      expect(tripPaceOptions.map((o) => o.$1).toSet(), hasLength(tripPaceOptions.length));
    });

    test('the defaults are themselves valid options', () {
      expect(transportOptions.map((o) => o.$1), contains(defaultTransportation));
      expect(interestOptions.map((o) => o.$1).toSet().containsAll(defaultInterests), isTrue);
    });
  });

  group('ItineraryPrompts allow-lists stay derived, not duplicated', () {
    test('IconRegistry.contentKeys excludes only the weather-condition icons', () {
      expect(IconRegistry.contentKeys, isNot(contains('cloud')));
      expect(IconRegistry.contentKeys, isNot(contains('rainy')));
      expect(IconRegistry.contentKeys, isNot(contains('thunderstorm')));
      expect(IconRegistry.contentKeys, isNot(contains('foggy')));
      expect(IconRegistry.contentKeys, contains('restaurant'));
      expect(IconRegistry.contentKeys, contains('hotel'));
    });

    test('AppColors.paletteKeys covers every case byKey() actually handles', () {
      for (final key in AppColors.paletteKeys) {
        expect(AppColors.byKey(key), isNotNull);
      }
      expect(AppColors.paletteKeys, contains('primary'));
    });
  });
}
