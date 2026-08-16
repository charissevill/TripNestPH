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
      return _weatherOverride.getForecast(latitude: latitude, longitude: longitude, days: days);
    }
    final weatherService = WeatherService();
    try {
      return await weatherService.getForecast(latitude: latitude, longitude: longitude, days: days);
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
    final candidateRestaurants = candidateResults[0] as List<Restaurant>;
    final accommodations = candidateResults[1] as List<PlaceRecommendation>;
    final candidatePlaceAttractions =
        candidateResults[2] as List<PlaceRecommendation>;
    final province = candidateResults[3] as Province?;
    final weather = candidateResults[4] as List<WeatherForecast>;

    // When the traveler said where they're staying, closer candidates lead
    // each list — combined with the explicit prompt instruction below, this
    // gives the AI both a ranking signal and an instruction, since it can't
    // reliably reason about real-world distance from a bare coordinate.
    _sortByDistanceFromAccommodation(
      candidateRestaurants,
      request,
      (r) => r.latitude,
      (r) => r.longitude,
    );
    _sortByDistanceFromAccommodation(
      candidatePlaceAttractions,
      request,
      (p) => p.latitude,
      (p) => p.longitude,
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

  /// Sorts [items] ascending by distance from [request]'s accommodation
  /// coordinate, in place — a no-op if the traveler didn't specify one.
  /// An item with no coordinates of its own sorts last (never excluded),
  /// so it can still be picked, just without a ranking boost.
  void _sortByDistanceFromAccommodation<T>(
    List<T> items,
    AiItineraryRequest request,
    double? Function(T) latitudeOf,
    double? Function(T) longitudeOf,
  ) {
    final accommodationLat = request.accommodationLatitude;
    final accommodationLng = request.accommodationLongitude;
    // Also covers the empty-list case: `_fetchAccommodations`/
    // `_fetchPlaceAttractions` return a `const []` when the destination has
    // no coordinates, and sorting an unmodifiable list throws.
    if (accommodationLat == null || accommodationLng == null || items.isEmpty)
      return;

    double distanceOf(T item) {
      final lat = latitudeOf(item);
      final lng = longitudeOf(item);
      if (lat == null || lng == null) return double.infinity;
      return haversineKm(accommodationLat, accommodationLng, lat, lng);
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
