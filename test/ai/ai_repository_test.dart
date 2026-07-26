import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tripnest_ph/ai/models/itinerary_request.dart';
import 'package:tripnest_ph/ai/repositories/ai_repository.dart';
import 'package:tripnest_ph/ai/services/openai_service.dart';
import 'package:tripnest_ph/core/services/weather_service.dart';
import 'package:tripnest_ph/core/utils/function_caller.dart';
import 'package:tripnest_ph/data/repositories/destination_repository.dart';
import 'package:tripnest_ph/data/repositories/province_repository.dart';
import 'package:tripnest_ph/data/repositories/restaurant_repository.dart';

/// Fakes the `aiComplete` Cloud Function's `{'content': ...}` response shape
/// so [OpenAiService] parses it exactly like a real callable-function
/// result, without touching the real `cloud_functions` plugin (which needs
/// a platform channel `flutter test` doesn't provide).
FunctionCaller _fakeAiComplete(Map<String, dynamic> itineraryJson, {void Function(Map<String, dynamic> data)? onCall}) {
  return (name, data) async {
    expect(name, 'aiComplete');
    onCall?.call(data);
    return {'content': jsonEncode(itineraryJson)};
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // AiCacheService reads/writes SharedPreferences — give it a real (if
    // empty) backing store instead of an unmocked platform channel.
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'generateItinerary() grounds recommendations in real Firestore ids, not the mock seed data',
    () async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('restaurants').doc('real-restaurant-1').set({
        'name': 'Real Seaside Grill',
        'cuisine': 'Filipino',
        'provinceId': 'palawan',
        'provinceName': 'Palawan',
        'heroImageUrl': '',
        'galleryImageUrls': <String>[],
        'rating': 4.5,
        'reviewCount': 10,
        'priceRange': '₱₱',
        'description': 'A real restaurant seeded straight into Firestore.',
        'openingHours': '9am-9pm',
        'menuHighlights': <String>[],
        'status': 'published',
      });
      await firestore.collection('tourist_spots').doc('real-destination-1').set({
        'name': 'Real Hidden Lagoon',
        'provinceId': 'palawan',
        'provinceName': 'Palawan',
        'categoryId': 'nature',
        'heroImageUrl': '',
        'galleryImageUrls': <String>[],
        'rating': 4.8,
        'reviewCount': 20,
        'shortDescription': 'A real destination seeded straight into Firestore.',
        'longDescription': '',
        'status': 'published',
      });

      final caller = _fakeAiComplete({
        'days': [
          {
            'dayNumber': 1,
            'dateLabel': 'Day 1',
            'activities': [
              {'time': '9:00 AM', 'title': 'Arrive', 'description': 'Settle in.', 'iconKey': 'flight_land', 'location': 'Palawan'},
            ],
          },
        ],
        'budgetBreakdown': [
          {'label': 'Food', 'amount': 1000, 'iconKey': 'restaurant', 'colorKey': 'primary'},
        ],
        'travelTips': ['Bring sunscreen.'],
        'totalBudget': 1000,
        // The AI only ever sees candidate *names* (never real Firestore
        // ids) in the prompt, and replies with names — AiRepository is
        // responsible for mapping those back to real ids afterward.
        'recommendedRestaurantNames': ['Real Seaside Grill'],
        'nearbyAttractionNames': ['Real Hidden Lagoon'],
      });

      final repository = AiRepository(
        openAiService: OpenAiService(caller: caller),
        destinationRepository: DestinationRepository(firestore: firestore),
        restaurantRepository: RestaurantRepository(firestore: firestore),
        provinceRepository: ProvinceRepository(firestore: firestore),
      );

      final itinerary = await repository.generateItinerary(
        const AiItineraryRequest(
          destinationId: 'some-other-destination',
          destinationName: 'Palawan',
          provinceId: 'palawan',
          provinceName: 'Palawan',
          budgetTierLabel: 'Mid-range',
          budgetRange: '₱15k - ₱40k',
          days: 1,
          travelers: 2,
          travelerType: 'Couple',
          transportation: {'Van / Car Rental'},
          interests: {'Nature'},
        ),
        coverImageUrl: '',
      );

      // The whole point of the fix: these must be the real seeded Firestore
      // document ids, never anything from the old mock_destinations.dart /
      // mock_restaurants.dart lists.
      expect(itinerary.recommendedRestaurantIds, ['real-restaurant-1']);
      expect(itinerary.nearbyAttractionIds, ['real-destination-1']);
    },
  );

  test('generateItinerary() never recommends a restaurant/destination from a different province', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('restaurants').doc('wrong-province').set({
      'name': 'Wrong Province Diner',
      'cuisine': 'Filipino',
      'provinceId': 'cebu',
      'provinceName': 'Cebu',
      'heroImageUrl': '',
      'galleryImageUrls': <String>[],
      'rating': 4.0,
      'reviewCount': 5,
      'priceRange': '₱',
      'description': '',
      'openingHours': '',
      'menuHighlights': <String>[],
      'status': 'published',
    });

    final caller = _fakeAiComplete({
      'days': [
        {'dayNumber': 1, 'dateLabel': 'Day 1', 'activities': <Map<String, dynamic>>[]},
      ],
      'budgetBreakdown': <Map<String, dynamic>>[],
      'travelTips': <String>[],
      'totalBudget': 0,
      // Even if the AI hallucinated a name from the wrong province, the
      // candidate list handed to AiRepository never included it, so
      // there's nothing for this name to match against.
      'recommendedRestaurantNames': ['Wrong Province Diner'],
      'nearbyAttractionNames': <String>[],
    });

    final repository = AiRepository(
      openAiService: OpenAiService(caller: caller),
      destinationRepository: DestinationRepository(firestore: firestore),
      restaurantRepository: RestaurantRepository(firestore: firestore),
      provinceRepository: ProvinceRepository(firestore: firestore),
    );

    final itinerary = await repository.generateItinerary(
      const AiItineraryRequest(
        destinationId: 'palawan-1',
        destinationName: 'Palawan',
        provinceId: 'palawan',
        provinceName: 'Palawan',
        budgetTierLabel: 'Budget',
        budgetRange: '₱5k - ₱15k',
        days: 1,
        travelers: 1,
        travelerType: 'Solo',
        transportation: {'Flight'},
        interests: {'Beaches'},
      ),
      coverImageUrl: '',
    );

    expect(itinerary.recommendedRestaurantIds, isEmpty);
  });

  test('generateItinerary() populates real weather when the destination has coordinates', () async {
    final firestore = FakeFirebaseFirestore();
    final caller = _fakeAiComplete({
      'days': [
        {'dayNumber': 1, 'dateLabel': 'Day 1', 'activities': <Map<String, dynamic>>[]},
        {'dayNumber': 2, 'dateLabel': 'Day 2', 'activities': <Map<String, dynamic>>[]},
      ],
      'budgetBreakdown': <Map<String, dynamic>>[],
      'travelTips': <String>[],
      'totalBudget': 0,
      'recommendedRestaurantNames': <String>[],
      'nearbyAttractionNames': <String>[],
    });
    final weatherClient = MockClient((request) async {
      expect(request.url.toString(), contains('latitude=9.7392'));
      expect(request.url.toString(), contains('longitude=118.7353'));
      return http.Response(
        jsonEncode({
          'daily': {
            'time': ['2026-08-01', '2026-08-02'],
            'weathercode': [0, 63],
            'temperature_2m_max': [32.4, 29.1],
            'temperature_2m_min': [25.0, 24.2],
          },
        }),
        200,
      );
    });

    final repository = AiRepository(
      openAiService: OpenAiService(caller: caller),
      weatherService: WeatherService(client: weatherClient),
      destinationRepository: DestinationRepository(firestore: firestore),
      restaurantRepository: RestaurantRepository(firestore: firestore),
      provinceRepository: ProvinceRepository(firestore: firestore),
    );

    final itinerary = await repository.generateItinerary(
      const AiItineraryRequest(
        destinationId: 'palawan-1',
        destinationName: 'Palawan',
        provinceId: 'palawan',
        provinceName: 'Palawan',
        budgetTierLabel: 'Budget',
        budgetRange: '₱5k - ₱15k',
        days: 2,
        travelers: 1,
        travelerType: 'Solo',
        transportation: {'Flight'},
        interests: {'Beaches'},
        latitude: 9.7392,
        longitude: 118.7353,
      ),
      coverImageUrl: '',
    );

    expect(itinerary.weather, hasLength(2));
    expect(itinerary.weather[0].condition, 'Sunny');
    expect(itinerary.weather[0].highTemp, 32);
    expect(itinerary.weather[1].condition, 'Rainy');
  });

  test('generateItinerary() leaves weather empty when the destination has no coordinates', () async {
    final firestore = FakeFirebaseFirestore();
    final caller = _fakeAiComplete({
      'days': [
        {'dayNumber': 1, 'dateLabel': 'Day 1', 'activities': <Map<String, dynamic>>[]},
      ],
      'budgetBreakdown': <Map<String, dynamic>>[],
      'travelTips': <String>[],
      'totalBudget': 0,
      'recommendedRestaurantNames': <String>[],
      'nearbyAttractionNames': <String>[],
    });
    var weatherClientCalled = false;
    final weatherClient = MockClient((request) async {
      weatherClientCalled = true;
      return http.Response('{}', 200);
    });

    final repository = AiRepository(
      openAiService: OpenAiService(caller: caller),
      weatherService: WeatherService(client: weatherClient),
      destinationRepository: DestinationRepository(firestore: firestore),
      restaurantRepository: RestaurantRepository(firestore: firestore),
      provinceRepository: ProvinceRepository(firestore: firestore),
    );

    final itinerary = await repository.generateItinerary(
      const AiItineraryRequest(
        destinationId: 'palawan-1',
        destinationName: 'Palawan',
        provinceId: 'palawan',
        provinceName: 'Palawan',
        budgetTierLabel: 'Budget',
        budgetRange: '₱5k - ₱15k',
        days: 1,
        travelers: 1,
        travelerType: 'Solo',
        transportation: {'Flight'},
        interests: {'Beaches'},
      ),
      coverImageUrl: '',
    );

    expect(itinerary.weather, isEmpty);
    expect(weatherClientCalled, isFalse);
  });

  test('generateItinerary() sorts candidate restaurants by distance from the accommodation', () async {
    final firestore = FakeFirebaseFirestore();
    // Seeded far-then-near on purpose — if sorting works, the near one
    // appears first in the prompt regardless of Firestore read order.
    await firestore.collection('restaurants').doc('far-restaurant').set({
      'name': 'Far Away Diner',
      'cuisine': 'Filipino',
      'provinceId': 'palawan',
      'provinceName': 'Palawan',
      'heroImageUrl': '',
      'galleryImageUrls': <String>[],
      'rating': 4.0,
      'reviewCount': 5,
      'priceRange': '₱',
      'description': '',
      'openingHours': '',
      'menuHighlights': <String>[],
      'status': 'published',
      'latitude': 10.5,
      'longitude': 119.5,
    });
    await firestore.collection('restaurants').doc('near-restaurant').set({
      'name': 'Near Bistro',
      'cuisine': 'Filipino',
      'provinceId': 'palawan',
      'provinceName': 'Palawan',
      'heroImageUrl': '',
      'galleryImageUrls': <String>[],
      'rating': 4.0,
      'reviewCount': 5,
      'priceRange': '₱',
      'description': '',
      'openingHours': '',
      'menuHighlights': <String>[],
      'status': 'published',
      'latitude': 9.7392,
      'longitude': 118.7353,
    });

    Map<String, dynamic>? capturedData;
    final caller = _fakeAiComplete(
      {
        'days': [
          {'dayNumber': 1, 'dateLabel': 'Day 1', 'activities': <Map<String, dynamic>>[]},
        ],
        'budgetBreakdown': <Map<String, dynamic>>[],
        'travelTips': <String>[],
        'totalBudget': 0,
        'recommendedRestaurantNames': <String>[],
        'nearbyAttractionNames': <String>[],
      },
      onCall: (data) => capturedData = data,
    );

    final repository = AiRepository(
      openAiService: OpenAiService(caller: caller),
      destinationRepository: DestinationRepository(firestore: firestore),
      restaurantRepository: RestaurantRepository(firestore: firestore),
      provinceRepository: ProvinceRepository(firestore: firestore),
    );

    await repository.generateItinerary(
      const AiItineraryRequest(
        destinationId: 'palawan-1',
        destinationName: 'Palawan',
        provinceId: 'palawan',
        provinceName: 'Palawan',
        budgetTierLabel: 'Budget',
        budgetRange: '₱5k - ₱15k',
        days: 1,
        travelers: 1,
        travelerType: 'Solo',
        transportation: {'Flight'},
        interests: {'Beaches'},
        accommodationName: 'Test Resort',
        accommodationLatitude: 9.7392,
        accommodationLongitude: 118.7353,
      ),
      coverImageUrl: '',
    );

    final messages = capturedData!['messages'] as List;
    final userContent = messages.last['content'] as String;
    expect(userContent, contains('Test Resort'));
    expect(userContent.indexOf('Near Bistro'), lessThan(userContent.indexOf('Far Away Diner')));
  });
}
