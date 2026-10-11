import 'package:flutter_test/flutter_test.dart';
import 'package:tripnest_ph/ai/prompts/chat_prompts.dart';
import 'package:tripnest_ph/core/utils/chat_context.dart';
import 'package:tripnest_ph/domain/models/business.dart';
import 'package:tripnest_ph/domain/models/expense.dart';
import 'package:tripnest_ph/domain/models/festival.dart';
import 'package:tripnest_ph/domain/models/itinerary.dart';
import 'package:tripnest_ph/domain/models/restaurant.dart' show MenuItem;
import 'package:tripnest_ph/domain/models/saved_itinerary.dart';

Business _business(
  String name, {
  String category = BusinessCategory.shop,
  String province = 'Cebu',
  double? latitude,
  double? longitude,
  String openingHours = '',
  double rating = 0,
  int reviewCount = 0,
  List<MenuItem> menuItems = const [],
}) {
  return Business(
    id: name,
    ownerId: 'owner',
    name: name,
    category: category,
    description: '',
    provinceId: province.toLowerCase(),
    provinceName: province,
    status: 'approved',
    latitude: latitude,
    longitude: longitude,
    openingHours: openingHours,
    rating: rating,
    reviewCount: reviewCount,
    menuItems: menuItems,
  );
}

Festival _festival(
  String name, {
  String province = 'Cebu',
  String dateLabel = '',
  DateTime? startDate,
  DateTime? endDate,
}) {
  return Festival(
    id: name,
    name: name,
    provinceId: province.toLowerCase(),
    provinceName: province,
    regionId: '',
    heroImageUrl: '',
    galleryImageUrls: const [],
    dateLabel: dateLabel,
    month: '',
    description: '',
    highlights: const [],
    rating: 0,
    reviewCount: 0,
    startDate: startDate,
    endDate: endDate,
  );
}

SavedItinerary _trip(
  String id, {
  DateTime? startDate,
  DateTime? completedAt,
  DateTime? savedAt,
  double totalBudget = 10000,
  int totalDays = 2,
}) {
  return SavedItinerary(
    id: id,
    userId: 'u1',
    title: 'Trip $id',
    savedAt: savedAt ?? DateTime(2026, 1, 1),
    startDate: startDate,
    completedAt: completedAt,
    itinerary: Itinerary(
      destinationName: 'Baguio',
      coverImageUrl: '',
      totalDays: totalDays,
      travelers: 2,
      totalBudget: totalBudget,
      days: const [
        ItineraryDay(
          dayNumber: 1,
          dateLabel: '',
          activities: [
            ItineraryActivity(
              time: 'Morning',
              title: 'Burnham Park',
              description: '',
              iconKey: 'landscape',
              location: 'Burnham Park',
            ),
          ],
        ),
      ],
      budgetBreakdown: const [],
      weather: const [],
      travelTips: const [],
      recommendedRestaurantIds: const [],
      nearbyAttractionIds: const [],
    ),
  );
}

Expense _expense(String category, double amount) => Expense(
  id: '$category$amount',
  category: category,
  amount: amount,
  note: '',
  loggedBy: 'u1',
  createdAt: DateTime(2026, 10, 1),
);

void main() {
  final now = DateTime(2026, 10, 11, 9);

  group('relevantChatTopics()', () {
    test('recognizes English and Tagalog cues', () {
      expect(
        relevantChatTopics('uulan ba bukas sa Baguio?'),
        containsAll([ChatContextTopic.weather, ChatContextTopic.businesses]),
      );
      expect(
        relevantChatTopics('Restaurants near me'),
        containsAll([ChatContextTopic.location, ChatContextTopic.restaurants]),
      );
      expect(
        relevantChatTopics('magkano na nagastos ko sa trip ko?'),
        contains(ChatContextTopic.trips),
      );
      expect(
        relevantChatTopics('anong festival ngayong buwan?'),
        contains(ChatContextTopic.festivals),
      );
    });

    test('is empty for a message about none of them', () {
      expect(relevantChatTopics('Plan a 2-day Baguio getaway'), isEmpty);
    });
  });

  group('assembleChatContext()', () {
    const sections = [
      ChatContextSection(ChatContextTopic.provinces, 'PROVINCES'),
      ChatContextSection(ChatContextTopic.location, 'LOCATION'),
      ChatContextSection(ChatContextTopic.festivals, 'FESTIVALS'),
    ];

    test('falls back to topic declaration order', () {
      expect(
        assembleChatContext(sections, maxChars: 1000),
        'LOCATION FESTIVALS PROVINCES',
      );
    });

    test('puts priority topics first so the cap cuts the rest', () {
      expect(
        assembleChatContext(
          sections,
          priority: [ChatContextTopic.festivals],
          maxChars: 12,
        ),
        'FESTIVALS LO',
      );
    });

    test('skips empty sections', () {
      expect(
        assembleChatContext(const [
          ChatContextSection(ChatContextTopic.location, ''),
          ChatContextSection(ChatContextTopic.weather, 'WEATHER'),
        ], maxChars: 1000),
        'WEATHER',
      );
    });
  });

  test('describeForecastForChat() labels today and tomorrow', () {
    const forecast = [
      WeatherForecast(dayLabel: 'Sun', condition: 'Rainy', iconKey: 'rainy', highTemp: 30, lowTemp: 24),
      WeatherForecast(dayLabel: 'Mon', condition: 'Sunny', iconKey: 'wb_sunny', highTemp: 32, lowTemp: 25),
      WeatherForecast(dayLabel: 'Tue', condition: 'Cloudy', iconKey: 'cloud', highTemp: 31, lowTemp: 25),
    ];
    expect(
      describeForecastForChat(forecast),
      'Today (Sun): Rainy, 24–30°C; Tomorrow (Mon): Sunny, 25–32°C; Tue: Cloudy, 25–31°C',
    );
  });

  group('describeBusinessesForChat()', () {
    test('is empty with no businesses', () {
      expect(describeBusinessesForChat(const []), '');
    });

    test('gives full details only to the most relevant listings', () {
      final text = describeBusinessesForChat(
        [
          _business('Alpha Souvenirs', openingHours: '8am-5pm'),
          _business(
            'Bohol Island Tours',
            category: BusinessCategory.tourOperator,
            province: 'Bohol',
            openingHours: '7am-6pm',
            rating: 4.5,
            reviewCount: 12,
            menuItems: const [
              MenuItem(name: 'Countryside tour', price: '₱1,500', imageUrl: ''),
            ],
          ),
        ],
        focusText: 'any tour operator in Bohol?',
        detailedCount: 1,
      );
      final detailed = text.split('Other businesses in the directory').first;
      expect(detailed, contains('Bohol Island Tours'));
      expect(detailed, contains('hours: 7am-6pm'));
      expect(detailed, contains('rated 4.5 from 12 reviews'));
      expect(detailed, contains('offers: Countryside tour ₱1,500'));
      expect(detailed, isNot(contains('Alpha Souvenirs')));
      expect(text, contains('Alpha Souvenirs (Shop, Cebu)'));
      expect(text, isNot(contains('8am-5pm')));
    });

    test('a business named in the conversation outranks everything else', () {
      final text = describeBusinessesForChat(
        [
          _business('Near Shop', latitude: 10.0, longitude: 123.0),
          _business('Far Away Store', province: 'Davao', openingHours: '9am-9pm'),
        ],
        focusText: 'bukas ba sila? ... try **Far Away Store** for pasalubong',
        originLatitude: 10.0,
        originLongitude: 123.0,
        detailedCount: 1,
      );
      expect(text.split('Other businesses').first, contains('hours: 9am-9pm'));
    });

    test('includes the distance from the traveler, nearest first', () {
      final text = describeBusinessesForChat(
        [
          _business('Farther', latitude: 10.05, longitude: 123.0),
          _business('Closer', latitude: 10.001, longitude: 123.0),
          _business('No Pin'),
        ],
        originLatitude: 10.0,
        originLongitude: 123.0,
      );
      expect(text, contains('Closer (Shop; Cebu; 0.1 km from the traveler'));
      expect(text.indexOf('Closer'), lessThan(text.indexOf('Farther')));
      expect(text.indexOf('Farther'), lessThan(text.indexOf('No Pin')));
    });
  });

  test('businessesNearTraveler() keeps only pinned listings in range', () {
    final near = businessesNearTraveler(
      [
        _business('Other Island', latitude: 14.6, longitude: 121.0),
        _business('Walkable', latitude: 10.002, longitude: 123.0),
        _business('No Pin'),
        _business('Short Ride', latitude: 10.05, longitude: 123.0),
      ],
      originLatitude: 10.0,
      originLongitude: 123.0,
    );
    expect(near.map((b) => b.name), ['Walkable', 'Short Ride']);
  });

  group('describeFestivalsForChat()', () {
    test('lists upcoming first and flags ongoing/finished ones', () {
      final text = describeFestivalsForChat([
        _festival('Past Fest', dateLabel: 'January 15, 2026', startDate: DateTime(2026, 1, 15)),
        _festival('Undated Fest'),
        _festival('Later Fest', dateLabel: 'December 1, 2026', startDate: DateTime(2026, 12, 1)),
        _festival(
          'Now Fest',
          dateLabel: 'October 10–12, 2026',
          startDate: DateTime(2026, 10, 10),
          endDate: DateTime(2026, 10, 12),
        ),
      ], now: now);
      final order = ['Now Fest', 'Later Fest', 'Undated Fest', 'Past Fest'].map(text.indexOf).toList();
      expect(order, [...order]..sort());
      expect(text, contains('Now Fest (Cebu; October 10–12, 2026; happening now)'));
      expect(text, contains('Past Fest (Cebu; January 15, 2026; already finished)'));
    });

    test('leads with festivals in a province the message names', () {
      final text = describeFestivalsForChat(
        [
          _festival('Sinulog', startDate: DateTime(2027, 1, 17)),
          _festival('Panagbenga', province: 'Benguet', startDate: DateTime(2027, 2, 1)),
        ],
        now: now,
        focusText: 'festivals in benguet?',
      );
      expect(text.indexOf('Panagbenga'), lessThan(text.indexOf('Sinulog')));
    });
  });

  group('orderTripsForChat()', () {
    test('current and upcoming, then undated, then finished', () {
      final ordered = orderTripsForChat([
        _trip('done', startDate: DateTime(2026, 11, 1), completedAt: DateTime(2026, 9, 1)),
        _trip('undated'),
        _trip('later', startDate: DateTime(2026, 12, 1)),
        _trip('past', startDate: DateTime(2026, 9, 1)),
        _trip('soon', startDate: DateTime(2026, 10, 20)),
      ], now: now);
      expect(ordered.map((t) => t.id).take(3), ['soon', 'later', 'undated']);
      expect(ordered.map((t) => t.id).skip(3), containsAll(['done', 'past']));
    });
  });

  group('describeTripsForChat()', () {
    test('says so when there are no trips', () {
      expect(describeTripsForChat(const [], now: now), contains('no saved trips'));
    });

    test('reports spend against the planned budget', () {
      final text = describeTripsForChat(
        [_trip('a', startDate: DateTime(2026, 10, 20))],
        now: now,
        expensesByTripId: {
          'a': [_expense('Food', 1500), _expense('Food', 500), _expense('Transportation', 2200)],
        },
      );
      expect(text, contains('"Trip a" — Baguio, 2 days, 2 travelers, Oct 20, 2026 to Oct 21, 2026'));
      expect(text, contains('planned budget ₱10,000'));
      expect(text, contains('spent so far ₱4,200 (Food ₱2,000, Transportation ₱2,200)'));
      expect(text, contains('₱5,800 left'));
      expect(text, contains('Day 1: Burnham Park'));
    });

    test('flags an overspent trip and one in progress', () {
      final text = describeTripsForChat(
        [_trip('a', startDate: DateTime(2026, 10, 10), totalBudget: 1000)],
        now: now,
        expensesByTripId: {
          'a': [_expense('Food', 1500)],
        },
      );
      expect(text, contains('in progress — today is day 2'));
      expect(text, contains('₱500 over budget'));
    });

    test('claims nothing about spending when expenses were not loaded', () {
      final text = describeTripsForChat([_trip('a')], now: now);
      expect(text, contains('no start date set yet'));
      expect(text, isNot(contains('expenses')));
      expect(text, isNot(contains('spent so far')));
    });

    test('says so when expenses loaded but none are logged', () {
      final text = describeTripsForChat([_trip('a')], now: now, expensesByTripId: const {'a': []});
      expect(text, contains('no expenses logged yet'));
    });
  });

  // The whole system message (fixed instructions + context) is rejected by
  // the `aiComplete` Cloud Function past AI_MAX_MESSAGE_CHARS (16000, see
  // functions/index.js) — which fails every chat reply, not just a long one.
  test('instructions plus a full context stay under the server ceiling', () {
    final prompt = ChatPrompts.systemPrompt(userContext: 'x' * chatContextMaxChars);
    expect(prompt.length, lessThan(16000));
  });
}
