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

  test('matches a Places API recommendation (accommodation/attraction) with no Firestore id', () {
    const place = PlaceRecommendation(
      placeId: 'places/abc123',
      name: 'Cagsawa Ruins',
      latitude: 13.1391,
      longitude: 123.6864,
      mapsUri: 'https://maps.google.com/?cid=123',
    );
    final day = const ItineraryDay(
      dayNumber: 1,
      dateLabel: 'Day 1',
      activities: [
        ItineraryActivity(
          time: 'Morning',
          title: 'Cagsawa Ruins Visit',
          description: 'See the iconic ruins framed by Mayon Volcano.',
          iconKey: 'landscape',
          location: 'Cagsawa, Albay',
        ),
      ],
    );

    final stops = matchDayToRoute(day, restaurants: const [], destinations: const [], placeRecommendations: const [place]);

    expect(stops, hasLength(1));
    expect(stops[0].name, 'Cagsawa Ruins');
    expect(stops[0].placeMapsUri, 'https://maps.google.com/?cid=123');
    expect(stops[0].destinationId, isNull);
    expect(stops[0].restaurantId, isNull);
  });

  test('matches activities describing the trip\'s own destination, which is never in `destinations`', () {
    final day = const ItineraryDay(
      dayNumber: 1,
      dateLabel: 'Day 1',
      activities: [
        ItineraryActivity(
          time: 'Morning',
          title: 'Explore Kawasan Falls',
          description: 'Take in the scenery.',
          iconKey: 'landscape',
          location: 'Kawasan Falls, Cebu',
        ),
        ItineraryActivity(
          time: 'Afternoon',
          title: 'Canyoneering at Kawasan Falls',
          description: 'Go canyoneering with a certified guide.',
          iconKey: 'hiking',
          location: 'Kawasan Falls, Cebu',
        ),
      ],
    );

    // Deliberately empty `destinations` — matches the app's real behavior
    // (the trip's own destination is never included in that list).
    final stops = matchDayToRoute(
      day,
      restaurants: const [],
      destinations: const [],
      mainDestinationId: 'kawasan-falls',
      mainDestinationName: 'Kawasan Falls',
      mainDestinationLatitude: 9.8225,
      mainDestinationLongitude: 123.3803,
    );

    expect(stops, hasLength(2));
    expect(stops[0].destinationId, 'kawasan-falls');
    expect(stops[0].latitude, 9.8225);
    expect(stops[1].destinationId, 'kawasan-falls');
  });

  test('does not match the main destination when no coordinates are given for it', () {
    final day = const ItineraryDay(
      dayNumber: 1,
      dateLabel: 'Day 1',
      activities: [
        ItineraryActivity(
          time: 'Morning',
          title: 'Explore Kawasan Falls',
          description: 'Take in the scenery.',
          iconKey: 'landscape',
          location: 'Kawasan Falls, Cebu',
        ),
      ],
    );

    final stops = matchDayToRoute(
      day,
      restaurants: const [],
      destinations: const [],
      mainDestinationName: 'Kawasan Falls',
    );

    expect(stops, isEmpty);
  });

  test('matches a place named only in the description, not the title/location', () {
    final day = ItineraryDay(
      dayNumber: 1,
      dateLabel: 'Day 1',
      activities: [
        ItineraryActivity(
          time: 'Afternoon',
          title: 'Explore the town',
          description: 'Visit ${destination.name} and take in the view.',
          iconKey: 'landscape',
          location: 'Town center',
        ),
      ],
    );

    final stops = matchDayToRoute(day, restaurants: const [], destinations: [destination]);

    expect(stops, hasLength(1));
    expect(stops[0].name, destination.name);
    expect(stops[0].destinationId, destination.id);
  });

  test('anchors to the main destination when a day has no specific matches at all', () {
    final day = const ItineraryDay(
      dayNumber: 2,
      dateLabel: 'Day 2',
      activities: [
        ItineraryActivity(
          time: 'Morning',
          title: 'Beach Relaxation',
          description: 'Relax at a nearby beach.',
          iconKey: 'beach_access',
          location: 'A nearby beach',
        ),
        ItineraryActivity(
          time: 'Afternoon',
          title: 'Island Hopping',
          description: 'Explore the nearby islands.',
          iconKey: 'directions_boat',
          location: 'Nearby islands',
        ),
      ],
    );

    final stops = matchDayToRoute(
      day,
      restaurants: const [],
      destinations: const [],
      mainDestinationId: 'panglao',
      mainDestinationName: 'Panglao',
      mainDestinationLatitude: 9.5885,
      mainDestinationLongitude: 123.7521,
    );

    expect(stops, hasLength(1));
    expect(stops[0].time, 'Overview');
    expect(stops[0].destinationId, 'panglao');
    expect(stops[0].latitude, 9.5885);
  });

  test('adds the main-destination anchor alongside a single specific match', () {
    final day = ItineraryDay(
      dayNumber: 1,
      dateLabel: 'Day 1',
      activities: [
        ItineraryActivity(
          time: 'Morning',
          title: 'Lunch at ${restaurant.name}',
          description: '',
          iconKey: 'restaurant',
          location: '',
        ),
        const ItineraryActivity(time: 'Afternoon', title: 'Free time', description: '', iconKey: 'hotel', location: ''),
      ],
    );

    final stops = matchDayToRoute(
      day,
      restaurants: [restaurant],
      destinations: const [],
      mainDestinationId: 'panglao',
      mainDestinationName: 'Panglao',
      mainDestinationLatitude: 9.5885,
      mainDestinationLongitude: 123.7521,
    );

    expect(stops, hasLength(2));
    expect(stops[0].restaurantId, restaurant.id);
    expect(stops[1].time, 'Overview');
    expect(stops[1].destinationId, 'panglao');
  });

  test('does not add an anchor on top of a day that already has 2+ specific matches', () {
    final day = ItineraryDay(
      dayNumber: 1,
      dateLabel: 'Day 1',
      activities: [
        ItineraryActivity(
          time: 'Morning',
          title: 'Visit ${destination.name}',
          description: '',
          iconKey: 'landscape',
          location: '',
        ),
        ItineraryActivity(
          time: 'Afternoon',
          title: 'Lunch at ${restaurant.name}',
          description: '',
          iconKey: 'restaurant',
          location: '',
        ),
      ],
    );

    final stops = matchDayToRoute(
      day,
      restaurants: [restaurant],
      destinations: [destination],
      mainDestinationId: 'panglao',
      mainDestinationName: 'Panglao',
      mainDestinationLatitude: 9.5885,
      mainDestinationLongitude: 123.7521,
    );

    expect(stops, hasLength(2));
    expect(stops.any((s) => s.time == 'Overview'), isFalse);
  });

  test('uses an activity\'s own geocoded coordinates when no curated candidate matches', () {
    final day = const ItineraryDay(
      dayNumber: 1,
      dateLabel: 'Day 1',
      activities: [
        ItineraryActivity(
          time: 'Morning',
          title: 'Beach Relaxation',
          description: 'Relax at Alona Beach.',
          iconKey: 'beach_access',
          location: 'Alona Beach',
          latitude: 9.5488,
          longitude: 123.7729,
        ),
      ],
    );

    final stops = matchDayToRoute(day, restaurants: const [], destinations: const [], placeRecommendations: const []);

    expect(stops, hasLength(1));
    expect(stops[0].name, 'Beach Relaxation');
    expect(stops[0].latitude, 9.5488);
    expect(stops[0].longitude, 123.7729);
    expect(stops[0].destinationId, isNull);
    expect(stops[0].restaurantId, isNull);
  });

  test('prefers a curated restaurant match over an activity\'s own geocoded coordinates', () {
    final day = ItineraryDay(
      dayNumber: 1,
      dateLabel: 'Day 1',
      activities: [
        ItineraryActivity(
          time: 'Afternoon',
          title: 'Lunch at ${restaurant.name}',
          description: '',
          iconKey: 'restaurant',
          location: 'Panglao',
          latitude: 1,
          longitude: 1,
        ),
      ],
    );

    final stops = matchDayToRoute(day, restaurants: [restaurant], destinations: const []);

    expect(stops, hasLength(1));
    expect(stops[0].restaurantId, restaurant.id);
    expect(stops[0].latitude, restaurant.latitude);
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
