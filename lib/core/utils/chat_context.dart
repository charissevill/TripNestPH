import 'package:intl/intl.dart';

import '../../domain/models/business.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/festival.dart';
import '../../domain/models/itinerary.dart';
import '../../domain/models/saved_itinerary.dart';
import 'geo_distance.dart';

/// The most real-data context sent with one chat message. The context rides
/// in the same system message as `ChatPrompts`' fixed instructions, and the
/// server rejects a message over `AI_MAX_MESSAGE_CHARS` (16000, see
/// `functions/index.js`) — so this plus those instructions has to stay
/// under that, however much the catalog behind the context grows.
const int chatContextMaxChars = 8000;

/// What a piece of the AI chat's real-data context is about. Declaration
/// order is the default order sections are sent in when a message isn't
/// clearly about any of them (see [assembleChatContext]) — the context is
/// capped, so whatever comes last is what gets cut.
enum ChatContextTopic {
  destination,
  location,
  weather,
  trips,
  saved,
  businesses,
  festivals,
  attractions,
  accommodations,
  restaurants,
  provinces,
}

/// One block of real-data context handed to the model.
class ChatContextSection {
  const ChatContextSection(this.topic, this.text);

  final ChatContextTopic topic;
  final String text;
}

/// English and Tagalog/Taglish cues for each topic. Plain substring checks,
/// so a false hit is possible (e.g. "rain" inside "train") — that only moves
/// a section earlier in the context, never drops or invents anything.
const Map<ChatContextTopic, List<String>> _topicKeywords = {
  ChatContextTopic.location: [
    'near me',
    'nearby',
    'near here',
    'around me',
    'around here',
    'close to me',
    'malapit',
    'dito',
    'where am i',
    'nasaan ako',
    'asan ako',
  ],
  ChatContextTopic.weather: [
    'weather',
    'forecast',
    'rain',
    'sunny',
    'storm',
    'typhoon',
    'umbrella',
    'panahon',
    'ulan',
    'bagyo',
    'maaraw',
    'payong',
  ],
  ChatContextTopic.trips: [
    'my trip',
    'my itinerar',
    'my plan',
    'trip ko',
    'itinerary ko',
    'biyahe ko',
    'trip namin',
    'spent',
    'spend',
    'expense',
    'gastos',
    'my budget',
    'budget ko',
    'sa budget',
    'on budget',
    'over budget',
  ],
  ChatContextTopic.saved: [
    'saved',
    'na-save',
    'nasave',
    'sinave',
    'favorite',
    'favourite',
    'bookmark',
    'wishlist',
  ],
  ChatContextTopic.businesses: [
    'business',
    'negosyo',
    'tour operator',
    'tour guide',
    'shop',
    'store',
    'tindahan',
    'souvenir',
    'pasalubong',
    'transport',
    'rental',
    'shuttle',
    'opening hours',
    'what time',
    'anong oras',
    'bukas',
    'open',
    'magkano',
    'how much',
    'menu',
    'contact',
    'registered',
    'directory',
  ],
  ChatContextTopic.festivals: [
    'festival',
    'fiesta',
    'pista',
    'event',
    'celebration',
    'okasyon',
  ],
  ChatContextTopic.attractions: [
    'attraction',
    'tourist spot',
    'pasyalan',
    'puntahan',
    'landmark',
  ],
  ChatContextTopic.accommodations: [
    'hotel',
    'resort',
    'hostel',
    'accommodation',
    'place to stay',
    'where to stay',
    'matutuluyan',
    'tuluyan',
  ],
  ChatContextTopic.restaurants: [
    'restaurant',
    'cafe',
    'café',
    'coffee',
    'food',
    'eat',
    'kainan',
    'kain',
    'pagkain',
  ],
  ChatContextTopic.provinces: [
    'emergency',
    'hotline',
    'etiquette',
    'culture',
    'custom',
    'kultura',
  ],
};

/// The topics [text] is asking about, in [ChatContextTopic] declaration
/// order. Empty when nothing matched.
List<ChatContextTopic> relevantChatTopics(String text) {
  final lower = text.toLowerCase();
  return [
    for (final topic in ChatContextTopic.values)
      if (_topicKeywords[topic]?.any(lower.contains) ?? false) topic,
  ];
}

/// Joins [sections] into the context string sent to the model, cut to
/// [maxChars]. Sections about a [priority] topic go first (in [priority]'s
/// own order), the rest follow in [ChatContextTopic] declaration order — so
/// when the context is too long for the cap, what gets cut is whatever the
/// traveler's message is least likely to need.
String assembleChatContext(
  List<ChatContextSection> sections, {
  List<ChatContextTopic> priority = const [],
  required int maxChars,
}) {
  final order = <ChatContextTopic>[
    ...priority,
    for (final topic in ChatContextTopic.values)
      if (!priority.contains(topic)) topic,
  ];
  final joined = [
    for (final topic in order)
      for (final section in sections)
        if (section.topic == topic && section.text.isNotEmpty) section.text,
  ].join(' ');
  if (maxChars <= 0) return '';
  return joined.length > maxChars ? joined.substring(0, maxChars) : joined;
}

/// A forecast as one line, e.g. "Today (Sun): Rainy, 24–30°C; Tomorrow
/// (Mon): ...". [forecast] starts today — that's what `WeatherService`
/// returns.
String describeForecastForChat(List<WeatherForecast> forecast) {
  return [
    for (var i = 0; i < forecast.length; i++)
      '${i == 0
          ? 'Today (${forecast[i].dayLabel})'
          : i == 1
          ? 'Tomorrow (${forecast[i].dayLabel})'
          : forecast[i].dayLabel}: '
          '${forecast[i].condition}, ${forecast[i].lowTemp}–${forecast[i].highTemp}°C',
  ].join('; ');
}

const Map<String, List<String>> _businessCategoryKeywords = {
  BusinessCategory.accommodation: [
    'hotel',
    'resort',
    'hostel',
    'inn',
    'stay',
    'accommodation',
    'room',
    'tuluyan',
  ],
  BusinessCategory.foodAndDining: [
    'restaurant',
    'cafe',
    'café',
    'coffee',
    'food',
    'eat',
    'kain',
  ],
  BusinessCategory.tourOperator: ['tour', 'guide', 'package', 'island hopping'],
  BusinessCategory.shop: [
    'shop',
    'store',
    'souvenir',
    'pasalubong',
    'tindahan',
    'buy',
    'bili',
  ],
  BusinessCategory.transport: [
    'transport',
    'van',
    'rental',
    'rent',
    'shuttle',
    'sasakyan',
    'ride',
  ],
};

/// A registered business counts as "near the traveler" within this radius —
/// the same one the chat's nearby-accommodation search uses.
const double chatNearbyBusinessKm = 15;

double? _kmTo(double? originLat, double? originLng, double? lat, double? lng) {
  if (originLat == null || originLng == null || lat == null || lng == null) {
    return null;
  }
  return haversineKm(originLat, originLng, lat, lng);
}

String _clip(String text, int maxChars) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return flat.length > maxChars ? '${flat.substring(0, maxChars).trim()}…' : flat;
}

/// Everything on file for one business, as the model sees it. [km] is its
/// distance from the traveler, when both have coordinates.
String describeBusinessForChat(Business business, {double? km}) {
  final details = <String>[
    BusinessCategory.label(business.category),
    if (business.provinceName.isNotEmpty) business.provinceName,
    if (km != null) '${km.toStringAsFixed(1)} km from the traveler',
    if (business.isFoodAndDining && business.cuisine.isNotEmpty)
      'cuisine: ${business.cuisine}',
    if (business.isFoodAndDining && business.priceRange.isNotEmpty)
      'price range: ${business.priceRange}',
    if (business.openingHours.isNotEmpty) 'hours: ${business.openingHours}',
    if (business.reviewCount > 0)
      'rated ${business.rating.toStringAsFixed(1)} from ${business.reviewCount} review${business.reviewCount == 1 ? '' : 's'}',
    if (business.description.trim().isNotEmpty)
      'about: ${_clip(business.description, 140)}',
    if (business.menuItems.isNotEmpty)
      'offers: ${business.menuItems.take(4).map((m) => m.price.isEmpty ? m.name : '${m.name} ${m.price}').join(', ')}',
    if (business.accessibilityTags.isNotEmpty)
      'accessibility: ${business.accessibilityTags.join(', ')}',
    if (business.contactNumber.isNotEmpty) 'phone: ${business.contactNumber}',
    if (business.websiteUrl.isNotEmpty) 'website: ${business.websiteUrl}',
    if (business.address.isNotEmpty) 'address: ${business.address}',
  ];
  return '${business.name} (${details.join('; ')})';
}

/// [businesses] with coordinates within [chatNearbyBusinessKm] of the
/// traveler, nearest first.
List<Business> businessesNearTraveler(
  List<Business> businesses, {
  required double originLatitude,
  required double originLongitude,
}) {
  double km(Business b) =>
      _kmTo(originLatitude, originLongitude, b.latitude, b.longitude) ??
      double.infinity;
  return businesses.where((b) => km(b) <= chatNearbyBusinessKm).toList()
    ..sort((a, b) => km(a).compareTo(km(b)));
}

/// The TripNest PH business directory as the model sees it for one message:
/// full details for the [detailedCount] listings most relevant to
/// [focusText] (named in it, in a province it names, of a category it asks
/// for, or near the traveler), then just name/category/province for the
/// next [nameOnlyCount]. Sending every detail of every listing wouldn't fit
/// the context cap. Empty string when there are no businesses.
String describeBusinessesForChat(
  List<Business> businesses, {
  String focusText = '',
  double? originLatitude,
  double? originLongitude,
  int detailedCount = 8,
  int nameOnlyCount = 20,
}) {
  if (businesses.isEmpty) return '';
  final focus = focusText.toLowerCase();

  double? km(Business b) =>
      _kmTo(originLatitude, originLongitude, b.latitude, b.longitude);

  int score(Business b) {
    var total = 0;
    final name = b.name.trim().toLowerCase();
    if (name.length >= 3 && focus.contains(name)) total += 100;
    final province = b.provinceName.trim().toLowerCase();
    if (province.length >= 3 && focus.contains(province)) total += 40;
    if (_businessCategoryKeywords[b.category]?.any(focus.contains) ?? false) {
      total += 20;
    }
    final distance = km(b);
    if (distance != null && distance <= chatNearbyBusinessKm) total += 10;
    return total;
  }

  final ranked = [...businesses]
    ..sort((a, b) {
      final byScore = score(b).compareTo(score(a));
      if (byScore != 0) return byScore;
      final byDistance = (km(a) ?? double.infinity).compareTo(
        km(b) ?? double.infinity,
      );
      if (byDistance != 0) return byDistance;
      return b.rating.compareTo(a.rating);
    });

  final detailed = ranked.take(detailedCount).toList();
  final nameOnly = ranked.skip(detailedCount).take(nameOnlyCount).toList();
  final buffer = StringBuffer(
    'Real local businesses in the TripNest PH directory (approved listings registered in the app) — '
    'recommend these by name using only the exact details given, and never invent a business, or a '
    'detail (hours, price, phone, distance) that isn\'t here: '
    '${detailed.map((b) => describeBusinessForChat(b, km: km(b))).join(' | ')}.',
  );
  if (nameOnly.isNotEmpty) {
    buffer.write(
      ' Other businesses in the directory (name only — say the traveler can open the listing in '
      'Explore for details): '
      '${nameOnly.map((b) => '${b.name} (${BusinessCategory.label(b.category)}, ${b.provinceName})').join(', ')}.',
    );
  }
  return buffer.toString();
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The festival catalog as the model sees it: ones in a province
/// [focusText] names first, then ongoing/upcoming by date, then undated,
/// then already-finished ones. Empty string when there are no festivals.
String describeFestivalsForChat(
  List<Festival> festivals, {
  required DateTime now,
  String focusText = '',
  int limit = 20,
}) {
  if (festivals.isEmpty) return '';
  final focus = focusText.toLowerCase();
  final today = _dateOnly(now);

  bool isFinished(Festival f) {
    final end = f.endDate ?? f.startDate;
    return end != null && _dateOnly(end).isBefore(today);
  }

  bool isOngoing(Festival f) {
    final start = f.startDate;
    if (start == null || isFinished(f)) return false;
    return !_dateOnly(start).isAfter(today);
  }

  // 0 = dated and not finished, 1 = undated, 2 = finished.
  int bucket(Festival f) => f.startDate == null
      ? 1
      : isFinished(f)
      ? 2
      : 0;

  bool inFocus(Festival f) {
    final province = f.provinceName.trim().toLowerCase();
    final name = f.name.trim().toLowerCase();
    return (province.length >= 3 && focus.contains(province)) ||
        (name.length >= 3 && focus.contains(name));
  }

  final ranked = [...festivals]
    ..sort((a, b) {
      final byFocus = (inFocus(b) ? 1 : 0).compareTo(inFocus(a) ? 1 : 0);
      if (byFocus != 0) return byFocus;
      final byBucket = bucket(a).compareTo(bucket(b));
      if (byBucket != 0) return byBucket;
      if (a.startDate != null && b.startDate != null) {
        return a.startDate!.compareTo(b.startDate!);
      }
      return a.name.compareTo(b.name);
    });

  String describe(Festival f) {
    final details = <String>[
      if (f.provinceName.isNotEmpty) f.provinceName,
      if (f.dateLabel.isNotEmpty)
        f.dateLabel
      else if (f.startDate != null)
        DateFormat('MMMM d, y').format(f.startDate!),
      if (isOngoing(f)) 'happening now' else if (isFinished(f)) 'already finished',
      if (f.venue.isNotEmpty) 'venue: ${f.venue}',
    ];
    return details.isEmpty ? f.name : '${f.name} (${details.join('; ')})';
  }

  return 'Real festivals in the TripNest PH catalog — use these exact dates and venues for any '
      'festival/event question, and say so plainly when none on file matches instead of inventing a '
      'date: ${ranked.take(limit).map(describe).join(' | ')}.';
}

/// [trips] in the order a traveler most likely means by "my trip": ones in
/// progress or still ahead (soonest first), then ones with no start date
/// yet (most recently saved first), then completed/past ones.
List<SavedItinerary> orderTripsForChat(
  List<SavedItinerary> trips, {
  required DateTime now,
}) {
  final today = _dateOnly(now);

  bool isOver(SavedItinerary t) {
    final end = t.endDate;
    return t.isCompleted || (end != null && _dateOnly(end).isBefore(today));
  }

  // 0 = dated and not over, 1 = undated and not over, 2 = over.
  int bucket(SavedItinerary t) => isOver(t)
      ? 2
      : t.startDate == null
      ? 1
      : 0;

  return [...trips]..sort((a, b) {
    final byBucket = bucket(a).compareTo(bucket(b));
    if (byBucket != 0) return byBucket;
    if (bucket(a) == 0) return a.startDate!.compareTo(b.startDate!);
    return b.savedAt.compareTo(a.savedAt);
  });
}

String _peso(double amount) => '₱${NumberFormat('#,##0').format(amount)}';

/// The traveler's own saved trips as the model sees them — [trips] in the
/// order given (see [orderTripsForChat]). The first [detailedCount] get
/// their day plan and, when [expensesByTripId] has an entry for them, what's
/// been spent against the planned budget; the rest are a one-line summary.
/// A trip missing from [expensesByTripId] says nothing about spending,
/// rather than claiming nothing was logged.
String describeTripsForChat(
  List<SavedItinerary> trips, {
  required DateTime now,
  Map<String, List<Expense>> expensesByTripId = const {},
  int detailedCount = 3,
  int limit = 8,
}) {
  if (trips.isEmpty) {
    return 'The traveler has no saved trips in TripNest PH yet — if they ask about "my trip", say '
        'so and offer to help plan one.';
  }
  final today = _dateOnly(now);
  final dateFormat = DateFormat('MMM d, y');

  String timing(SavedItinerary t) {
    if (t.isCompleted) return 'marked completed';
    final start = t.startDate;
    final end = t.endDate;
    if (start == null || end == null) return 'no start date set yet';
    if (_dateOnly(end).isBefore(today)) {
      return 'was ${dateFormat.format(start)} to ${dateFormat.format(end)}';
    }
    if (!_dateOnly(start).isAfter(today)) {
      final day = today.difference(_dateOnly(start)).inDays + 1;
      return 'in progress — today is day $day (${dateFormat.format(start)} to ${dateFormat.format(end)})';
    }
    return '${dateFormat.format(start)} to ${dateFormat.format(end)}';
  }

  String summary(SavedItinerary t) {
    final it = t.itinerary;
    return '"${t.title}" — ${it.destinationName}, ${it.totalDays} day${it.totalDays == 1 ? '' : 's'}, '
        '${it.travelers} traveler${it.travelers == 1 ? '' : 's'}, ${timing(t)}';
  }

  String spending(SavedItinerary t) {
    final expenses = expensesByTripId[t.id];
    final planned = t.itinerary.totalBudget;
    final plannedText = planned > 0 ? 'planned budget ${_peso(planned)}' : '';
    if (expenses == null) return plannedText;
    if (expenses.isEmpty) {
      return [
        if (plannedText.isNotEmpty) plannedText,
        'no expenses logged yet',
      ].join(', ');
    }
    final byCategory = <String, double>{};
    for (final e in expenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    final spent = byCategory.values.fold<double>(0, (sum, v) => sum + v);
    final breakdown = byCategory.entries
        .map((e) => '${e.key} ${_peso(e.value)}')
        .join(', ');
    return [
      if (plannedText.isNotEmpty) plannedText,
      'spent so far ${_peso(spent)} ($breakdown)',
      if (planned > 0)
        spent > planned
            ? '${_peso(spent - planned)} over budget'
            : '${_peso(planned - spent)} left',
    ].join(', ');
  }

  String plan(SavedItinerary t) => t.itinerary.days
      .where((d) => d.activities.isNotEmpty)
      .map(
        (d) =>
            'Day ${d.dayNumber}: ${d.activities.map((a) => a.title).join(', ')}',
      )
      .join('; ');

  final shown = trips.take(limit).toList();
  final lines = <String>[
    for (var i = 0; i < shown.length; i++)
      if (i < detailedCount)
        [
          summary(shown[i]),
          spending(shown[i]),
          plan(shown[i]),
        ].where((s) => s.isNotEmpty).join('; ')
      else
        summary(shown[i]),
  ];
  return 'The traveler\'s own saved trips in TripNest PH (answer "my trip"/"my itinerary"/"how much '
      'have I spent" questions from this, never from a guess; amounts are what they logged in the '
      'trip\'s Budget Tracker): ${lines.join(' | ')}.';
}
