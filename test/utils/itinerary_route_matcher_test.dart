import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/utils/itinerary_route_matcher.dart';
import 'package:tripnest_ph/data/mock/mock_destinations.dart';
import 'package:tripnest_ph/data/mock/mock_restaurants.dart';
import 'package:tripnest_ph/domain/models/itinerary.dart';
import 'package:tripnest_ph/domain/models/restaurant.dart';

void main() {
  // mockRestaurants.first is 'Bohol Bee Farm' (lat 9.5372, lng 123.7517);
  // mockDestinations.first is 'Chocolate Hills' (lat 9.9298, lng 124.1636).
  final restaurant = mockRestaurants.first;
  final destination = mockDestinations.first;

  test('resolves activities that name a real restaurant/destination, in activity order', () {
    final day = const ItineraryDay(
      dayNumber: 1,
      dateLabel: 'Day 1',
      activities: [
        ItineraryActivity(
          time: 'Morning',
          title: 'Visit Chocolate Hills',
          description: 'Sunrise at the viewpoint.',
          iconKey: 'landscape',
          location: 'Carmen viewpoint',
        ),
        ItineraryActivity(
          time: 'Afternoon',
          title: 'Lunch at Bohol Bee Farm',
          description: 'Organic buffet lunch.',
          iconKey: 'restaurant',
          location: 'Panglao',
        ),
        ItineraryActivity(
          time: 'Evening',
          title: 'Free time',
          description: 'Rest at the hotel.',
          iconKey: 'hotel',
          location: 'Hotel',
        ),
      ],
    );

    final stops = matchDayToRoute(day, restaurants: [restaurant], destinations: [destination]);

    expect(stops, hasLength(2));
    expect(stops[0].time, 'Morning');
    expect(stops[0].name, destination.name);
    expect(stops[0].destinationId, destination.id);
    expect(stops[0].restaurantId, isNull);
    expect(stops[0].latitude, destination.latitude);
    expect(stops[0].longitude, destination.longitude);
    expect(stops[1].time, 'Afternoon');
    expect(stops[1].name, restaurant.name);
    expect(stops[1].restaurantId, restaurant.id);
    expect(stops[1].destinationId, isNull);
  });

  test('does not match activities that mention no known place', () {
    final day = const ItineraryDay(
      dayNumber: 1,
      dateLabel: 'Day 1',
      activities: [
        ItineraryActivity(
          time: 'Morning',
          title: 'Explore the town',
          description: 'Wander around.',
          iconKey: 'landscape',
          location: 'Somewhere else entirely',
        ),
      ],
    );

    final stops = matchDayToRoute(day, restaurants: [restaurant], destinations: [destination]);

    expect(stops, isEmpty);
  });

  test('skips a candidate whose name is too short to match meaningfully', () {
    const shortNamed = Restaurant(
      id: 'spa',
      name: 'Spa',
      cuisine: 'N/A',
      provinceId: 'x',
      provinceName: 'X',
      regionId: 'region-x',
      heroImageUrl: '',
      galleryImageUrls: [],
      rating: 0,
      reviewCount: 0,
      priceRange: '₱',
      description: '',
      openingHours: '',
      menuHighlights: [],
      latitude: 1,
      longitude: 1,
    );
    final day = const ItineraryDay(
      dayNumber: 1,
      dateLabel: 'Day 1',
      activities: [
        ItineraryActivity(
          time: 'Morning',
          title: 'Relax at the Spa',
          description: 'A relaxing massage.',
          iconKey: 'landscape',
          location: 'Resort spa',
        ),
      ],
    );

    final stops = matchDayToRoute(day, restaurants: [shortNamed], destinations: const []);

    expect(stops, isEmpty);
  });

  test('skips a match that has no real coordinates on file', () {
    final noCoords = Restaurant(
      id: restaurant.id,
      name: restaurant.name,
      cuisine: restaurant.cuisine,
      provinceId: restaurant.provinceId,
      provinceName: restaurant.provinceName,
      regionId: restaurant.regionId,
      heroImageUrl: restaurant.heroImageUrl,
      galleryImageUrls: restaurant.galleryImageUrls,
      rating: restaurant.rating,
      reviewCount: restaurant.reviewCount,
      priceRange: restaurant.priceRange,
      description: restaurant.description,
      openingHours: restaurant.openingHours,
      menuHighlights: restaurant.menuHighlights,
    );
    final day = const ItineraryDay(
      dayNumber: 1,
      dateLabel: 'Day 1',
      activities: [
        ItineraryActivity(
          time: 'Afternoon',
          title: 'Lunch at Bohol Bee Farm',
          description: 'Organic buffet lunch.',
          iconKey: 'restaurant',
          location: 'Panglao',
        ),
      ],
    );

    final stops = matchDayToRoute(day, restaurants: [noCoords], destinations: const []);

    expect(stops, isEmpty);
  });
}
