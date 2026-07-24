import 'dart:convert';

import '../../core/services/places_service.dart';
import '../../core/services/weather_service.dart';
import '../../data/mock/mock_itinerary.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/itinerary.dart';
import '../../domain/models/restaurant.dart';
import '../models/ai_message.dart';
import '../models/itinerary_request.dart';
import '../prompts/chat_prompts.dart';
import '../prompts/itinerary_prompts.dart';
import '../services/ai_cache_service.dart';
import '../services/openai_service.dart';

/// The only layer that talks to [OpenAiService] directly. Providers call
/// into here; nothing above this layer knows a REST API is involved.
class AiRepository {
  AiRepository({
    OpenAiService? openAiService,
    AiCacheService? cacheService,
    DestinationRepository? destinationRepository,
    RestaurantRepository? restaurantRepository,
    WeatherService? weatherService,
    PlacesService? placesService,
  })  : _openAi = openAiService ?? OpenAiService(),
        _cache = cacheService ?? AiCacheService(),
        _weather = weatherService ?? WeatherService(),
        _places = placesService ?? PlacesService(),
        _destinationRepositoryOverride = destinationRepository,
        _restaurantRepositoryOverride = restaurantRepository;

  final OpenAiService _openAi;
  final AiCacheService _cache;
  final WeatherService _weather;
  final PlacesService _places;

  // Lazy, same reasoning as AuthProvider's rarely-used repositories: this
  // provider is constructed unconditionally at app startup (so the AI
  // Planner tab is instant to open), but itinerary generation is the only
  // thing that ever needs Firestore here — no reason to pay for
  // FirebaseFirestore.instance before that actually happens.
  final DestinationRepository? _destinationRepositoryOverride;
  final RestaurantRepository? _restaurantRepositoryOverride;
  DestinationRepository? _destinationRepositoryInstance;
  RestaurantRepository? _restaurantRepositoryInstance;
  DestinationRepository get _destinationRepository =>
      _destinationRepositoryOverride ?? (_destinationRepositoryInstance ??= DestinationRepository());
  RestaurantRepository get _restaurantRepository =>
      _restaurantRepositoryOverride ?? (_restaurantRepositoryInstance ??= RestaurantRepository());

  /// Generates a full itinerary for [request] and maps it into the app's
  /// existing [Itinerary] model, grounding restaurant/attraction picks
  /// against the real live catalog (same province as the trip) so no ID is
  /// ever hallucinated and every recommendation is something that actually
  /// exists in Firestore today.
  ///
  /// No OpenAI key configured server-side (see `aiComplete` in
  /// `functions/index.js`) surfaces as an [AiException] with
  /// [AiException.isConfigError] set — caught here and turned into a
  /// clearly-labeled sample itinerary instead, so "Generate Itinerary"
  /// always leads somewhere even before a real key is set up.
  Future<Itinerary> generateItinerary(AiItineraryRequest request, {required String coverImageUrl}) async {
    try {
      return await _generateItineraryViaAi(request, coverImageUrl: coverImageUrl);
    } on AiException catch (e) {
      if (e.isConfigError) return _demoItinerary();
      rethrow;
    }
  }

  Future<Itinerary> _generateItineraryViaAi(AiItineraryRequest request, {required String coverImageUrl}) async {
    // Restaurants/attractions come from the curated Firestore catalog;
    // accommodations come live from Places API — fetched together so the
    // (often slower) live hotel lookup doesn't add latency on top of the
    // Firestore reads.
    final candidateResults = await Future.wait([
      _restaurantRepository.filter(provinceId: request.provinceId, limit: 30),
      _destinationRepository.filter(provinceId: request.provinceId, limit: 30),
      _fetchAccommodations(request),
    ]);
    final candidateRestaurants = candidateResults[0] as List<Restaurant>;
    final candidateAttractions =
        (candidateResults[1] as List<Destination>).where((d) => d.id != request.destinationId).toList();
    final accommodations = candidateResults[2] as List<PlaceRecommendation>;

    // Runs alongside the (often slower) OpenAI call below rather than
    // after it, so a real forecast never adds extra wait time.
    final weatherFuture = request.latitude != null && request.longitude != null
        ? _weather.getForecast(latitude: request.latitude!, longitude: request.longitude!, days: request.days)
        : Future.value(<WeatherForecast>[]);

    final signature = jsonEncode({
      'destinationId': request.destinationId,
      'days': request.days,
      'travelers': request.travelers,
      'travelerType': request.travelerType,
      'budget': request.budgetTierLabel,
      'transportation': request.transportation.toList()..sort(),
      'interests': request.interests.toList()..sort(),
    });

    var raw = await _cache.get('itinerary', signature);
    if (raw == null) {
      raw = await _openAi.complete(
        messages: [
          {'role': 'system', 'content': ItineraryPrompts.system()},
          {
            'role': 'user',
            'content': ItineraryPrompts.user(
              request: request,
              candidateRestaurantNames: candidateRestaurants.map((r) => r.name).toList(),
              candidateAttractionNames: candidateAttractions.map((d) => d.name).toList(),
              candidateHotelNames: accommodations.map((a) => a.name).toList(),
            ),
          },
        ],
        temperature: 0.7,
        maxTokens: 2400,
        jsonMode: true,
      );
      await _cache.set('itinerary', signature, raw);
    }
    final weather = await weatherFuture;

    return _parseItinerary(
      raw,
      request: request,
      coverImageUrl: coverImageUrl,
      candidateRestaurants: candidateRestaurants,
      candidateAttractions: candidateAttractions,
      accommodations: accommodations,
      weather: weather,
    );
  }

  /// A self-contained sample trip (same content the pre-AI planner used to
  /// show) for when no OpenAI key is configured. Ignores [request] entirely
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
  Future<List<PlaceRecommendation>> _fetchAccommodations(AiItineraryRequest request) async {
    if (request.latitude == null || request.longitude == null) return const [];
    final places = await _places.searchNearby(
      latitude: request.latitude!,
      longitude: request.longitude!,
      includedTypes: PlaceCategory.lodging,
      maxResultCount: 10,
    );
    final ranked = [...places]..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return ranked
        .take(3)
        .map(
          (p) => PlaceRecommendation(
            placeId: p.id,
            name: p.name,
            rating: p.rating,
            userRatingCount: p.userRatingCount,
            priceLevel: p.priceLevel,
            photoUrl: p.photoNames.isNotEmpty ? _places.photoUrl(p.photoNames.first) : '',
            address: p.address,
            latitude: p.latitude,
            longitude: p.longitude,
          ),
        )
        .toList();
  }

  Itinerary _parseItinerary(
    String raw, {
    required AiItineraryRequest request,
    required String coverImageUrl,
    required List<Restaurant> candidateRestaurants,
    required List<Destination> candidateAttractions,
    required List<PlaceRecommendation> accommodations,
    required List<WeatherForecast> weather,
  }) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(_stripCodeFences(raw)) as Map<String, dynamic>;
    } catch (_) {
      throw const AiException('The AI returned an itinerary in an unexpected format. Please try again.');
    }

    try {
      final days = (json['days'] as List? ?? const [])
          .map((d) => ItineraryDay.fromMap(Map<String, dynamic>.from(d as Map)))
          .toList();
      final budgetBreakdown = (json['budgetBreakdown'] as List? ?? const [])
          .map((b) => BudgetItem.fromMap(Map<String, dynamic>.from(b as Map)))
          .toList();
      final travelTips = List<String>.from(json['travelTips'] as List? ?? const []);
      final totalBudget = (json['totalBudget'] as num?)?.toDouble() ??
          budgetBreakdown.fold<double>(0, (sum, b) => sum + b.amount);

      final recommendedNames = List<String>.from(json['recommendedRestaurantNames'] as List? ?? const []);
      final attractionNames = List<String>.from(json['nearbyAttractionNames'] as List? ?? const []);

      final restaurantIds = candidateRestaurants
          .where((r) => recommendedNames.any((n) => n.toLowerCase() == r.name.toLowerCase()))
          .map((r) => r.id)
          .toList();
      final attractionIds = candidateAttractions
          .where((d) => attractionNames.any((n) => n.toLowerCase() == d.name.toLowerCase()))
          .map((d) => d.id)
          .toList();

      if (days.isEmpty) {
        throw const AiException('The AI returned an incomplete itinerary. Please try again.');
      }

      return Itinerary(
        destinationName: request.destinationName,
        coverImageUrl: coverImageUrl,
        totalDays: request.days,
        travelers: request.travelers,
        totalBudget: totalBudget,
        days: days,
        budgetBreakdown: budgetBreakdown,
        weather: weather,
        travelTips: travelTips,
        recommendedRestaurantIds: restaurantIds,
        nearbyAttractionIds: attractionIds,
        recommendedAccommodations: accommodations,
      );
    } on AiException {
      rethrow;
    } catch (_) {
      throw const AiException('The AI returned an itinerary in an unexpected format. Please try again.');
    }
  }

  /// Sends the conversation so far to the assistant and returns its reply.
  /// [history] should already be capped to a reasonable window by the
  /// caller (see [AiChatProvider]) to bound token usage.
  Future<String> sendChatMessage(List<AiChatMessage> history, {String? userContext}) {
    return _openAi.complete(
      messages: [
        {'role': 'system', 'content': ChatPrompts.systemPrompt(userContext: userContext)},
        ...history.map((m) => {'role': m.apiRole, 'content': m.content}),
      ],
      temperature: 0.8,
      maxTokens: 800,
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

  void dispose() {
    _weather.dispose();
  }
}
