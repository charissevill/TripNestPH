import 'dart:convert';

import '../../core/services/places_service.dart';
import '../../core/services/weather_service.dart';
import '../../core/utils/geo_distance.dart';
import '../../data/mock/mock_itinerary.dart';
import '../../domain/models/place.dart';
import '../../data/repositories/province_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../domain/models/itinerary.dart';
import '../../domain/models/province.dart';
import '../../domain/models/restaurant.dart';
import '../models/ai_message.dart';
import '../models/itinerary_request.dart';
import '../prompts/chat_prompts.dart';
import '../prompts/itinerary_prompts.dart';
import '../services/ai_cache_service.dart';
import '../services/openai_service.dart';

/// Locations shorter than this are skipped by [AiRepository._geocodeActivities]
/// — a search this generic (e.g. "Hotel") risks matching an unrelated,
/// same-named business rather than the specific place the activity means.
const int _minGeocodableLocationLength = 4;

/// The only layer that talks to [OpenAiService] directly. Providers call
/// into here; nothing above this layer knows a REST API is involved.
class AiRepository {
  AiRepository({
    OpenAiService? openAiService,
    AiCacheService? cacheService,
    RestaurantRepository? restaurantRepository,
    ProvinceRepository? provinceRepository,
    WeatherService? weatherService,
    PlacesService? placesService,
  }) : _openAi = openAiService ?? OpenAiService(),
       _cache = cacheService ?? AiCacheService(),
       _weatherOverride = weatherService,
       _places = placesService ?? PlacesService(),
       _restaurantRepositoryOverride = restaurantRepository,
       _provinceRepositoryOverride = provinceRepository;

  final OpenAiService _openAi;
  final AiCacheService _cache;

  // Null in production — a fresh WeatherService is created per request
  // instead (see _fetchForecast) rather than one held for this repository's
  // whole lifetime, which is effectively the app's whole lifetime (both
  // AiChatProvider and AiPlannerProvider construct their AiRepository once
  // at startup). The same stale-client bug CurrentWeatherCard was fixed for:
  // a long-lived http.Client can get stuck after a network blip and keep
  // returning empty/stale forecasts for every generation after that. Tests
  // inject a fake here and get that exact instance every time, same as
  // before.
  final WeatherService? _weatherOverride;
  final PlacesService _places;

  /// A real forecast fetch, using a fresh client per call in production (or
  /// the injected test double, every time) — see [_weatherOverride].
  Future<List<WeatherForecast>> _fetchForecast({
    required double latitude,
    required double longitude,
    required int days,
  }) async {
    if (_weatherOverride != null) {
      return _weatherOverride.getForecast(
        latitude: latitude,
        longitude: longitude,
        days: days,
      );
    }
    final weatherService = WeatherService();
    try {
      return await weatherService.getForecast(
        latitude: latitude,
        longitude: longitude,
        days: days,
      );
    } finally {
      weatherService.dispose();
    }
  }

  // Lazy, same reasoning as AuthProvider's rarely-used repositories: this
  // provider is constructed unconditionally at app startup (so the AI
  // Planner tab is instant to open), but itinerary generation is the only
  // thing that ever needs Firestore here — no reason to pay for
  // FirebaseFirestore.instance before that actually happens.
  final RestaurantRepository? _restaurantRepositoryOverride;
  final ProvinceRepository? _provinceRepositoryOverride;
  RestaurantRepository? _restaurantRepositoryInstance;
  ProvinceRepository? _provinceRepositoryInstance;
  RestaurantRepository get _restaurantRepository =>
      _restaurantRepositoryOverride ??
      (_restaurantRepositoryInstance ??= RestaurantRepository());
  ProvinceRepository get _provinceRepository =>
      _provinceRepositoryOverride ??
      (_provinceRepositoryInstance ??= ProvinceRepository());

  /// Generates a full itinerary for [request] and maps it into the app's
  /// existing [Itinerary] model, grounding restaurant/attraction picks
  /// against the real live catalog (same province as the trip) so no ID is
  /// ever hallucinated and every recommendation is something that actually
  /// exists in Firestore today.
  ///
  /// No AI provider key configured server-side (see `aiComplete` in
  /// `functions/index.js`) surfaces as an [AiException] with
  /// [AiException.isConfigError] set — caught here and turned into a
  /// clearly-labeled sample itinerary instead, so "Generate Itinerary"
  /// always leads somewhere even before a real key is set up.
  Future<Itinerary> generateItinerary(
    AiItineraryRequest request, {
    required String coverImageUrl,
    bool forceRefresh = false,
  }) async {
    try {
      // A request built from an AI Chat conversation ("Build Full
      // Itinerary") already has the real day-by-day plan sitting right
      // there in the chat reply — parsing that directly and only asking AI
      // to cost it out (see generateItineraryFromChatPlan) guarantees the
      // generated trip's places are the chat's places, rather than asking a
      // second, separate generation call to "match" that reply in prose and
      // hoping it actually does. Never true for Regenerate (which builds a
      // fresh request with no priorConversationContext, by design —
      // see AiItineraryRequest.priorConversationContext's doc comment), so
      // this can't ever short-circuit those into reproducing the same plan.
      if (request.priorConversationContext != null &&
          request.priorConversationContext!.isNotEmpty) {
        final fromChat = await generateItineraryFromChatPlan(
          request,
          coverImageUrl: coverImageUrl,
        );
        if (fromChat != null) return fromChat;
      }
      return await _generateItineraryViaAi(
        request,
        coverImageUrl: coverImageUrl,
        forceRefresh: forceRefresh,
      );
    } on AiException catch (e) {
      if (e.isConfigError) return _demoItinerary();
      rethrow;
    }
  }

  /// Builds an [Itinerary] straight from the day-by-day plan a chat reply
  /// already gave (see [ChatPrompts.systemPrompt]'s "Day <N> – ..." / "- <Time>:
  /// **<Place>** — ..." format), instead of asking a second AI call to
  /// regenerate one that merely "matches" it. That older approach — folding
  /// the chat's named places into freshly-fetched candidate lists and
  /// telling the model "this itinerary MUST match that reply" — depended on
  /// the model actually honoring free-text prose instructions consistently,
  /// which it doesn't: in practice a chat reply's own places routinely
  /// didn't survive into the generated itinerary at all. Deterministically
  /// parsing what the reply already said removes that gap entirely — the
  /// itinerary's places are literally the chat's places, not a second
  /// guess at them.
  ///
  /// Only the budget breakdown and travel tips still come from a (much
  /// narrower) AI call — see [ItineraryPrompts.budgetAndTipsSystem] — since
  /// costing out a trip and writing tips isn't something regex parsing can
  /// do, but that call is never asked to pick or move a place, so it can't
  /// reintroduce this same mismatch.
  ///
  /// Returns null when [request.priorConversationContext] doesn't actually
  /// contain a parseable day-by-day plan (e.g. a reply saved before this
  /// format existed, or the traveler tapped "Build Full Itinerary" off a
  /// short single-recommendation reply with no real "Day N" structure) —
  /// the caller falls back to the normal AI-generation path in that case.
  Future<Itinerary?> generateItineraryFromChatPlan(
    AiItineraryRequest request, {
    required String coverImageUrl,
  }) async {
    final parsedDays = _parseChatDayPlan(request.priorConversationContext!);
    if (parsedDays == null || parsedDays.isEmpty) return null;

    final destinationCoordinates = await _resolveDestinationCoordinates(
      request,
    );

    final results = await Future.wait([
      _geocodeActivities(
        parsedDays,
        areaName: request.destinationName,
        biasLatitude: destinationCoordinates.latitude,
        biasLongitude: destinationCoordinates.longitude,
      ),
      _fetchAccommodations(request),
      _fetchPlaceAttractions(request),
      _provinceRepository.getById(request.provinceId),
      destinationCoordinates.latitude != null &&
              destinationCoordinates.longitude != null
          ? _fetchForecast(
              latitude: destinationCoordinates.latitude!,
              longitude: destinationCoordinates.longitude!,
              days: parsedDays.length,
            )
          : Future.value(<WeatherForecast>[]),
    ]);
    final geocodedDays = results[0] as List<ItineraryDay>;
    final accommodations = results[1] as List<PlaceRecommendation>;
    final placeAttractions = results[2] as List<PlaceRecommendation>;
    final province = results[3] as Province?;
    final weather = results[4] as List<WeatherForecast>;

    final (
      budgetBreakdown,
      totalBudget,
      travelTips,
    ) = await _estimateBudgetAndTips(
      request,
      geocodedDays: geocodedDays,
      province: province,
      accommodations: accommodations,
    );

    return Itinerary(
      destinationName: request.destinationName,
      coverImageUrl: coverImageUrl,
      totalDays: geocodedDays.length,
      travelers: request.travelers,
      totalBudget: totalBudget,
      days: geocodedDays,
      budgetBreakdown: budgetBreakdown,
      weather: weather,
      travelTips: travelTips,
      recommendedRestaurantIds: const [],
      nearbyAttractionIds: const [],
      recommendedAccommodations: accommodations,
      recommendedPlaceAttractions: placeAttractions,
      accommodationName: request.accommodationName ?? '',
      destinationId: request.destinationId.isEmpty
          ? null
          : request.destinationId,
      destinationLatitude: destinationCoordinates.latitude,
      destinationLongitude: destinationCoordinates.longitude,
    );
  }

  /// Recognized time-of-day labels for a chat-parsed activity line — used
  /// to reject a line that only superficially looks like "<label>: ...
  /// **bold**..." (e.g. "Note: **Important** — bring cash") from being
  /// mistaken for a real day activity.
  static const Set<String> _dayPartKeywords = {
    'morning',
    'afternoon',
    'evening',
    'noon',
    'night',
  };

  /// Parses a chat reply's `Day <N> – <theme>` / `<Time>: **<Place>** —
  /// <sentence>` structure (see [ChatPrompts.systemPrompt]) into
  /// ungeocoded [ItineraryDay]s — [ItineraryActivity.location] is set but
  /// `latitude`/`longitude` stay null until [_geocodeActivities] resolves
  /// them. Tolerant of small formatting drift a real reply can still have
  /// despite the system prompt's exact-format instruction (an LLM doesn't
  /// follow a format instruction with 100% consistency) — a leading bullet
  /// marker is optional, and a lead-in word or two between the time label's
  /// colon and the bold place name (e.g. "Morning: Explore **Burnham
  /// Park** – ...", not just "Morning: **Burnham Park** – ...") is folded
  /// into the description rather than causing the whole line to be
  /// dropped. What's NOT tolerated: a place name that isn't `**bold**`, or
  /// a label that isn't recognizably a time of day (see [_dayPartKeywords])
  /// — those still fall through to the AI-regeneration fallback rather than
  /// risk mis-parsing an unrelated line as an activity.
  ///
  /// Returns null when no `Day <N>` header is found at all (nothing to
  /// build from) rather than an empty list, so callers can tell "no
  /// structured plan here" apart from "structured, but every day parsed
  /// empty" (both fall back the same way, but the distinction matters for
  /// debugging a real reply that unexpectedly failed to parse).
  List<ItineraryDay>? _parseChatDayPlan(String content) {
    final dayHeaderPattern = RegExp(
      r'^Day\s+(\d+)\s*[–—-]\s*(.+)$',
      multiLine: true,
    );
    final linePattern = RegExp(
      r'^[-•]?\s*([A-Za-z][A-Za-z\s-]{1,24}):\s*(.+)$',
    );
    final boldPattern = RegExp(r'\*\*(.+?)\*\*');

    final dayMatches = dayHeaderPattern.allMatches(content).toList();
    if (dayMatches.isEmpty) return null;

    final days = <ItineraryDay>[];
    for (var i = 0; i < dayMatches.length; i++) {
      final match = dayMatches[i];
      final dayNumber = int.tryParse(match.group(1)!) ?? (days.length + 1);
      final blockStart = match.end;
      final blockEnd = i + 1 < dayMatches.length
          ? dayMatches[i + 1].start
          : content.length;
      final block = content.substring(blockStart, blockEnd);

      final activities = <ItineraryActivity>[];
      for (final rawLine in block.split('\n')) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;
        final lineMatch = linePattern.firstMatch(line);
        if (lineMatch == null) continue;
        final time = lineMatch.group(1)!.trim();
        if (!_dayPartKeywords.any((k) => time.toLowerCase().contains(k)))
          continue;
        final rest = lineMatch.group(2)!.trim();
        final boldMatch = boldPattern.firstMatch(rest);
        if (boldMatch == null) continue;
        final placeName = boldMatch.group(1)!.trim();
        if (placeName.isEmpty) continue;
        final before = rest.substring(0, boldMatch.start).trim();
        final after = rest
            .substring(boldMatch.end)
            .trim()
            .replaceFirst(RegExp(r'^[–—-]\s*'), '');
        final description = [
          before,
          after,
        ].where((s) => s.isNotEmpty).join(' ').trim();
        activities.add(
          ItineraryActivity(
            time: time,
            title: placeName,
            description: description.isEmpty
                ? 'Visit $placeName.'
                : description,
            iconKey: _iconKeyForActivity(time, placeName, description),
            location: placeName,
          ),
        );
      }
      if (activities.isEmpty) continue;
      days.add(
        ItineraryDay(
          dayNumber: dayNumber,
          dateLabel: '',
          activities: activities,
        ),
      );
    }
    return days.isEmpty ? null : days;
  }

  /// A best-effort, keyword-based icon pick for a chat-parsed activity —
  /// there's no AI call in [generateItineraryFromChatPlan]'s day-building
  /// path to ask for one (see that method's doc comment for why), so this
  /// fills the same visual role [ItineraryPrompts.iconKeys] guidance does
  /// for an AI-picked one. Falls back to a time-of-day-appropriate default
  /// rather than [IconRegistry]'s own generic fallback, so a chat-derived
  /// itinerary's activity list doesn't visibly look less considered than an
  /// AI-generated one.
  String _iconKeyForActivity(
    String time,
    String placeName,
    String description,
  ) {
    final text = '$placeName $description'.toLowerCase();
    if (text.contains('museum') ||
        text.contains('gallery') ||
        text.contains('heritage') ||
        text.contains('histor')) {
      return 'account_balance';
    }
    if (text.contains('hik') ||
        text.contains('trail') ||
        text.contains('trek') ||
        text.contains('peak') ||
        text.contains('summit')) {
      return 'hiking';
    }
    if (text.contains('beach') ||
        text.contains('island') ||
        text.contains('cove'))
      return 'beach_access';
    if (text.contains('forest') ||
        text.contains('jungle') ||
        text.contains('rainforest'))
      return 'forest';
    if (text.contains('market') ||
        text.contains('shop') ||
        text.contains('souvenir') ||
        text.contains('bazaar')) {
      return 'shopping_bag';
    }
    if (text.contains('festival') || text.contains('celebrat'))
      return 'celebration';
    if (text.contains('boat') ||
        text.contains('island hop') ||
        text.contains('ferry'))
      return 'directions_boat';
    if (text.contains('garden') ||
        text.contains('park') ||
        text.contains('view') ||
        text.contains('scenic')) {
      return 'landscape';
    }
    if (text.contains('café') ||
        text.contains('cafe') ||
        text.contains('coffee') ||
        text.contains('dessert') ||
        text.contains('restaurant') ||
        text.contains('dine') ||
        text.contains('food') ||
        text.contains('eat') ||
        text.contains('breakfast') ||
        text.contains('lunch') ||
        text.contains('dinner')) {
      return time.toLowerCase().contains('evening')
          ? 'restaurant'
          : 'lunch_dining';
    }
    return time.toLowerCase().contains('evening') ? 'restaurant' : 'landscape';
  }

  /// The narrow AI call [generateItineraryFromChatPlan] uses to cost out an
  /// already-fixed day plan and write travel tips for it — see
  /// [ItineraryPrompts.budgetAndTipsSystem]'s doc comment for why this stays
  /// separate from (and much smaller than) the full itinerary-generation
  /// prompt. Falls back to a plain even-split estimate and no travel tips
  /// (rather than throwing) if the call fails or returns something
  /// unparseable — a chat-derived itinerary with a slightly rougher budget
  /// estimate is still far better than failing the whole generation over a
  /// secondary detail.
  Future<(List<BudgetItem>, double, List<String>)> _estimateBudgetAndTips(
    AiItineraryRequest request, {
    required List<ItineraryDay> geocodedDays,
    required Province? province,
    required List<PlaceRecommendation> accommodations,
  }) async {
    final dayPlanSummary = geocodedDays
        .map(
          (day) =>
              'Day ${day.dayNumber}: ${day.activities.map((a) => '${a.title} (${a.time})').join(', ')}',
        )
        .join('\n');

    try {
      final raw = await _openAi.complete(
        messages: [
          {'role': 'system', 'content': ItineraryPrompts.budgetAndTipsSystem()},
          {
            'role': 'user',
            'content': ItineraryPrompts.budgetAndTipsUser(
              request: request,
              dayPlanSummary: dayPlanSummary,
              emergencyHotlines: province?.emergencyHotlines ?? const [],
              provinceTravelTips: province?.travelTips ?? const [],
              provinceBudgetMin: province?.estimatedDailyBudgetMin,
              provinceBudgetMax: province?.estimatedDailyBudgetMax,
              accommodationName:
                  request.accommodationName ??
                  (accommodations.isNotEmpty
                      ? accommodations.first.name
                      : null),
            ),
          },
        ],
        temperature: 0.5,
        maxTokens: 900,
        jsonMode: true,
      );
      final json = jsonDecode(_stripCodeFences(raw)) as Map<String, dynamic>;
      final budgetBreakdown = (json['budgetBreakdown'] as List? ?? const [])
          .map((b) => BudgetItem.fromMap(Map<String, dynamic>.from(b as Map)))
          .toList();
      final travelTips = List<String>.from(
        json['travelTips'] as List? ?? const [],
      );
      final totalBudget =
          (json['totalBudget'] as num?)?.toDouble() ??
          budgetBreakdown.fold<double>(0, (sum, b) => sum + b.amount);
      if (budgetBreakdown.isEmpty)
        throw const AiException('empty budget breakdown');
      return (budgetBreakdown, totalBudget, travelTips);
    } catch (_) {
      return (
        _fallbackBudgetBreakdown(request),
        _fallbackTotalBudget(request),
        <String>[],
      );
    }
  }

  /// Used only when [_estimateBudgetAndTips]'s AI call itself fails — an
  /// even, generic split of the traveler's chosen budget tier range across
  /// the same 5 categories the AI path always uses, so the itinerary still
  /// has a complete, sensibly-shaped budget summary instead of an empty one.
  double _fallbackTotalBudget(AiItineraryRequest request) {
    // budgetRange is a display string like "₱5k – ₱15k" or "₱40k+" (see
    // planner_options.dart's budgetTiers) — "k" means thousands, so it has
    // to be handled explicitly or "5k" parses as the number 5.
    final numbers = <double>[];
    for (final m in RegExp(
      r'([\d,]+)\s*(k)?',
      caseSensitive: false,
    ).allMatches(request.budgetRange)) {
      final n = double.tryParse(m.group(1)!.replaceAll(',', ''));
      if (n == null || n <= 0) continue;
      numbers.add(m.group(2) != null ? n * 1000 : n);
    }
    if (numbers.isEmpty) return 15000;
    return numbers.length > 1 ? (numbers[0] + numbers[1]) / 2 : numbers[0];
  }

  List<BudgetItem> _fallbackBudgetBreakdown(AiItineraryRequest request) {
    final total = _fallbackTotalBudget(request);
    const shares = {
      'Transportation': 0.2,
      'Food': 0.3,
      'Entrance Fees': 0.15,
      'Accommodation': 0.25,
      'Miscellaneous': 0.1,
    };
    const iconKeys = {
      'Transportation': 'directions_boat',
      'Food': 'restaurant',
      'Entrance Fees': 'payments',
      'Accommodation': 'hotel',
      'Miscellaneous': 'shopping_bag',
    };
    const colorKeys = {
      'Transportation': 'primary',
      'Food': 'secondary',
      'Entrance Fees': 'accent',
      'Accommodation': 'primaryDark',
      'Miscellaneous': 'secondaryDark',
    };
    return shares.entries
        .map(
          (e) => BudgetItem(
            label: e.key,
            amount: total * e.value,
            iconKey: iconKeys[e.key]!,
            colorKey: colorKeys[e.key]!,
          ),
        )
        .toList();
  }

  Future<Itinerary> _generateItineraryViaAi(
    AiItineraryRequest request, {
    required String coverImageUrl,
    bool forceRefresh = false,
  }) async {
    // Resolved first, on its own: a specific-destination trip already has
    // this on the request (returns instantly, no await), and only a
    // whole-province trip pays for the one geocoding call — everything else
    // below either doesn't need it (restaurants/accommodations/attractions
    // key off `request.latitude`/`longitude` directly) or does (weather), so
    // this can't simply join the batch below without weather waiting on its
    // own result anyway.
    final destinationCoordinates = await _resolveDestinationCoordinates(
      request,
    );

    // Restaurants come from the curated Firestore catalog (not LGU content —
    // business-owner-submitted); accommodations and attractions come live
    // from Places API; province facts (emergency hotlines/travel tips/budget
    // guide) come from Firestore too — all fetched together so the (often
    // slower) live Places lookups don't add latency on top of the Firestore
    // reads. Weather joins this same batch (rather than running alongside
    // the AI completion call, as before) so the forecast is already in hand
    // by the time the prompt is built below and can actually inform which
    // activities the model picks — not just decorate the result afterward.
    final candidateResults = await Future.wait([
      _restaurantRepository.filter(provinceId: request.provinceId, limit: 30),
      _fetchAccommodations(request),
      _fetchPlaceAttractions(request),
      _provinceRepository.getById(request.provinceId),
      destinationCoordinates.latitude != null &&
              destinationCoordinates.longitude != null
          ? _fetchForecast(
              latitude: destinationCoordinates.latitude!,
              longitude: destinationCoordinates.longitude!,
              days: request.days,
            )
          : Future.value(<WeatherForecast>[]),
    ]);
    final candidateRestaurants = <Restaurant>[
      ...candidateResults[0] as List<Restaurant>,
    ];
    final accommodations = candidateResults[1] as List<PlaceRecommendation>;
    final candidatePlaceAttractions = <PlaceRecommendation>[
      ...candidateResults[2] as List<PlaceRecommendation>,
    ];
    final province = candidateResults[3] as Province?;
    final weather = candidateResults[4] as List<WeatherForecast>;

    // A trip generated from an AI Chat conversation ("Build Full
    // Itinerary") needs the specific places that chat reply already named
    // to actually be pickable here, not just fetched fresh and hoped to
    // overlap — see AiItineraryRequest.priorConversationEntities' doc
    // comment for why.
    _mergePriorConversationEntities(
      request.priorConversationEntities,
      restaurants: candidateRestaurants,
      attractions: candidatePlaceAttractions,
    );

    // Closer candidates lead each list — anchored on the accommodation when
    // the traveler gave one, otherwise on the destination itself (always
    // resolved by now, even for a whole-province trip — see
    // _resolveDestinationCoordinates), so every trip gets a real geographic
    // ranking signal, not just ones with a stated accommodation. Combined
    // with the explicit prompt instruction below, this both biases which
    // candidates the model picks and pushes it to keep a single day's picks
    // near each other — the model can't reliably reason about real-world
    // distance from a bare coordinate itself, so the list order has to do
    // that work for it.
    _sortByDistanceFromAnchor(
      candidateRestaurants,
      request,
      (r) => r.latitude,
      (r) => r.longitude,
      fallbackAnchor: destinationCoordinates,
    );
    _sortByDistanceFromAnchor(
      candidatePlaceAttractions,
      request,
      (p) => p.latitude,
      (p) => p.longitude,
      fallbackAnchor: destinationCoordinates,
    );

    final signature = jsonEncode({
      'destinationId': request.destinationId,
      'days': request.days,
      'travelers': request.travelers,
      'travelerType': request.travelerType,
      'budget': request.budgetTierLabel,
      'transportation': request.transportation.toList()..sort(),
      'interests': request.interests.toList()..sort(),
      'accommodationName': request.accommodationName,
      'priorConversationContext': request.priorConversationContext,
      'refinementInstruction': request.refinementInstruction,
      'tripPace': request.tripPace,
    });

    // "Regenerate" on the result screen deliberately skips the cache lookup
    // (but still writes its result below) — it exists specifically to ask
    // for a *different* itinerary for the same trip, unlike an accidental
    // resubmission of the same untouched Planner form, which should reuse
    // what was already generated instead of spending another API call.
    var raw = forceRefresh ? null : await _cache.get('itinerary', signature);
    final isFreshResponse = raw == null;
    if (raw == null) {
      raw = await _openAi.complete(
        messages: [
          {'role': 'system', 'content': ItineraryPrompts.system()},
          {
            'role': 'user',
            'content': ItineraryPrompts.user(
              request: request,
              candidateRestaurantNames: candidateRestaurants
                  .map((r) => r.name)
                  .toList(),
              candidateAttractionNames: candidatePlaceAttractions
                  .map((p) => p.name)
                  .toList(),
              candidateHotelNames: accommodations.map((a) => a.name).toList(),
              emergencyHotlines: province?.emergencyHotlines ?? const [],
              provinceTravelTips: province?.travelTips ?? const [],
              provinceBudgetMin: province?.estimatedDailyBudgetMin,
              provinceBudgetMax: province?.estimatedDailyBudgetMax,
              accommodationName: request.accommodationName,
              priorConversationContext: request.priorConversationContext,
              weatherForecast: weather,
              refinementInstruction: request.refinementInstruction,
              tripPace: request.tripPace,
            ),
          },
        ],
        temperature: 0.7,
        maxTokens: 2400,
        jsonMode: true,
      );
      // Not cached yet — only once _parseItinerary below confirms it's
      // actually usable. Caching it here unconditionally meant a truncated/
      // malformed response (hits the token cap mid-object, a flaky
      // provider response) got cached as-is, and every retry with the same
      // unchanged form kept hitting the cache and getting back that exact
      // same broken text for up to the cache's full TTL — with no way to
      // actually get a fresh attempt short of changing the form.
    }

    final itinerary = await _parseItinerary(
      raw,
      request: request,
      coverImageUrl: coverImageUrl,
      candidateRestaurants: candidateRestaurants,
      candidatePlaceAttractions: candidatePlaceAttractions,
      accommodations: accommodations,
      weather: weather,
      destinationLatitude: destinationCoordinates.latitude,
      destinationLongitude: destinationCoordinates.longitude,
    );
    // Only reached once parsing above actually succeeded — see the comment
    // where the old unconditional cache write used to sit.
    if (isFreshResponse) {
      await _cache.set('itinerary', signature, raw);
    }
    return itinerary;
  }

  /// [AiItineraryRequest.latitude]/`longitude` are only ever set for a
  /// specific-destination trip (see `ai_planner_screen.dart`'s `_generate()`)
  /// — a "whole province" trip has no single stored coordinate, which used
  /// to mean no weather forecast, no live accommodations/attractions bias,
  /// and no main-destination anchor for the day route map. Falls back to
  /// geocoding the province itself via the same live Places text search
  /// [_geocodeActivities] uses, so those features degrade to "centered on
  /// the province" instead of not working at all. Returns the request's own
  /// coordinates unchanged when they're already set — no extra network call.
  Future<({double? latitude, double? longitude})>
  _resolveDestinationCoordinates(AiItineraryRequest request) async {
    if (request.latitude != null && request.longitude != null) {
      return (latitude: request.latitude, longitude: request.longitude);
    }
    final query = '${request.provinceName}, Philippines';
    final results = await _places.searchText(
      textQuery: query,
      maxResultCount: 1,
    );
    if (results.isEmpty || !results.first.hasCoordinates)
      return (latitude: null, longitude: null);
    return (
      latitude: results.first.latitude,
      longitude: results.first.longitude,
    );
  }

  /// Sorts [items] ascending by distance from an anchor point, in place —
  /// [request]'s accommodation coordinate when the traveler gave one,
  /// otherwise [fallbackAnchor] (the resolved destination itself). A no-op
  /// only when neither anchor is available. An item with no coordinates of
  /// its own sorts last (never excluded), so it can still be picked, just
  /// without a ranking boost.
  void _sortByDistanceFromAnchor<T>(
    List<T> items,
    AiItineraryRequest request,
    double? Function(T) latitudeOf,
    double? Function(T) longitudeOf, {
    required ({double? latitude, double? longitude}) fallbackAnchor,
  }) {
    final anchorLat = request.accommodationLatitude ?? fallbackAnchor.latitude;
    final anchorLng =
        request.accommodationLongitude ?? fallbackAnchor.longitude;
    // Also covers the empty-list case: `_fetchAccommodations`/
    // `_fetchPlaceAttractions` return a `const []` when the destination has
    // no coordinates, and sorting an unmodifiable list throws.
    if (anchorLat == null || anchorLng == null || items.isEmpty) return;

    double distanceOf(T item) {
      final lat = latitudeOf(item);
      final lng = longitudeOf(item);
      if (lat == null || lng == null) return double.infinity;
      return haversineKm(anchorLat, anchorLng, lat, lng);
    }

    items.sort((a, b) => distanceOf(a).compareTo(distanceOf(b)));
  }

  /// A self-contained sample trip (same content the pre-AI planner used to
  /// show) for when no AI provider key is configured. Ignores [request] entirely
  /// rather than half-personalizing it — mixing a real destination/cover
  /// photo with canned El Nido day activities would look more broken than a
  /// clearly-labeled sample.
  Itinerary _demoItinerary() {
    return Itinerary(
      destinationName: mockItinerary.destinationName,
      coverImageUrl: mockItinerary.coverImageUrl,
      totalDays: mockItinerary.totalDays,
      travelers: mockItinerary.travelers,
      totalBudget: mockItinerary.totalBudget,
      budgetBreakdown: mockItinerary.budgetBreakdown,
      weather: mockItinerary.weather,
      travelTips: [
        'This is a sample itinerary — set the OPENAI_API_KEY Cloud Functions secret for a real, personalized AI-generated plan.',
        ...mockItinerary.travelTips,
      ],
      recommendedRestaurantIds: mockItinerary.recommendedRestaurantIds,
      nearbyAttractionIds: mockItinerary.nearbyAttractionIds,
      days: mockItinerary.days,
    );
  }

  /// Top-rated live hotels near the destination, snapshotted onto the
  /// generated [Itinerary] (see [PlaceRecommendation]'s doc comment) —
  /// surfaced directly from real results rather than routed through the
  /// LLM's own judgement, which would risk it hallucinating a
  /// plausible-sounding hotel name that isn't actually one of the results.
  Future<List<PlaceRecommendation>> _fetchAccommodations(
    AiItineraryRequest request,
  ) async {
    if (request.latitude == null || request.longitude == null) return const [];
    final places = await _places.searchNearby(
      latitude: request.latitude!,
      longitude: request.longitude!,
      includedTypes: PlaceCategory.lodging,
      maxResultCount: 10,
    );
    final ranked = [...places]
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return ranked
        .take(3)
        .map(
          (p) => PlaceRecommendation(
            placeId: p.id,
            name: p.name,
            rating: p.rating,
            userRatingCount: p.userRatingCount,
            priceLevel: p.priceLevel,
            photoUrl: p.photoNames.isNotEmpty
                ? _places.photoUrl(p.photoNames.first)
                : '',
            address: p.address,
            latitude: p.latitude,
            longitude: p.longitude,
            mapsUri: p.googleMapsUri,
            websiteUri: p.websiteUri,
          ),
        )
        .toList();
  }

  /// Live Places API attractions (museums, parks, landmarks) near the
  /// destination — the sole source of attraction candidates/recommendations
  /// (never the curated Firestore `tourist_spots` catalog, which is
  /// LGU-curated content), same rating-ranked top-N pattern as
  /// [_fetchAccommodations].
  Future<List<PlaceRecommendation>> _fetchPlaceAttractions(
    AiItineraryRequest request,
  ) async {
    if (request.latitude == null || request.longitude == null) return const [];
    final places = await _places.searchNearby(
      latitude: request.latitude!,
      longitude: request.longitude!,
      includedTypes: PlaceCategory.attractions,
      maxResultCount: 10,
    );
    final ranked = [...places]
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return ranked
        .take(6)
        .map(
          (p) => PlaceRecommendation(
            placeId: p.id,
            name: p.name,
            rating: p.rating,
            userRatingCount: p.userRatingCount,
            priceLevel: p.priceLevel,
            photoUrl: p.photoNames.isNotEmpty
                ? _places.photoUrl(p.photoNames.first)
                : '',
            address: p.address,
            latitude: p.latitude,
            longitude: p.longitude,
            mapsUri: p.googleMapsUri,
          ),
        )
        .toList();
  }

  /// Folds the real [Place]/[Restaurant] objects an AI Chat conversation
  /// already named (see [AiItineraryRequest.priorConversationEntities])
  /// into this generation's own freshly-fetched candidate lists, deduped by
  /// lowercased name so something already present isn't listed twice.
  /// Mutates [restaurants]/[attractions] in place — called right before
  /// [_sortByDistanceFromAnchor] ranks those same lists, so a merged-in
  /// place still gets a real distance-based position rather than always
  /// landing first or last.
  void _mergePriorConversationEntities(
    List<Object> entities, {
    required List<Restaurant> restaurants,
    required List<PlaceRecommendation> attractions,
  }) {
    if (entities.isEmpty) return;
    final knownRestaurantNames = restaurants
        .map((r) => r.name.trim().toLowerCase())
        .toSet();
    final knownAttractionNames = attractions
        .map((p) => p.name.trim().toLowerCase())
        .toSet();
    for (final entity in entities) {
      switch (entity) {
        case Restaurant r:
          if (knownRestaurantNames.add(r.name.trim().toLowerCase()))
            restaurants.add(r);
        case Place p:
          if (knownAttractionNames.add(p.name.trim().toLowerCase())) {
            attractions.add(
              PlaceRecommendation(
                placeId: p.id,
                name: p.name,
                rating: p.rating,
                userRatingCount: p.userRatingCount,
                priceLevel: p.priceLevel,
                photoUrl: p.photoNames.isNotEmpty
                    ? _places.photoUrl(p.photoNames.first)
                    : '',
                address: p.address,
                latitude: p.latitude,
                longitude: p.longitude,
                mapsUri: p.googleMapsUri,
                websiteUri: p.websiteUri,
              ),
            );
          }
        // A Business (or anything else) has no Restaurant/PlaceRecommendation-
        // shaped equivalent to merge in — see the doc comment on
        // AiItineraryRequest.priorConversationEntities.
        case Object():
          break;
      }
    }
  }

  /// Resolves each activity's own stated [ItineraryActivity.location] to a
  /// real coordinate via a live Places API text search, so the day route map
  /// (`itinerary_route_matcher.dart`) can plot places outside the trip's
  /// pre-fetched restaurant/destination/attraction candidate lists — a
  /// beach or river mentioned in an activity, say, which has no dedicated
  /// Places category and so is never one of those candidates. Runs once at
  /// generation time and gets saved with the itinerary, never re-searched on
  /// later views. Best-effort: a location too short to search meaningfully,
  /// or a search that finds nothing, just leaves that activity's coordinates
  /// null — never fabricated, never blocks generation.
  Future<List<ItineraryDay>> _geocodeActivities(
    List<ItineraryDay> days, {
    required String areaName,
    double? biasLatitude,
    double? biasLongitude,
  }) async {
    final uniqueLocations = <String>{};
    for (final day in days) {
      for (final activity in day.activities) {
        final location = activity.location.trim();
        if (location.length >= _minGeocodableLocationLength)
          uniqueLocations.add(location);
      }
    }
    if (uniqueLocations.isEmpty) return days;

    final entries = await Future.wait(
      uniqueLocations.map((location) async {
        final results = await _places.searchText(
          textQuery: '$location, $areaName',
          maxResultCount: 1,
          biasLatitude: biasLatitude,
          biasLongitude: biasLongitude,
        );
        final match = results.isNotEmpty && results.first.hasCoordinates
            ? results.first
            : null;
        return MapEntry(location, match);
      }),
    );
    final resolved = <String, Place>{
      for (final e in entries)
        if (e.value != null) e.key: e.value!,
    };
    if (resolved.isEmpty) return days;

    return days
        .map(
          (day) => ItineraryDay(
            dayNumber: day.dayNumber,
            dateLabel: day.dateLabel,
            activities: day.activities.map((activity) {
              final place = resolved[activity.location.trim()];
              if (place == null) return activity;
              return ItineraryActivity(
                time: activity.time,
                title: activity.title,
                description: activity.description,
                iconKey: activity.iconKey,
                location: activity.location,
                latitude: place.latitude,
                longitude: place.longitude,
              );
            }).toList(),
          ),
        )
        .toList();
  }

  Future<Itinerary> _parseItinerary(
    String raw, {
    required AiItineraryRequest request,
    required String coverImageUrl,
    required List<Restaurant> candidateRestaurants,
    required List<PlaceRecommendation> candidatePlaceAttractions,
    required List<PlaceRecommendation> accommodations,
    required List<WeatherForecast> weather,
    required double? destinationLatitude,
    required double? destinationLongitude,
  }) async {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(_stripCodeFences(raw)) as Map<String, dynamic>;
    } catch (_) {
      throw const AiException(
        'The AI returned an itinerary in an unexpected format. Please try again.',
      );
    }

    try {
      final days = (json['days'] as List? ?? const [])
          .map((d) => ItineraryDay.fromMap(Map<String, dynamic>.from(d as Map)))
          .toList();
      final budgetBreakdown = (json['budgetBreakdown'] as List? ?? const [])
          .map((b) => BudgetItem.fromMap(Map<String, dynamic>.from(b as Map)))
          .toList();
      final travelTips = List<String>.from(
        json['travelTips'] as List? ?? const [],
      );
      final totalBudget =
          (json['totalBudget'] as num?)?.toDouble() ??
          budgetBreakdown.fold<double>(0, (sum, b) => sum + b.amount);

      final recommendedNames = List<String>.from(
        json['recommendedRestaurantNames'] as List? ?? const [],
      );
      final attractionNames = List<String>.from(
        json['nearbyAttractionNames'] as List? ?? const [],
      );

      final restaurantIds = candidateRestaurants
          .where(
            (r) => recommendedNames.any(
              (n) => n.toLowerCase() == r.name.toLowerCase(),
            ),
          )
          .map((r) => r.id)
          .toList();
      final placeAttractionRecs = candidatePlaceAttractions
          .where(
            (p) => attractionNames.any(
              (n) => n.toLowerCase() == p.name.toLowerCase(),
            ),
          )
          .toList();

      if (days.isEmpty) {
        throw const AiException(
          'The AI returned an incomplete itinerary. Please try again.',
        );
      }

      final geocodedDays = await _geocodeActivities(
        days,
        areaName: request.destinationName,
        biasLatitude: destinationLatitude,
        biasLongitude: destinationLongitude,
      );

      return Itinerary(
        destinationName: request.destinationName,
        coverImageUrl: coverImageUrl,
        totalDays: request.days,
        travelers: request.travelers,
        totalBudget: totalBudget,
        days: geocodedDays,
        budgetBreakdown: budgetBreakdown,
        weather: weather,
        travelTips: travelTips,
        recommendedRestaurantIds: restaurantIds,
        // Attractions are Google Places-only now (never a curated
        // `tourist_spots` doc id) — see `recommendedPlaceAttractions` below.
        nearbyAttractionIds: const [],
        recommendedAccommodations: accommodations,
        recommendedPlaceAttractions: placeAttractionRecs,
        accommodationName: request.accommodationName ?? '',
        // Empty destinationId means a whole-province trip (see AiPlannerScreen's
        // _generate()) — no single destination to anchor day route maps to.
        destinationId: request.destinationId.isEmpty
            ? null
            : request.destinationId,
        // A whole-province trip has [destinationLatitude]/[destinationLongitude]
        // resolved by geocoding the province itself (see
        // `_resolveDestinationCoordinates`), not `request.latitude`/`longitude`
        // directly — those stay null for a whole-province request.
        destinationLatitude: destinationLatitude,
        destinationLongitude: destinationLongitude,
      );
    } on AiException {
      rethrow;
    } catch (_) {
      throw const AiException(
        'The AI returned an itinerary in an unexpected format. Please try again.',
      );
    }
  }

  /// Names the single specific Philippine destination (city/municipality +
  /// province, e.g. "Baguio, Benguet") [message] is about, if any — a
  /// small, fast, isolated completion (never the full chat history, and
  /// never mixed into the main reply) so a chat screen can ground its next
  /// reply in real Places data for that exact destination *before*
  /// generating it.
  ///
  /// Deliberately an LLM call rather than a raw Places text search on the
  /// whole message: a free-text destination can be phrased any number of
  /// ways (English, Taglish, casual, formal), and Places' own free-text
  /// search on a whole sentence — extra words like "plan", "budget-
  /// friendly", "for a couple" mixed in — can resolve to something ranked
  /// as relevant for reasons that have nothing to do with the actual
  /// destination meant (see `AiChatScreen._groundDestinationContext`'s doc
  /// comment for the real bug this caused: "Baguio" resolving to an
  /// unrelated town). Understanding what a sentence is actually about is
  /// exactly what a language model does well; the caller still verifies the
  /// resulting Places search result actually matches before trusting it.
  ///
  /// Returns null when the message doesn't clearly name one specific
  /// destination, or the call fails for any reason (best-effort — the
  /// caller falls back to ungrounded behavior, same as before this
  /// existed).
  Future<String?> extractDestination(String message) async {
    try {
      final reply = await _openAi.complete(
        messages: [
          {
            'role': 'system',
            'content':
                'You extract the single specific Philippine destination (city or municipality, plus its province) a traveler\'s message is about. Reply with ONLY that, in exactly "City, Province" format (e.g. "Baguio, Benguet") — never explain, never add punctuation, quotes, or any other words. If the message doesn\'t clearly name one specific real destination, reply with exactly: NONE',
          },
          {'role': 'user', 'content': message},
        ],
        temperature: 0,
        // Well above the few tokens the answer itself needs: the model
        // spends part of this budget on hidden reasoning first, and a
        // budget that only fits the answer comes back empty every time.
        maxTokens: 200,
      );
      final trimmed = reply.trim();
      if (trimmed.isEmpty || trimmed.toUpperCase() == 'NONE') return null;
      return trimmed;
    } catch (_) {
      return null;
    }
  }

  /// Regenerates a single activity for one day's time slot — used when a
  /// traveler wants a fresh pick for just, say, "Morning" without touching
  /// the rest of the day or trip. A much narrower ask than
  /// [generateItinerary]: one JSON object, not a whole itinerary (see
  /// [ItineraryPrompts.regenerateActivitySystem]).
  ///
  /// Geocoded the same best-effort way [_geocodeActivities] resolves any
  /// activity's location, but never left coordinate-less: when the specific
  /// place the AI named doesn't resolve to a real search result, this falls
  /// back to [fallbackLatitude]/[fallbackLongitude] (the trip's own
  /// destination coordinates, passed by the caller) instead — approximate,
  /// but still a real point within the actual destination, not a fabricated
  /// one, so the activity always gets a pin on the day route map rather
  /// than silently having none. Only fully coordinate-less if the caller
  /// has no destination coordinates to fall back to either.
  Future<ItineraryActivity> regenerateActivity({
    required String destinationName,
    required String time,
    required List<String> otherActivityTitles,
    double? fallbackLatitude,
    double? fallbackLongitude,
  }) async {
    final raw = await _openAi.complete(
      messages: [
        {
          'role': 'system',
          'content': ItineraryPrompts.regenerateActivitySystem(),
        },
        {
          'role': 'user',
          'content': ItineraryPrompts.regenerateActivityUser(
            destinationName: destinationName,
            time: time,
            otherActivityTitles: otherActivityTitles,
          ),
        },
      ],
      temperature: 0.9,
      maxTokens: 300,
      jsonMode: true,
    );

    Map<String, dynamic> json;
    try {
      json = jsonDecode(_stripCodeFences(raw)) as Map<String, dynamic>;
    } catch (_) {
      throw const AiException(
        'The AI returned an activity in an unexpected format. Please try again.',
      );
    }

    final title = (json['title'] as String? ?? '').trim();
    if (title.isEmpty) {
      throw const AiException(
        'The AI couldn\'t come up with a new activity. Please try again.',
      );
    }
    final location = (json['location'] as String? ?? '').trim();
    final rawIconKey = (json['iconKey'] as String? ?? '').trim();

    final results = location.length >= _minGeocodableLocationLength
        ? await _places.searchText(
            textQuery: '$location, $destinationName',
            maxResultCount: 1,
            biasLatitude: fallbackLatitude,
            biasLongitude: fallbackLongitude,
          )
        : const <Place>[];
    final match = results.isNotEmpty && results.first.hasCoordinates
        ? results.first
        : null;

    return ItineraryActivity(
      time: time,
      title: title,
      description: (json['description'] as String? ?? '').trim(),
      iconKey: rawIconKey.isEmpty ? 'landscape' : rawIconKey,
      location: location,
      latitude: match?.latitude ?? fallbackLatitude,
      longitude: match?.longitude ?? fallbackLongitude,
    );
  }

  /// Sends the conversation so far to the assistant and returns its reply.
  /// [history] should already be capped to a reasonable window by the
  /// caller (see [AiChatProvider]) to bound token usage.
  Future<String> sendChatMessage(
    List<AiChatMessage> history, {
    String? userContext,
  }) {
    return _openAi.complete(
      messages: [
        {
          'role': 'system',
          'content': ChatPrompts.systemPrompt(userContext: userContext),
        },
        ...history.map((m) => {'role': m.apiRole, 'content': m.content}),
      ],
      temperature: 0.8,
      maxTokens: 450,
    );
  }

  String _stripCodeFences(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.substring(3);
      if (text.startsWith('json')) text = text.substring(4);
      final closingIndex = text.lastIndexOf('```');
      if (closingIndex != -1) text = text.substring(0, closingIndex);
    }
    return text.trim();
  }

  // Nothing to dispose anymore — see _weatherOverride's doc comment; a
  // fresh WeatherService is created and disposed per-request instead of
  // held here for the repository's lifetime. Kept as a no-op rather than
  // removed outright since both AiChatProvider and AiPlannerProvider call
  // this unconditionally.
  void dispose() {}
}
