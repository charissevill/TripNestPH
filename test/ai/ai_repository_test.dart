import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tripnest_ph/ai/models/itinerary_request.dart';
import 'package:tripnest_ph/ai/repositories/ai_repository.dart';
import 'package:tripnest_ph/ai/services/openai_service.dart';
import 'package:tripnest_ph/core/services/places_service.dart';
import 'package:tripnest_ph/core/services/weather_service.dart';
import 'package:tripnest_ph/core/utils/function_caller.dart';
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

/// Fakes the `placesSearchText` Cloud Function, keyed by exact `textQuery`,
/// mirroring the real response shape [Place.fromJson] expects. A query with
/// no entry in [responsesByQuery] resolves as "found nothing" (`places: []`),
/// same as a real search with no results.
FunctionCaller _fakePlacesSearchText(Map<String, List<Map<String, dynamic>>> responsesByQuery) {
  return (name, data) async {
    expect(name, 'placesSearchText');
    final query = data['textQuery'] as String;
    return {'places': responsesByQuery[query] ?? const []};
  };
}

/// Fakes the `placesSearchNearby` Cloud Function with a single canned
/// response list, regardless of query — used to test `_fetchAccommodations`/
/// `_fetchPlaceAttractions` in isolation from the geocoding calls, which go
/// through `placesSearchText` instead.
FunctionCaller _fakePlacesSearchNearby(List<Map<String, dynamic>> places) {
  return (name, data) async {
    expect(name, 'placesSearchNearby');
    return {'places': places};
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
    'generateItinerary() grounds recommended restaurants in real Firestore ids, and never resolves attractions to the curated tourist_spots catalog',
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
      // Seeded to prove this curated destination is never resolved into
      // `nearbyAttractionIds` anymore, even though the (faked) AI response
      // below names it — attractions are Google Places-only now.
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

      // The restaurant id must be the real seeded Firestore document id,
      // never anything from the old mock_restaurants.dart list.
      expect(itinerary.recommendedRestaurantIds, ['real-restaurant-1']);
      // Attractions are Google Places-only now — never a curated
      // `tourist_spots` doc id, even though "Real Hidden Lagoon" is both a
      // real seeded destination and the exact name the AI's response used.
      expect(itinerary.nearbyAttractionIds, isEmpty);
      // This request has no lat/lng, so `_fetchPlaceAttractions` never ran —
      // nothing to match the AI's attraction name against either way.
      expect(itinerary.recommendedPlaceAttractions, isEmpty);
    },
  );

  test('generateItinerary() never recommends a restaurant from a different province', () async {
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

  test('generateItinerary() feeds the fetched forecast into the prompt sent to the AI', () async {
    final firestore = FakeFirebaseFirestore();
    Map<String, dynamic>? capturedData;
    final caller = _fakeAiComplete(
      {
        'days': [
          {'dayNumber': 1, 'dateLabel': 'Day 1', 'activities': <Map<String, dynamic>>[]},
          {'dayNumber': 2, 'dateLabel': 'Day 2', 'activities': <Map<String, dynamic>>[]},
        ],
        'budgetBreakdown': <Map<String, dynamic>>[],
        'travelTips': <String>[],
        'totalBudget': 0,
        'recommendedRestaurantNames': <String>[],
        'nearbyAttractionNames': <String>[],
      },
      onCall: (data) => capturedData = data,
    );
    final weatherClient = MockClient((request) async {
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
      restaurantRepository: RestaurantRepository(firestore: firestore),
      provinceRepository: ProvinceRepository(firestore: firestore),
    );

    await repository.generateItinerary(
      const AiItineraryRequest(
        destinationId: 'palawan-weather-prompt',
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

    final messages = capturedData!['messages'] as List;
    final userContent = messages.last['content'] as String;
    // The forecast the model actually sees, not just what ends up attached
    // to the itinerary for display afterward — proves weather is resolved
    // *before* the prompt is built, not just alongside/after the AI call.
    expect(userContent, contains('Sunny'));
    expect(userContent, contains('Rainy'));
    // The system prompt's own weather-adjustment rule.
    final systemContent = messages.first['content'] as String;
    expect(systemContent, contains('weather forecast'));
  });

  test('generateItinerary() feeds a refinement instruction into the prompt, when given one', () async {
    final firestore = FakeFirebaseFirestore();
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
      restaurantRepository: RestaurantRepository(firestore: firestore),
      provinceRepository: ProvinceRepository(firestore: firestore),
    );

    await repository.generateItinerary(
      const AiItineraryRequest(
        destinationId: 'palawan-refine',
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
        refinementInstruction: 'Make Day 1 cheaper overall.',
      ),
      coverImageUrl: '',
    );

    final messages = capturedData!['messages'] as List;
    final userContent = messages.last['content'] as String;
    expect(userContent, contains('Make Day 1 cheaper overall.'));
  });

  test('generateItinerary() feeds the trip pace and its guidance into the prompt, when given one', () async {
    final firestore = FakeFirebaseFirestore();
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
      restaurantRepository: RestaurantRepository(firestore: firestore),
      provinceRepository: ProvinceRepository(firestore: firestore),
    );

    await repository.generateItinerary(
      const AiItineraryRequest(
        destinationId: 'palawan-pace',
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
        tripPace: 'Foodie Focus',
      ),
      coverImageUrl: '',
    );

    final messages = capturedData!['messages'] as List;
    final userContent = messages.last['content'] as String;
    expect(userContent, contains('Trip pace: Foodie Focus'));
    expect(userContent, contains('let food lead the plan'));
  });

  test('generateItinerary() carries the Food category\'s priced line items through to the itinerary', () async {
    final firestore = FakeFirebaseFirestore();
    final caller = _fakeAiComplete({
      'days': [
        {'dayNumber': 1, 'dateLabel': 'Day 1', 'activities': <Map<String, dynamic>>[]},
      ],
      'budgetBreakdown': [
        {
          'label': 'Food',
          'amount': 1000,
          'iconKey': 'restaurant',
          'colorKey': 'secondary',
          'items': [
            {'name': 'Chicken Inasal meal', 'price': 150, 'place': 'Real Seaside Grill'},
            {'name': 'Halo-halo', 'price': 90, 'place': 'Larsian BBQ stalls'},
          ],
        },
        {'label': 'Transportation', 'amount': 500, 'iconKey': 'directions_boat', 'colorKey': 'primary'},
      ],
      'travelTips': <String>[],
      'totalBudget': 1500,
      'recommendedRestaurantNames': <String>[],
      'nearbyAttractionNames': <String>[],
    });

    final repository = AiRepository(
      openAiService: OpenAiService(caller: caller),
      restaurantRepository: RestaurantRepository(firestore: firestore),
      provinceRepository: ProvinceRepository(firestore: firestore),
    );

    final itinerary = await repository.generateItinerary(
      const AiItineraryRequest(
        destinationId: 'palawan-food-items',
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

    final food = itinerary.budgetBreakdown.firstWhere((b) => b.label == 'Food');
    expect(food.items, hasLength(2));
    expect(food.items.first.name, 'Chicken Inasal meal');
    expect(food.items.first.price, 150);
    expect(food.items.first.place, 'Real Seaside Grill');
    // Categories the AI didn't break down further stay an empty list, not
    // missing/null.
    final transport = itinerary.budgetBreakdown.firstWhere((b) => b.label == 'Transportation');
    expect(transport.items, isEmpty);
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

  test('generateItinerary() sorts candidate restaurants by distance from the destination itself, when no accommodation is given', () async {
    final firestore = FakeFirebaseFirestore();
    // Seeded far-then-near, same reasoning as the accommodation-anchored
    // sort test above — proves the fallback anchor (the destination's own
    // resolved coordinates) does the same job when there's no accommodation
    // to anchor on instead.
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
      restaurantRepository: RestaurantRepository(firestore: firestore),
      provinceRepository: ProvinceRepository(firestore: firestore),
    );

    // Destination coordinates set, no accommodation at all — exactly a
    // specific-destination trip where the traveler skipped that optional
    // field. A destinationId unused by any other test in this file — the
    // AI response cache is keyed by request signature (destinationId/days/
    // travelers/travelerType/budget/transportation/interests/
    // accommodationName — deliberately not latitude/longitude), so reusing
    // one would silently serve another test's cached response instead of
    // hitting this test's own fake.
    await repository.generateItinerary(
      const AiItineraryRequest(
        destinationId: 'palawan-anchor-fallback',
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
        latitude: 9.7392,
        longitude: 118.7353,
      ),
      coverImageUrl: '',
    );

    final messages = capturedData!['messages'] as List;
    final userContent = messages.last['content'] as String;
    expect(userContent.indexOf('Near Bistro'), lessThan(userContent.indexOf('Far Away Diner')));
  });

  test(
    'generateItinerary() geocodes an activity location that matches no candidate list, via a live Places search',
    () async {
      final firestore = FakeFirebaseFirestore();
      final caller = _fakeAiComplete({
        'days': [
          {
            'dayNumber': 1,
            'dateLabel': 'Day 1',
            'activities': [
              {
                'time': 'Morning',
                'title': 'Beach Relaxation',
                'description': 'Relax at the beach.',
                'iconKey': 'beach_access',
                'location': 'Alona Beach',
              },
            ],
          },
        ],
        'budgetBreakdown': <Map<String, dynamic>>[],
        'travelTips': <String>[],
        'totalBudget': 0,
        'recommendedRestaurantNames': <String>[],
        'nearbyAttractionNames': <String>[],
      });
      final placesCaller = _fakePlacesSearchText({
        'Alona Beach, Panglao': [
          {
            'id': 'places/alona-beach',
            'displayName': {'text': 'Alona Beach'},
            'location': {'latitude': 9.5488, 'longitude': 123.7729},
          },
        ],
      });

      final repository = AiRepository(
        openAiService: OpenAiService(caller: caller),
        placesService: PlacesService(caller: placesCaller),
        restaurantRepository: RestaurantRepository(firestore: firestore),
        provinceRepository: ProvinceRepository(firestore: firestore),
      );

      final itinerary = await repository.generateItinerary(
        const AiItineraryRequest(
          destinationId: 'panglao-1',
          destinationName: 'Panglao',
          provinceId: 'bohol',
          provinceName: 'Bohol',
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

      final activity = itinerary.days.single.activities.single;
      expect(activity.latitude, 9.5488);
      expect(activity.longitude, 123.7729);
    },
  );

  // Uses a distinct AiItineraryRequest signature from the test above — the
  // AI response is keyed and cached by request signature (AiCacheService),
  // so two tests with identical params would silently share one cached
  // itinerary/Places result instead of exercising their own fakes.

  test('generateItinerary() leaves an activity ungeocoded when the Places search finds nothing', () async {
    final firestore = FakeFirebaseFirestore();
    final caller = _fakeAiComplete({
      'days': [
        {
          'dayNumber': 1,
          'dateLabel': 'Day 1',
          'activities': [
            {
              'time': 'Morning',
              'title': 'Free time',
              'description': 'Rest at the hotel.',
              'iconKey': 'hotel',
              'location': 'Somewhere vague',
            },
          ],
        },
      ],
      'budgetBreakdown': <Map<String, dynamic>>[],
      'travelTips': <String>[],
      'totalBudget': 0,
      'recommendedRestaurantNames': <String>[],
      'nearbyAttractionNames': <String>[],
    });

    final repository = AiRepository(
      openAiService: OpenAiService(caller: caller),
      placesService: PlacesService(caller: _fakePlacesSearchText(const {})),
      restaurantRepository: RestaurantRepository(firestore: firestore),
      provinceRepository: ProvinceRepository(firestore: firestore),
    );

    final itinerary = await repository.generateItinerary(
      const AiItineraryRequest(
        destinationId: 'panglao-2',
        destinationName: 'Panglao',
        provinceId: 'bohol',
        provinceName: 'Bohol',
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

    final activity = itinerary.days.single.activities.single;
    expect(activity.latitude, isNull);
    expect(activity.longitude, isNull);
  });

  test(
    'generateItinerary() falls back to geocoding the province for a whole-province trip (no destinationId/coordinates)',
    () async {
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
      // A province name unused by any other test in this file — the Places
      // search cache (PlacesCacheService, backed by the shared mock
      // SharedPreferences store) persists across tests in the same run, so
      // reusing a query another test already made (and cached the response
      // of) would silently return that other test's cached result instead
      // of hitting this test's own fake.
      final placesCaller = _fakePlacesSearchText({
        'Siargao, Philippines': [
          {
            'id': 'places/siargao',
            'displayName': {'text': 'Siargao'},
            'location': {'latitude': 9.8500, 'longitude': 126.0455},
          },
        ],
      });
      final weatherClient = MockClient((request) async {
        expect(request.url.toString(), contains('latitude=9.85'));
        expect(request.url.toString(), contains('longitude=126.0455'));
        return http.Response(
          jsonEncode({
            'daily': {
              'time': ['2026-08-01'],
              'weathercode': [0],
              'temperature_2m_max': [31.0],
              'temperature_2m_min': [24.0],
            },
          }),
          200,
        );
      });

      final repository = AiRepository(
        openAiService: OpenAiService(caller: caller),
        placesService: PlacesService(caller: placesCaller),
        weatherService: WeatherService(client: weatherClient),
        restaurantRepository: RestaurantRepository(firestore: firestore),
        provinceRepository: ProvinceRepository(firestore: firestore),
      );

      // No destinationId and no latitude/longitude — exactly what
      // AiPlannerScreen sends for a "whole province" trip.
      final itinerary = await repository.generateItinerary(
        const AiItineraryRequest(
          destinationId: '',
          destinationName: 'Siargao',
          provinceId: 'siargao',
          provinceName: 'Siargao',
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

      expect(itinerary.weather, hasLength(1));
      expect(itinerary.weather.single.highTemp, 31);
      expect(itinerary.destinationId, isNull);
      expect(itinerary.destinationLatitude, 9.85);
      expect(itinerary.destinationLongitude, 126.0455);
    },
  );

  test('generateItinerary() carries a recommended accommodation\'s real website through to PlaceRecommendation', () async {
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
    // Same canned response for both `_fetchAccommodations` and
    // `_fetchPlaceAttractions` (both hit `placesSearchNearby`) — only
    // `recommendedAccommodations` is asserted below, so this is harmless.
    final placesCaller = _fakePlacesSearchNearby([
      {
        'id': 'places/sample-resort',
        'displayName': {'text': 'Sample Beach Resort'},
        'location': {'latitude': 9.75, 'longitude': 118.75},
        'websiteUri': 'https://samplebeachresort.example.com',
      },
    ]);

    final repository = AiRepository(
      openAiService: OpenAiService(caller: caller),
      placesService: PlacesService(caller: placesCaller),
      restaurantRepository: RestaurantRepository(firestore: firestore),
      provinceRepository: ProvinceRepository(firestore: firestore),
    );

    // A coordinate not reused by any other test in this file — the
    // `PlacesCacheService`/`AiCacheService` caches persist across tests
    // sharing this file's single `setUpAll` mock SharedPreferences store,
    // so reusing another test's lat/lng could silently return its cached
    // (empty) Places result instead of hitting this test's own fake.
    final itinerary = await repository.generateItinerary(
      const AiItineraryRequest(
        destinationId: 'palawan-99',
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
        latitude: 10.1234,
        longitude: 119.5678,
      ),
      coverImageUrl: '',
    );

    expect(itinerary.recommendedAccommodations, hasLength(1));
    expect(itinerary.recommendedAccommodations.single.websiteUri, 'https://samplebeachresort.example.com');
  });

  test(
    'generateItinerary() resolves an AI-named attraction to a live Places recommendation, never to a Firestore id',
    () async {
      final firestore = FakeFirebaseFirestore();
      final caller = _fakeAiComplete({
        'days': [
          {'dayNumber': 1, 'dateLabel': 'Day 1', 'activities': <Map<String, dynamic>>[]},
        ],
        'budgetBreakdown': <Map<String, dynamic>>[],
        'travelTips': <String>[],
        'totalBudget': 0,
        'recommendedRestaurantNames': <String>[],
        'nearbyAttractionNames': ['Real Underground River'],
      });
      // Same canned response for both `_fetchAccommodations` and
      // `_fetchPlaceAttractions` (both hit `placesSearchNearby`) — harmless
      // here since only `recommendedPlaceAttractions` is asserted below.
      final placesCaller = _fakePlacesSearchNearby([
        {
          'id': 'places/real-underground-river',
          'displayName': {'text': 'Real Underground River'},
          'location': {'latitude': 11.1839, 'longitude': 122.0938},
          'websiteUri': 'https://realundergroundriver.example.com',
        },
      ]);

      final repository = AiRepository(
        openAiService: OpenAiService(caller: caller),
        placesService: PlacesService(caller: placesCaller),
        restaurantRepository: RestaurantRepository(firestore: firestore),
        provinceRepository: ProvinceRepository(firestore: firestore),
      );

      // A coordinate not reused by any other test in this file — see the
      // cache-collision note on the accommodation-website test above.
      final itinerary = await repository.generateItinerary(
        const AiItineraryRequest(
          destinationId: 'palawan-100',
          destinationName: 'Palawan',
          provinceId: 'palawan',
          provinceName: 'Palawan',
          budgetTierLabel: 'Budget',
          budgetRange: '₱5k - ₱15k',
          days: 1,
          travelers: 1,
          travelerType: 'Solo',
          transportation: {'Flight'},
          interests: {'Nature'},
          latitude: 11.1839,
          longitude: 122.0938,
        ),
        coverImageUrl: '',
      );

      expect(itinerary.recommendedPlaceAttractions, hasLength(1));
      expect(itinerary.recommendedPlaceAttractions.single.name, 'Real Underground River');
      // Never a curated Firestore doc id — attractions are Places-only now.
      expect(itinerary.nearbyAttractionIds, isEmpty);
    },
  );
}
