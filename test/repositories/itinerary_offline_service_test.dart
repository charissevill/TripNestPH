import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/services/itinerary_offline_service.dart';
import 'package:tripnest_ph/data/mock/mock_destinations.dart';
import 'package:tripnest_ph/data/mock/mock_itinerary.dart';
import 'package:tripnest_ph/data/mock/mock_restaurants.dart';
import 'package:tripnest_ph/data/repositories/destination_repository.dart';
import 'package:tripnest_ph/data/repositories/restaurant_repository.dart';
import 'package:tripnest_ph/domain/models/itinerary.dart';

void main() {
  // imageUrlsFor() is a pure function and never touches Firestore, but the
  // service still constructs its repositories eagerly — a fake instance
  // avoids needing Firebase.initializeApp() in this unit test.
  late ItineraryOfflineService service;

  setUp(() {
    service = ItineraryOfflineService(
      restaurantRepository: RestaurantRepository(firestore: FakeFirebaseFirestore()),
      destinationRepository: DestinationRepository(firestore: FakeFirebaseFirestore()),
    );
  });

  test('imageUrlsFor() includes the cover image plus every restaurant/destination photo', () {
    final restaurant = mockRestaurants.first;
    final destination = mockDestinations.first;

    final urls = service.imageUrlsFor(mockItinerary, [restaurant], [destination]);

    expect(urls, containsAll([mockItinerary.coverImageUrl, restaurant.heroImageUrl, destination.heroImageUrl]));
  });

  test('imageUrlsFor() includes recommendation photos and skips empty ones', () {
    final itinerary = Itinerary(
      destinationName: mockItinerary.destinationName,
      coverImageUrl: mockItinerary.coverImageUrl,
      totalDays: mockItinerary.totalDays,
      travelers: mockItinerary.travelers,
      totalBudget: mockItinerary.totalBudget,
      days: mockItinerary.days,
      budgetBreakdown: mockItinerary.budgetBreakdown,
      weather: mockItinerary.weather,
      travelTips: mockItinerary.travelTips,
      recommendedRestaurantIds: mockItinerary.recommendedRestaurantIds,
      nearbyAttractionIds: mockItinerary.nearbyAttractionIds,
      recommendedAccommodations: const [
        PlaceRecommendation(placeId: 'hotel-1', name: 'Hotel One', photoUrl: 'https://example.com/hotel-1.jpg'),
        PlaceRecommendation(placeId: 'hotel-2', name: 'Hotel Two', photoUrl: ''),
      ],
      recommendedPlaceAttractions: const [
        PlaceRecommendation(placeId: 'spot-1', name: 'Spot One', photoUrl: 'https://example.com/spot-1.jpg'),
      ],
    );

    final urls = service.imageUrlsFor(itinerary, const [], const []);

    expect(urls, containsAll(['https://example.com/hotel-1.jpg', 'https://example.com/spot-1.jpg']));
    expect(urls, isNot(contains('')));
  });

  test('imageUrlsFor() de-duplicates repeated URLs', () {
    final itinerary = Itinerary(
      destinationName: mockItinerary.destinationName,
      coverImageUrl: 'https://example.com/shared.jpg',
      totalDays: mockItinerary.totalDays,
      travelers: mockItinerary.travelers,
      totalBudget: mockItinerary.totalBudget,
      days: mockItinerary.days,
      budgetBreakdown: mockItinerary.budgetBreakdown,
      weather: mockItinerary.weather,
      travelTips: mockItinerary.travelTips,
      recommendedRestaurantIds: mockItinerary.recommendedRestaurantIds,
      nearbyAttractionIds: mockItinerary.nearbyAttractionIds,
      recommendedAccommodations: const [
        PlaceRecommendation(placeId: 'hotel-1', name: 'Hotel One', photoUrl: 'https://example.com/shared.jpg'),
      ],
    );

    final urls = service.imageUrlsFor(itinerary, const [], const []);

    expect(urls.where((u) => u == 'https://example.com/shared.jpg'), hasLength(1));
  });
}
