import 'package:flutter_test/flutter_test.dart';
import 'package:tripnest_ph/domain/models/itinerary.dart';
import 'package:tripnest_ph/domain/models/packing_item.dart';

Itinerary _itineraryWithWeather(List<WeatherForecast> weather) {
  return Itinerary(
    destinationName: 'Baguio',
    coverImageUrl: '',
    totalDays: weather.length,
    travelers: 1,
    totalBudget: 5000,
    days: const [],
    budgetBreakdown: const [],
    weather: weather,
    travelTips: const [],
    recommendedRestaurantIds: const [],
    nearbyAttractionIds: const [],
  );
}

WeatherForecast _forecast(String condition, {int lowTemp = 25, int highTemp = 32}) {
  return WeatherForecast(dayLabel: 'Day 1', condition: condition, iconKey: 'wb_sunny', highTemp: highTemp, lowTemp: lowTemp);
}

void main() {
  group('PackingItem.suggestedFor()', () {
    test('falls back to exactly defaults() when there is no forecast', () {
      final itinerary = _itineraryWithWeather(const []);
      final suggested = PackingItem.suggestedFor(itinerary);
      expect(suggested.map((p) => p.label), PackingItem.defaults().map((p) => p.label));
    });

    test('adds rain gear when the forecast includes rain', () {
      final itinerary = _itineraryWithWeather([_forecast('Rainy')]);
      final labels = PackingItem.suggestedFor(itinerary).map((p) => p.label);
      expect(labels, contains('Umbrella'));
      expect(labels, contains('Waterproof bag / dry bag for electronics'));
    });

    test('adds sun protection when the forecast is sunny', () {
      final itinerary = _itineraryWithWeather([_forecast('Sunny')]);
      final labels = PackingItem.suggestedFor(itinerary).map((p) => p.label);
      expect(labels, contains('Sunglasses'));
      expect(labels, contains('Hat or cap'));
    });

    test('adds a warm layer when a day is forecast cool (e.g. a highland trip)', () {
      final itinerary = _itineraryWithWeather([_forecast('Overcast', lowTemp: 15, highTemp: 24)]);
      final labels = PackingItem.suggestedFor(itinerary).map((p) => p.label);
      expect(labels, contains('Extra warm layer for cool mornings/evenings'));
    });

    test('never suggests a warm layer for a typical warm lowland forecast', () {
      final itinerary = _itineraryWithWeather([_forecast('Sunny', lowTemp: 26, highTemp: 33)]);
      final labels = PackingItem.suggestedFor(itinerary).map((p) => p.label);
      expect(labels, isNot(contains('Extra warm layer for cool mornings/evenings')));
    });

    test('always includes every default item, on top of any weather extras', () {
      final itinerary = _itineraryWithWeather([_forecast('Rainy')]);
      final labels = PackingItem.suggestedFor(itinerary).map((p) => p.label).toSet();
      for (final defaultItem in PackingItem.defaults()) {
        expect(labels, contains(defaultItem.label));
      }
    });
  });
}
