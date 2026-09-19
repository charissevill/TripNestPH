import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../ai/models/ai_message.dart';
import '../../ai/models/itinerary_request.dart';
import '../../ai/planner_options.dart';
import '../../ai/providers/ai_chat_provider.dart';
import '../../ai/providers/ai_planner_provider.dart';
import '../../ai/repositories/ai_repository.dart';
import '../../ai/widgets/chat_bubble.dart';
import '../../ai/widgets/chat_input_bar.dart';
import '../../ai/widgets/chat_sessions_sheet.dart';
import '../../ai/widgets/prompt_suggestion_chips.dart';
import '../../ai/widgets/suggestion_pill.dart';
import '../../ai/widgets/typing_indicator.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/services/location_service.dart';
import '../../core/services/places_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/chat_entity_matcher.dart';
import '../../core/utils/province_matcher.dart';
import '../../core/widgets/branding/app_logo.dart';
import '../../core/widgets/cards/business_card.dart';
import '../../core/widgets/cards/place_card.dart';
import '../../core/widgets/cards/restaurant_card.dart';
import '../../core/widgets/details/business_info_sheet.dart';
import '../../core/widgets/details/place_details_sheet.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/layout/max_width_container.dart';
import '../../data/repositories/business_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../domain/models/business.dart';
import '../../domain/models/place.dart';
import '../../domain/models/province.dart';
import '../../domain/models/restaurant.dart';

/// The AI Travel Assistant: a conversational chat surface that also serves
/// destination recommendations, budget estimates, smart travel tips,
/// hidden gems, food recommendations and emergency advice through natural
/// conversation and quick-tap suggestions (features 2–10), reachable from
/// the floating action button on every tab.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final PlacesService _places = PlacesService();
  final LocationService _locationService = LocationService();
  final AiRepository _aiRepository = AiRepository();

  /// Real live-Places attractions + provinces with a full guide + (when
  /// location access is granted) places genuinely near the traveler's
  /// current position, loaded once per chat session — grounds "destination
  /// recommendations"/"what's near me" answers in real, well-known places
  /// (never the curated `tourist_spots` catalog — LGU-curated content, not
  /// shown for discovery anywhere in the app anymore), the same "give it
  /// real names, never invent others" approach `ItineraryPrompts` already
  /// uses for itinerary generation. Best-effort: a load failure (or denied
  /// location) just means the chat falls back to less-specific context,
  /// same as before this existed.
  String? _realDataContext;

  /// Every live [Place]/curated [Restaurant]/approved [Business] fed into
  /// [_realDataContext] this session, keyed by lowercased name — lets
  /// [_matchedKnownEntities] resolve a **bolded** name in a reply back to
  /// the real object it named, so the chat can show an actual tappable card
  /// instead of just text. Only ever contains entities the model was
  /// actually given, so a match here is never a coincidence — the model
  /// didn't invent the name.
  final Map<String, Place> _knownPlacesByName = {};
  final Map<String, Restaurant> _knownRestaurantsByName = {};
  final Map<String, Business> _knownBusinessesByName = {};

  /// Names (lowercased) of destinations already grounded by
  /// [_groundDestinationContext] this session — a repeat mention (e.g. a
  /// follow-up "what about day 2?" for the same trip) skips re-fetching,
  /// since that destination's real places are already in [_realDataContext].
  final Set<String> _groundedDestinationNames = {};

  @override
  void initState() {
    super.initState();
    _loadRealDataContext();
  }

  /// The same Google Maps search URL shape `MapsLauncher.openDirections`
  /// builds — inlined here (rather than launching anything) so it can be
  /// handed to the AI as literal markdown link text.
  String _mapsSearchUrl({
    required double latitude,
    required double longitude,
    required String label,
  }) {
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$latitude,$longitude($label)')}';
  }

  /// Resolves the traveler's current position (best-effort — a denied/
  /// unavailable location just yields empty lists, same as Home's "Nearby
  /// You"/"Nearby Restaurants" carousels) and searches live Places around
  /// it, so "what's near me?"/"accommodation near me?"-style questions can
  /// be answered with real places genuinely close to the traveler right
  /// now, not just the nationwide featured-attractions list above (whose
  /// accommodation block is anchored to those attractions, not the
  /// traveler's own position).
  Future<
    ({
      List<Place> attractions,
      List<Place> restaurants,
      List<Place> accommodations,
    })
  >
  _fetchNearbyTraveler() async {
    final result = await _locationService.resolveCurrentPosition();
    if (!result.isGranted) {
      return (
        attractions: <Place>[],
        restaurants: <Place>[],
        accommodations: <Place>[],
      );
    }
    final position = result.position!;
    final nearby = await Future.wait([
      _places.searchNearby(
        latitude: position.latitude,
        longitude: position.longitude,
        includedTypes: PlaceCategory.attractions,
        radiusMeters: 5000,
        maxResultCount: 10,
      ),
      _places.searchNearby(
        latitude: position.latitude,
        longitude: position.longitude,
        includedTypes: PlaceCategory.dining,
        radiusMeters: 5000,
        maxResultCount: 10,
      ),
      // A wider radius than attractions/dining — accommodations are sparser
      // per area, so 5km around the traveler often finds none at all.
      _places.searchNearby(
        latitude: position.latitude,
        longitude: position.longitude,
        includedTypes: PlaceCategory.lodging,
        radiusMeters: 15000,
        maxResultCount: 10,
      ),
    ]);
    return (
      attractions: _recognizable(nearby[0]),
      restaurants: _recognizable(nearby[1]),
      accommodations: _recognizable(nearby[2]),
    );
  }

  /// Raw type-based Nearby Search surfaces minor, barely-documented points
  /// Google still tags with the requested type — e.g. an unnamed arch tagged
  /// 'tourist_attraction' with no photo and no real review history. Keeping
  /// only entries with at least one photo and a handful of ratings matches
  /// the same filter `HomeScreen`'s "Nearby You"/"Nearby Restaurants"
  /// carousels apply, so the AI never recommends a place a traveler
  /// wouldn't actually recognize.
  List<Place> _recognizable(List<Place> places) {
    return places
        .where((p) => p.photoNames.isNotEmpty && (p.userRatingCount ?? 0) >= 10)
        .toList();
  }

  Future<void> _loadRealDataContext() async {
    try {
      final results = await Future.wait([
        _places.searchText(
          textQuery: 'top tourist attractions in the Philippines',
          maxResultCount: 20,
        ),
        ProvinceRepository().getAll(),
        // Deliberately NOT getPopular(): that filters on `isPopular`, a flag
        // nothing in the app (admin screens included) ever actually sets —
        // an owner-submitted restaurant is real and published the moment
        // it's approved, so it should be groundable in chat from day one,
        // not stuck waiting on a curation step that never happens. filter()
        // with no constraints just returns published restaurants, same
        // "everything approved, no popularity gate" rule businesses (below)
        // already use.
        RestaurantRepository().filter(limit: 30),
        BusinessRepository().getAllApproved(limit: 30),
      ]);
      final attractionPlaces = (results[0] as List<Place>).take(10).toList();
      final provinces = (results[1] as List<Province>)
          .where((p) => p.hasContent)
          .toList();
      final restaurants = results[2] as List<Restaurant>;
      final businesses = results[3] as List<Business>;
      final nearbyTraveler = await _fetchNearbyTraveler();

      final parts = <String>[];
      if (attractionPlaces.isNotEmpty) {
        parts.add(
          'Real tourist attractions in the Philippines (from live Google Places data) you can '
          'recommend by name (never invent an attraction that isn\'t one of these or generally well-known): '
          '${attractionPlaces.map((p) => p.address.isNotEmpty ? '${p.name} (${p.address})' : p.name).join(', ')}.',
        );
      }

      final attractionsWithLinks = attractionPlaces
          .where((p) => p.websiteUri.isNotEmpty || p.googleMapsUri.isNotEmpty)
          .toList();
      if (attractionsWithLinks.isNotEmpty) {
        parts.add(
          'Real links on file for some of those attractions — only use these exact URLs, never invent one: '
          '${attractionsWithLinks.map((p) {
            final links = <String>[];
            if (p.websiteUri.isNotEmpty) links.add('website: ${p.websiteUri}');
            if (p.googleMapsUri.isNotEmpty) links.add('map: ${p.googleMapsUri}');
            return '${p.name} (${links.join(', ')})';
          }).join('; ')}.',
        );
      }

      if (nearbyTraveler.attractions.isNotEmpty ||
          nearbyTraveler.restaurants.isNotEmpty ||
          nearbyTraveler.accommodations.isNotEmpty) {
        final nearbyPlaces = [
          ...nearbyTraveler.attractions,
          ...nearbyTraveler.restaurants,
          ...nearbyTraveler.accommodations,
        ];
        parts.add(
          'Real places near the traveler\'s current location right now (from live Google Places '
          'data) — use these if they ask something like "what\'s near me", "restaurants nearby", or '
          '"accommodation near me"/"hotel recommendations near me", never invent a place that isn\'t '
          'one of these: '
          '${nearbyPlaces.map((p) => p.address.isNotEmpty ? '${p.name} (${p.address})' : p.name).join(', ')}.',
        );
        final nearbyLinks = nearbyPlaces
            .where((p) => p.websiteUri.isNotEmpty || p.googleMapsUri.isNotEmpty)
            .toList();
        if (nearbyLinks.isNotEmpty) {
          parts.add(
            'Real links on file for some of those nearby places — only use these exact URLs, never invent one: '
            '${nearbyLinks.map((p) {
              final links = <String>[];
              if (p.websiteUri.isNotEmpty) links.add('website: ${p.websiteUri}');
              if (p.googleMapsUri.isNotEmpty) links.add('map: ${p.googleMapsUri}');
              return '${p.name} (${links.join(', ')})';
            }).join('; ')}.',
          );
        }
      }

      // Bounded to a handful of attractions (not every one) so opening the
      // chat costs at most a few `placesSearchNearby` calls, not one per
      // attraction — `PlacesCacheService`'s 24h cache makes repeat opens
      // free anyway. Live, not curated: this app has no vetted accommodation
      // catalog, so real hotel names/links only exist via a live Places
      // lookup (same `PlaceCategory.lodging` search
      // `AiRepository._fetchAccommodations` already uses for itineraries).
      final attractionsWithCoords = attractionPlaces
          .where((p) => p.hasCoordinates)
          .take(3)
          .toList();
      final accommodationResults = await Future.wait(
        attractionsWithCoords.map(
          (p) => _places.searchNearby(
            latitude: p.latitude!,
            longitude: p.longitude!,
            includedTypes: PlaceCategory.lodging,
            maxResultCount: 5,
          ),
        ),
      );
      final accommodationsByAttraction = <Place, List<Place>>{};
      for (var i = 0; i < attractionsWithCoords.length; i++) {
        final ranked = [...accommodationResults[i]]
          ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        if (ranked.isNotEmpty)
          accommodationsByAttraction[attractionsWithCoords[i]] = ranked
              .take(2)
              .toList();
      }
      if (accommodationsByAttraction.isNotEmpty) {
        parts.add(
          'Real accommodations (hotels/resorts) near some featured attractions you can recommend by name '
          '(never invent a hotel/resort that isn\'t one of these): '
          '${accommodationsByAttraction.entries.map((e) => '${e.key.name}: ${e.value.map((p) => p.name).join(', ')}').join('; ')}.',
        );
        final accommodationLinks = accommodationsByAttraction.values
            .expand((places) => places)
            .where((p) => p.websiteUri.isNotEmpty || p.googleMapsUri.isNotEmpty)
            .toList();
        if (accommodationLinks.isNotEmpty) {
          parts.add(
            'Real links on file for some of those accommodations — only use these exact URLs, never invent one: '
            '${accommodationLinks.map((p) {
              final links = <String>[];
              if (p.websiteUri.isNotEmpty) links.add('website: ${p.websiteUri}');
              if (p.googleMapsUri.isNotEmpty) links.add('map: ${p.googleMapsUri}');
              return '${p.name} (${links.join(', ')})';
            }).join('; ')}.',
          );
        }
      }

      if (restaurants.isNotEmpty) {
        parts.add(
          'Real restaurants in the TripNest PH catalog you can recommend by name '
          '(never invent a restaurant that isn\'t one of these or generally well-known): '
          '${restaurants.map((r) => '${r.name} (${r.provinceName})').join(', ')}.',
        );
      }

      final restaurantsWithLinks = restaurants
          .where(
            (r) =>
                r.websiteUrl.isNotEmpty ||
                (r.latitude != null && r.longitude != null),
          )
          .toList();
      if (restaurantsWithLinks.isNotEmpty) {
        parts.add(
          'Real links on file for some of those restaurants — only use these exact URLs, never invent one: '
          '${restaurantsWithLinks.map((r) {
            final links = <String>[];
            if (r.websiteUrl.isNotEmpty) links.add('website: ${r.websiteUrl}');
            if (r.latitude != null && r.longitude != null) {
              links.add('map: ${_mapsSearchUrl(latitude: r.latitude!, longitude: r.longitude!, label: r.name)}');
            }
            return '${r.name} (${links.join(', ')})';
          }).join('; ')}.',
        );
      }

      // Approved businessOwner-submitted listings (accommodations, tour
      // operators, shops, transport, etc.) — the traveler-facing directory
      // behind Explore's "Businesses" tab. A foodAndDining one is already
      // covered by [restaurants] above (it's mirrored into that catalog),
      // so this is every *other* category, plus a name-only mention of any
      // food ones not already in the (capped-at-10) restaurants list.
      if (businesses.isNotEmpty) {
        parts.add(
          'Real local businesses in the TripNest PH directory you can recommend by name '
          '(never invent one that isn\'t one of these): '
          '${businesses.map((b) => '${b.name} (${BusinessCategory.label(b.category)}, ${b.provinceName})').join(', ')}.',
        );
      }

      final businessesWithLinks = businesses
          .where(
            (b) =>
                b.websiteUrl.isNotEmpty ||
                b.contactNumber.isNotEmpty ||
                b.address.isNotEmpty,
          )
          .toList();
      if (businessesWithLinks.isNotEmpty) {
        parts.add(
          'Real contact/location details on file for some of those businesses — only use these exact details, never invent one: '
          '${businessesWithLinks.map((b) {
            final details = <String>[];
            if (b.websiteUrl.isNotEmpty) details.add('website: ${b.websiteUrl}');
            if (b.contactNumber.isNotEmpty) details.add('phone: ${b.contactNumber}');
            if (b.address.isNotEmpty) details.add('address: ${b.address}');
            return '${b.name} (${details.join(', ')})';
          }).join('; ')}.',
        );
      }

      if (provinces.isNotEmpty) {
        parts.add(
          'Provinces with a full TripNest PH in-app travel guide: ${provinces.map((p) => p.name).join(', ')}.',
        );
      }

      final withHotlines = provinces
          .where((p) => p.emergencyHotlines.isNotEmpty)
          .toList();
      if (withHotlines.isNotEmpty) {
        parts.add(
          'Real emergency hotlines on file per province (use these verbatim if the traveler asks about safety/emergencies in one of these provinces, instead of inventing generic numbers): '
          '${withHotlines.map((p) => '${p.name}: ${p.emergencyHotlines.map((h) => '${h.label} ${h.number}').join(', ')}').join('; ')}.',
        );
      }

      final withTips = provinces.where((p) => p.travelTips.isNotEmpty).toList();
      if (withTips.isNotEmpty) {
        parts.add(
          'Official TripNest PH travel tips on file per province: '
          '${withTips.map((p) => '${p.name}: ${p.travelTips.join('; ')}').join(' | ')}.',
        );
      }

      // cultureNotes (titled etiquette cards) when a province has them,
      // otherwise the older plain-paragraph localCulture field — same
      // fallback the province page itself uses (see _CultureNoteCard's doc
      // comment on ProvinceDetailsScreen). Grounds "how do I greet someone",
      // "what should I wear at a temple/church", "local customs" questions
      // in real, admin-curated content instead of the model's own general
      // knowledge of the Philippines.
      final withCulture = provinces
          .where((p) => p.cultureNotes.isNotEmpty || p.localCulture.isNotEmpty)
          .toList();
      if (withCulture.isNotEmpty) {
        parts.add(
          'Real local culture/etiquette notes on file per province (use these — never a generic guess — when the traveler asks about local customs, greetings, dress code, or etiquette): '
          '${withCulture.map((p) {
            final text = p.cultureNotes.isNotEmpty ? p.cultureNotes.map((n) => '${n.title}: ${n.body}').join('; ') : p.localCulture;
            return '${p.name}: $text';
          }).join(' | ')}.',
        );
      }

      final withBudget = provinces
          .where(
            (p) =>
                p.estimatedDailyBudgetMin > 0 && p.estimatedDailyBudgetMax > 0,
          )
          .toList();
      if (withBudget.isNotEmpty) {
        parts.add(
          'Real typical daily budget guide on file per province: '
          '${withBudget.map((p) => '${p.name}: ₱${p.estimatedDailyBudgetMin.toStringAsFixed(0)}–₱${p.estimatedDailyBudgetMax.toStringAsFixed(0)}/day').join(', ')}.',
        );
      }

      // Every Place/Restaurant actually handed to the model this session —
      // see _knownPlacesByName's doc comment. Keyed last-write-wins by
      // lowercased name, which is fine here: a genuine collision is the
      // same real-world place appearing in two of these lists.
      final knownPlaces = <String, Place>{
        for (final p in attractionPlaces) p.name.trim().toLowerCase(): p,
        for (final p in [
          ...nearbyTraveler.attractions,
          ...nearbyTraveler.restaurants,
          ...nearbyTraveler.accommodations,
        ])
          p.name.trim().toLowerCase(): p,
        for (final list in accommodationsByAttraction.values)
          for (final p in list) p.name.trim().toLowerCase(): p,
      };
      final knownRestaurants = <String, Restaurant>{
        for (final r in restaurants) r.name.trim().toLowerCase(): r,
      };
      final knownBusinesses = <String, Business>{
        for (final b in businesses) b.name.trim().toLowerCase(): b,
      };

      if (mounted && parts.isNotEmpty) {
        setState(() {
          _realDataContext = parts.join(' ');
          _knownPlacesByName
            ..clear()
            ..addAll(knownPlaces);
          _knownRestaurantsByName
            ..clear()
            ..addAll(knownRestaurants);
          _knownBusinessesByName
            ..clear()
            ..addAll(knownBusinesses);
        });
      }
    } catch (_) {
      // Best-effort — chat still works fine with just profile-based context.
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  /// Keeps the system prompt (this context plus ~3000 chars of fixed
  /// instructions) safely under the server's per-message ceiling
  /// (`AI_MAX_MESSAGE_CHARS` in `functions/index.js`) even as the catalog
  /// this context is grounded in — featured destinations/restaurants,
  /// province guides — keeps growing over time.
  static const int _maxContextChars = 8000;

  String? _buildUserContext() {
    final user = context.read<AuthProvider>().currentUser;
    final parts = <String>[];
    if (user != null) {
      if (user.travelPreferences.isNotEmpty)
        parts.add('Travel preferences: ${user.travelPreferences.join(', ')}.');
      if (user.favoriteCategories.isNotEmpty)
        parts.add(
          'Favorite categories: ${user.favoriteCategories.join(', ')}.',
        );
    }
    if (_realDataContext != null) parts.add(_realDataContext!);
    if (parts.isEmpty) return null;
    final joined = parts.join(' ');
    return joined.length > _maxContextChars
        ? joined.substring(0, _maxContextChars)
        : joined;
  }

  /// Pre-emptive grounding for the FIRST message that establishes this
  /// conversation's destination — the common case where a traveler's very
  /// first ask ("plan a 2-day Baguio itinerary") gets Day 1 *and* Day 2
  /// back in one single reply, so grounding only *after* that reply (see
  /// [_groundDestinationContext]) would be too late to help match anything
  /// inside it. Skipped once a destination has already been grounded this
  /// session (`_groundedDestinationNames.isNotEmpty`) — both to avoid
  /// spending a second AI call on every single message (this app's
  /// `aiComplete` Cloud Function is rate-limited per hour) and because a
  /// follow-up in an already-grounded conversation is covered by
  /// [_groundDestinationContext] instead, for free (it reuses the reply
  /// that's already being generated rather than a separate call).
  ///
  /// Uses [AiRepository.extractDestination] — a small, isolated AI call —
  /// rather than a raw Places text search on the whole raw message; see
  /// that method's doc comment for why a raw-sentence search isn't reliable
  /// enough for this.
  Future<void> _groundFromUserMessage(String userMessage) async {
    if (_groundedDestinationNames.isNotEmpty) return;
    final destination = await _aiRepository.extractDestination(userMessage);
    if (destination == null || !mounted) return;
    await _groundPlace(destination);
  }

  /// Best-effort: once a reply states its destination on a leading
  /// `Destination: <place>, <province>` line (see
  /// [_extractStatedDestination]'s doc comment), resolves that exact string
  /// to a real place and folds real restaurants/attractions actually near
  /// it into [_realDataContext]/[_knownPlacesByName] — ready for the
  /// traveler's next message in this same conversation (a "what about day
  /// 2?" follow-up, a refinement, or eventually "Build Full Itinerary").
  /// Free — piggybacks on a reply that already exists, unlike
  /// [_groundFromUserMessage]'s own dedicated AI call.
  ///
  /// Without either of these, a destination-specific request was only ever
  /// grounded in [_loadRealDataContext]'s generic, nationwide "top
  /// attractions"/"popular restaurants" lists — which often don't cover the
  /// specific place being asked about. The reply would still name
  /// real-sounding local spots (the model's own general knowledge), but
  /// [_matchedKnownEntities] could never match them back to anything real,
  /// so "Build Full Itinerary" had no matching candidates to merge in (see
  /// [AiItineraryRequest.priorConversationEntities]) and the itinerary
  /// generator's own fresh Places search — correctly scoped, but blind to
  /// what the chat already said — picked different specific spots for the
  /// same slots.
  Future<void> _groundDestinationContext(String assistantReply) async {
    final statedDestination = _extractStatedDestination(assistantReply);
    if (statedDestination == null) return;
    await _groundPlace(statedDestination);
  }

  /// Shared core for [_groundFromUserMessage]/[_groundDestinationContext]:
  /// resolves [destinationQuery] — already a clean "City, Province"-shaped
  /// string from one of those two, never raw free text — to a real place,
  /// verifies the match against every ranked candidate (belt-and-suspenders;
  /// see [_resolveDestinationPlace]), then folds its real nearby
  /// restaurants/attractions into
  /// [_realDataContext]/[_knownPlacesByName].
  Future<void> _groundPlace(String destinationQuery) async {
    final key = destinationQuery.trim().toLowerCase();
    if (key.isEmpty || _groundedDestinationNames.contains(key)) return;
    try {
      final results = await _places.searchText(
        textQuery: '$destinationQuery, Philippines',
        maxResultCount: 10,
      );
      final resolved = _resolveDestinationPlace(destinationQuery, results);
      if (resolved == null) return;

      final nearby = await Future.wait([
        _places.searchNearby(
          latitude: resolved.latitude!,
          longitude: resolved.longitude!,
          includedTypes: PlaceCategory.dining,
          maxResultCount: 10,
        ),
        _places.searchNearby(
          latitude: resolved.latitude!,
          longitude: resolved.longitude!,
          includedTypes: PlaceCategory.attractions,
          maxResultCount: 10,
        ),
      ]);
      final restaurants = _recognizable(nearby[0]);
      final attractions = _recognizable(nearby[1]);
      if (restaurants.isEmpty && attractions.isEmpty) return;
      if (!mounted) return;

      final allPlaces = [...restaurants, ...attractions];
      final addition =
          'Real restaurants and attractions actually near ${resolved.name} (from live Google Places data) — '
          'the traveler is asking about this destination specifically, so prefer these by name over anything '
          'else when planning here, and keep using these same exact names for every day of this trip you '
          'discuss (never invent a place that isn\'t one of these or generally well-known): '
          '${allPlaces.map((p) => p.address.isNotEmpty ? '${p.name} (${p.address})' : p.name).join(', ')}.';

      setState(() {
        _groundedDestinationNames.add(key);
        _realDataContext = _realDataContext == null
            ? addition
            : '${_realDataContext!} $addition';
        for (final p in allPlaces) {
          _knownPlacesByName[p.name.trim().toLowerCase()] = p;
        }
      });
    } catch (_) {
      // Best-effort — the chat still works with whatever context it already
      // has; see the class-level doc comment on _realDataContext.
    }
  }

  /// Filler words common in both English and Taglish trip requests — never
  /// meaningful enough on their own to count as a real match between what
  /// the traveler typed and a resolved place's own name (see
  /// [_matchesDestinationName]'s guard).
  static const Set<String> _fillerWords = {
    'plan',
    'trip',
    'day',
    'days',
    'itinerary',
    'please',
    'pls',
    'for',
    'to',
    'of',
    'in',
    'with',
    'and',
    'the',
    'a',
    'an',
    'my',
    'me',
    'us',
    'we',
    'our',
    'want',
    'like',
    'need',
    'go',
    'going',
    'visit',
    'about',
    'ng',
    'sa',
    'yung',
    'yun',
    'ako',
    'kami',
    'namin',
    'mo',
    'ko',
    'na',
    'pa',
    'ba',
    'is',
    'gusto',
    'pwede',
    'pwedeng',
    'para',
    'trip.',
  };

  /// Used specifically when resolving the destination itself (never a supplementary nearby
  /// place): checking [Place.address] is too weak here, since literally
  /// every landmark *inside* Baguio has "Baguio" in its address — that
  /// alone would happily accept, say, "Lion's Head" as a match for a
  /// "Baguio" destination query, which is exactly the bug this replaces
  /// (a trip's cover/title naming a specific attraction that then never
  /// even shows up in its own day plan). Requires the candidate's own NAME
  /// to share a significant word with the queried place name instead.
  bool _matchesDestinationName(String queryPlaceName, Place place) {
    Set<String> significantWords(String text) => text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length >= 3 && !_fillerWords.contains(w))
        .toSet();
    final queryWords = significantWords(queryPlaceName);
    if (queryWords.isEmpty) return false;
    return queryWords.any(significantWords(place.name).contains);
  }

  /// Picks the first of [results] (a Places text-search response, which can
  /// return several ranked candidates) whose own name actually matches
  /// [destinationQuery] — see [_matchesDestinationName]. Only the part of
  /// [destinationQuery] before its first comma is checked (a "City,
  /// Province"-shaped query's province half would never appear in a city's
  /// own name). Null when nothing in [results] is really the queried place,
  /// rather than silently falling back to whatever Places ranked first.
  Place? _resolveDestinationPlace(
    String destinationQuery,
    List<Place> results,
  ) {
    final placeNamePart = destinationQuery.split(',').first.trim();
    for (final candidate in results) {
      if (candidate.hasCoordinates &&
          _matchesDestinationName(placeNamePart, candidate)) {
        return candidate;
      }
    }
    return null;
  }

  Future<void> _send(String text) async {
    final chat = context.read<AiChatProvider>();
    _scrollToBottom();
    // Awaited — this is the one that can actually change how the reply
    // about to be generated turns out (see _groundFromUserMessage's doc
    // comment for why it's worth the wait, and why it's skipped/instant
    // once a destination's already grounded this session).
    await _groundFromUserMessage(text);
    await chat.sendMessage(text, userContext: _buildUserContext());
    _scrollToBottom();
    // Best-effort, deliberately not awaited before the next thing the
    // traveler does — grounds *upcoming* turns in this conversation (see
    // _groundDestinationContext's doc comment), never blocks the reply that
    // already arrived.
    final messages = chat.messages;
    if (messages.isNotEmpty &&
        !messages.last.isUser &&
        !messages.last.isError) {
      unawaited(_groundDestinationContext(messages.last.content));
    }
  }

  Future<void> _confirmDeleteCurrentChat(AiChatProvider chat) async {
    final sessionId = chat.currentSessionId;
    if (sessionId == null) return;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete this chat?',
      message: 'This conversation will be permanently deleted.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    await chat.deleteSession(sessionId);
  }

  /// The nearest user turn before [assistantMessage] — normally the request
  /// that produced it (e.g. "Plan a 3-day trip to Baguio"), and specific
  /// enough to drive a Places text search for the destination itself, unlike
  /// searching on the assistant's whole multi-day reply.
  String? _precedingUserMessage(AiChatMessage assistantMessage) {
    final messages = context.read<AiChatProvider>().messages;
    final index = messages.indexOf(assistantMessage);
    for (var i = index - 1; i >= 0; i--) {
      if (messages[i].isUser) return messages[i].content;
    }
    return null;
  }

  /// The highest "Day N" found in the reply, clamped to the Planner form's
  /// own 1-14 day range — a reply with "Day 1"..."Day 3" means a 3-day plan.
  int _extractDays(String content) {
    final numbers = RegExp(
      r'day\s*(\d+)',
      caseSensitive: false,
    ).allMatches(content).map((m) => int.parse(m.group(1)!));
    if (numbers.isEmpty) return 3;
    return numbers
        .reduce((a, b) => a > b ? a : b)
        .clamp(minTripDays, maxTripDays);
  }

  int _extractBudgetTierIndex(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('luxury') ||
        lower.contains('high-end') ||
        lower.contains('splurge'))
      return 2;
    if (lower.contains('budget') ||
        lower.contains('cheap') ||
        lower.contains('affordable') ||
        lower.contains('shoestring'))
      return 0;
    return 1;
  }

  /// Null when the conversation never actually said who's traveling —
  /// [_generateFromChat] asks via [_askTravelerCount] instead of silently
  /// guessing a default that might not match what the traveler meant.
  (String type, int travelers)? _extractTravelerInfo(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('solo') ||
        lower.contains('by myself') ||
        lower.contains('alone'))
      return ('Solo', 1);
    if (lower.contains('family') ||
        lower.contains('kids') ||
        lower.contains('children'))
      return ('Family', 4);
    if (lower.contains('friends') || lower.contains('barkada'))
      return ('Friends', 4);
    if (lower.contains('couple') ||
        lower.contains('partner') ||
        lower.contains('honeymoon'))
      return ('Couple', 2);
    final travelerCount = RegExp(
      r'(\d+)\s*(?:travelers?|people|pax|persons?)',
    ).firstMatch(lower);
    if (travelerCount != null) {
      final count = int.parse(travelerCount.group(1)!).clamp(1, 15);
      return (count == 1 ? 'Solo' : 'Friends', count);
    }
    return null;
  }

  Future<(String, int)?> _askTravelerCount() {
    return showDialog<(String, int)>(
      context: context,
      builder: (_) => const _TravelerCountDialog(),
    );
  }

  /// A day-by-day reply states its exact destination on a leading
  /// `Destination: <place>, <province>` line (see
  /// `ChatPrompts.systemPrompt`'s formatting rules) — parsed here so
  /// [_generateFromChat] searches Places for the specific place the AI
  /// actually recommended, not just the traveler's own (often vaguer)
  /// original prompt, which used to risk resolving to an unrelated place
  /// entirely (e.g. "plan a relaxing beach trip" matching a random beach
  /// with no connection to what the AI actually suggested). Returns null
  /// for a reply saved before this line existed, so [_generateFromChat]
  /// falls back to its previous, still-correct-for-clear-prompts behavior.
  String? _extractStatedDestination(String content) {
    final match = RegExp(
      r'^Destination:\s*(.+)$',
      multiLine: true,
    ).firstMatch(content);
    final destination = match?.group(1)?.trim();
    return (destination == null || destination.isEmpty) ? null : destination;
  }

  /// The province half of a `<place>, <province>` stated destination (see
  /// [_extractStatedDestination]) — the part after the last comma, so a
  /// place name that itself contains a comma-free "City, Province" shape
  /// still yields just the province. Null when there's no stated
  /// destination, or it never named a province at all.
  String? _statedProvinceName(String? statedDestination) {
    if (statedDestination == null) return null;
    final lastComma = statedDestination.lastIndexOf(',');
    if (lastComma == -1) return null;
    final province = statedDestination.substring(lastComma + 1).trim();
    return province.isEmpty ? null : province;
  }

  /// Real places/restaurants/businesses the reply actually named — see
  /// [extractBoldNames]'s doc comment for how the names themselves are
  /// found; this just resolves each against [_knownPlacesByName]/
  /// [_knownRestaurantsByName]/[_knownBusinessesByName]. Used for the
  /// tappable-card row under a reply, where [extractBoldNames]' default
  /// 4-name cap is the right call — a wall of cards under every bubble
  /// would be worse UI than showing the first few.
  List<Object> _matchedKnownEntities(String content) {
    final matches = <Object>[];
    for (final name in extractBoldNames(content)) {
      final place = _knownPlacesByName[name];
      final restaurant = _knownRestaurantsByName[name];
      final business = _knownBusinessesByName[name];
      if (place != null) {
        matches.add(place);
      } else if (restaurant != null) {
        matches.add(restaurant);
      } else if (business != null) {
        matches.add(business);
      }
    }
    return matches;
  }

  Set<String> _extractInterests(String text) {
    final lower = text.toLowerCase();
    final interests = <String>{};
    if (lower.contains('beach')) interests.add('Beaches');
    if (lower.contains('mountain') || lower.contains('hik'))
      interests.add('Mountains');
    if (lower.contains('food') ||
        lower.contains('cuisine') ||
        lower.contains('restaurant'))
      interests.add('Food');
    if (lower.contains('culture') ||
        lower.contains('heritage') ||
        lower.contains('histor'))
      interests.add('Culture & Heritage');
    if (lower.contains('adventure')) interests.add('Adventure');
    if (lower.contains('festival')) interests.add('Festivals');
    if (lower.contains('nature') ||
        lower.contains('forest') ||
        lower.contains('wildlife'))
      interests.add('Nature');
    if (lower.contains('nightlife') ||
        lower.contains('bar') ||
        lower.contains('club'))
      interests.add('Nightlife');
    return interests.isEmpty ? {'Beaches', 'Food'} : interests;
  }

  /// Handles the "Build this in AI Planner" tap on a day-by-day chat reply:
  /// resolves a real destination + province from the conversation (the same
  /// Places-search-then-match-province building block "Plan a Trip Here"
  /// already uses on [PlaceDetailsSheet]), then calls the exact same
  /// [AiPlannerProvider.generate] the Planner form uses and lands straight
  /// on [GeneratedItineraryScreen] — no empty form for the traveler to
  /// re-fill. Falls back to opening the blank Planner form whenever the
  /// destination can't be confidently resolved, since fabricating a
  /// destinationId would risk generating the wrong trip entirely.
  /// Pops the "Crafting your itinerary..." dialog if it's still the
  /// top-most route. Guarded with a try/catch (rather than trusting
  /// `Navigator.canPop`, which reports the branch navigator's own history,
  /// not necessarily the dialog route pushed on the root navigator) so a
  /// double-pop can never throw out of an `await`-resuming callback and
  /// silently abort the fallback navigation/snackbar right after it — the
  /// exact way an earlier version of this could look like "nothing
  /// happened" when something upstream had already gone wrong.
  void _closeGeneratingDialog() {
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {
      // Already closed (or never opened) — nothing to undo.
    }
  }

  void _fallbackToPlanner(String reason) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
    context.go(RoutePaths.planner);
  }

  Future<void> _generateFromChat(AiChatMessage assistantMessage) async {
    final userPrompt = _precedingUserMessage(assistantMessage);
    if (userPrompt == null) {
      _fallbackToPlanner(
        'Couldn\'t find the original request — pick your destination below.',
      );
      return;
    }

    final combinedText = '$userPrompt ${assistantMessage.content}';

    // Ask for anything the conversation genuinely never mentioned (e.g. how
    // many travelers) instead of silently generating around a guessed
    // default — before any of the slower destination/generation work below,
    // same as filling in the Planner form would happen before generating.
    final travelerInfo =
        _extractTravelerInfo(combinedText) ?? await _askTravelerCount();
    if (!mounted) return;
    if (travelerInfo == null) {
      _fallbackToPlanner(
        'Fill in your trip details below to generate an itinerary.',
      );
      return;
    }
    final (travelerType, travelers) = travelerInfo;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(canPop: false, child: _GeneratingDialog()),
    );

    try {
      final statedDestination = _extractStatedDestination(
        assistantMessage.content,
      );
      final destinationQuery = statedDestination ?? userPrompt;
      final places = await _places.searchText(
        textQuery: '$destinationQuery, Philippines',
      );
      // Picks the first *actually name-matching* result rather than
      // blindly trusting Places' top-ranked one — a text search for a city
      // can rank a famous landmark inside it above the city itself (e.g.
      // "Baguio" resolving to "Lion's Head"), which used to make the whole
      // trip's title/cover/anchor a specific attraction that then never
      // even appears in its own day plan. See _resolveDestinationPlace.
      final place = _resolveDestinationPlace(destinationQuery, places);
      if (place == null) {
        if (!mounted) return;
        _closeGeneratingDialog();
        _fallbackToPlanner(
          'Couldn\'t pin down that destination — pick it below instead.',
        );
        return;
      }

      final provinces = await ProvinceRepository().getAll();
      final province = matchProvinceByAddress(place.address, provinces);
      if (province == null) {
        if (!mounted) return;
        _closeGeneratingDialog();
        _fallbackToPlanner(
          'Couldn\'t match "${place.name}" to a province — pick your destination below.',
        );
        return;
      }

      // The AI states its province alongside the place name (e.g. "El Nido,
      // Palawan"), but the Places search above can still resolve to a
      // same-named place in a different one (there's more than one "San
      // Fernando" in the Philippines) — Places picks the top result by
      // relevance, not by matching that stated province. Silently
      // generating for whichever province Places happened to return would
      // build a trip for a place the traveler never actually discussed, so
      // a mismatch here falls back instead of guessing.
      final statedProvince = _statedProvinceName(statedDestination);
      if (statedProvince != null &&
          !province.name.toLowerCase().contains(statedProvince.toLowerCase()) &&
          !statedProvince.toLowerCase().contains(province.name.toLowerCase())) {
        if (!mounted) return;
        _closeGeneratingDialog();
        _fallbackToPlanner(
          'Found "${place.name}" in ${province.name}, not $statedProvince as discussed — pick your destination below to be sure.',
        );
        return;
      }

      if (!mounted) return;
      final tier = budgetTiers[_extractBudgetTierIndex(combinedText)];

      final planner = context.read<AiPlannerProvider>();
      final itinerary = await planner.generate(
        AiItineraryRequest(
          destinationId: place.id,
          destinationName: place.name,
          provinceId: province.id,
          provinceName: province.name,
          budgetTierLabel: tier.label,
          budgetRange: tier.range,
          days: _extractDays(assistantMessage.content),
          travelers: travelers,
          travelerType: travelerType,
          transportation: const {defaultTransportation},
          interests: _extractInterests(combinedText),
          latitude: place.latitude,
          longitude: place.longitude,
          priorConversationContext: assistantMessage.content,
          priorConversationEntities: _matchedKnownEntities(
            assistantMessage.content,
          ),
        ),
        coverImageUrl: place.photoNames.isNotEmpty
            ? _places.photoUrl(place.photoNames.first)
            : province.heroImageUrl,
      );

      if (!mounted) return;
      _closeGeneratingDialog();

      if (itinerary != null) {
        context.push(
          RoutePaths.generatedItinerary,
          extra: {'itinerary': itinerary},
        );
      } else {
        _fallbackToPlanner(
          planner.errorMessage ??
              'Couldn\'t generate your itinerary. Please try again.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('AI Chat → Planner generation failed: $e\n$stackTrace');
      if (!mounted) return;
      _closeGeneratingDialog();
      _fallbackToPlanner(
        'Something went wrong generating that itinerary. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<AiChatProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('AI Travel Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Symbols.forum_rounded),
            tooltip: 'Chats',
            onPressed: () => showChatSessionsSheet(context),
          ),
          if (chat.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Symbols.delete_outline_rounded),
              tooltip: 'Delete this chat',
              onPressed: () => _confirmDeleteCurrentChat(chat),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chat.messages.isEmpty
                ? _EmptyState(onSuggestionTap: _send)
                : MaxWidthContainer(
                    maxWidth: 900,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount:
                          chat.messages.length + (chat.isSending ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == chat.messages.length)
                          return const TypingIndicator();
                        final message = chat.messages[i];
                        final matches = message.isUser || message.isError
                            ? const <Object>[]
                            : _matchedKnownEntities(message.content);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ChatBubble(
                              message: message,
                              onOpenPlanner: () => _generateFromChat(message),
                            ),
                            if (matches.isNotEmpty)
                              _ChatEntityCardsRow(
                                entities: matches,
                                places: _places,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
          if (chat.messages.isNotEmpty)
            MaxWidthContainer(
              maxWidth: 900,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      const quickFollowUps = [
                        'Estimate my budget',
                        'Any hidden gems?',
                        'Safety tips',
                      ];
                      return SuggestionPill(
                        label: quickFollowUps[i],
                        onTap: chat.isSending
                            ? null
                            : () => _send(quickFollowUps[i]),
                      );
                    },
                  ),
                ),
              ),
            ),
          MaxWidthContainer(
            maxWidth: 900,
            child: ChatInputBar(onSend: _send, enabled: !chat.isSending),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSuggestionTap});

  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          const AppLogo(size: 88),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Hi, I\'m your TripNest PH travel assistant!',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ask me to plan a trip, find hidden gems, estimate a budget, or recommend food — anywhere in the Philippines.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Try asking', style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: AppSpacing.sm),
          PromptSuggestionChips(onSelected: onSuggestionTap),
        ],
      ),
    );
  }
}

/// Blocking modal shown while [_AiChatScreenState._generateFromChat] resolves
/// a destination and calls the same (slow: Firestore + Places + weather +
/// JSON-mode LLM) generation flow the Planner form's "Generate Itinerary"
/// button runs — without this, the chat would look frozen for several
/// seconds with no typing indicator to explain why. Cycles through what's
/// actually happening behind the scenes (place matching, geocoding, budget
/// estimation) rather than a single static caption the whole time, so a
/// several-second wait reads as real progress instead of a stuck spinner.
class _GeneratingDialog extends StatefulWidget {
  const _GeneratingDialog();

  @override
  State<_GeneratingDialog> createState() => _GeneratingDialogState();
}

class _GeneratingDialogState extends State<_GeneratingDialog> {
  static const _steps = [
    'Matching the places from your chat...',
    'Pinning exact locations on the map...',
    'Estimating your trip budget...',
    'Putting the final plan together...',
  ];

  int _stepIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (!mounted) return;
      setState(() => _stepIndex = (_stepIndex + 1) % _steps.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradient([
                      colorScheme.primary,
                      colorScheme.primaryFixedDim,
                    ]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Symbols.auto_awesome_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.08, 1.08),
                  duration: 900.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Crafting your itinerary',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: 18,
              child: AnimatedSwitcher(
                duration: 350.ms,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.35),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  _steps[_stepIndex],
                  key: ValueKey(_stepIndex),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                width: 160,
                height: 4,
                child: LinearProgressIndicator(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontal row of real place/restaurant cards under an assistant
/// reply — see [_AiChatScreenState._matchedKnownEntities]'s doc comment.
/// Each [entities] item is either a [Place] or a [Restaurant]; anything
/// else is a programming error in that matcher, not a case to design
/// around here.
class _ChatEntityCardsRow extends StatelessWidget {
  const _ChatEntityCardsRow({required this.entities, required this.places});

  final List<Object> entities;
  final PlacesService places;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SizedBox(
        height: 190,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: entities.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, i) {
            final entity = entities[i];
            return switch (entity) {
              Place place => PlaceCard(
                place: place,
                width: 160,
                imageHeight: 100,
                imageUrl: place.photoNames.isNotEmpty
                    ? places.photoUrl(place.photoNames.first)
                    : '',
                onTap: () => showPlaceDetailsSheet(
                  context,
                  place: place,
                  placesService: places,
                ),
              ),
              Restaurant restaurant => RestaurantCard(
                restaurant: restaurant,
                width: 160,
                imageHeight: 100,
                onTap: () =>
                    context.push(RoutePaths.restaurantDetails(restaurant.id)),
              ),
              Business business => BusinessCard(
                business: business,
                width: 160,
                imageHeight: 100,
                onTap: () => showBusinessInfoSheet(context, business),
              ),
              Object() => const SizedBox.shrink(),
            };
          },
        ),
      ),
    );
  }
}

/// Asks who's traveling when [AiChatScreen._extractTravelerInfo] couldn't
/// tell from the conversation — mirrors the traveler-type chips + count
/// stepper on the Planner form (`_travelerTypeOptions`/`_travelerRangeFor`
/// in `AiPlannerScreen`), just condensed into a single dialog since this is
/// the one field the chat generation flow needs but can't confidently infer.
class _TravelerCountDialog extends StatefulWidget {
  const _TravelerCountDialog();

  @override
  State<_TravelerCountDialog> createState() => _TravelerCountDialogState();
}

class _TravelerCountDialogState extends State<_TravelerCountDialog> {
  static const List<(String label, IconData icon, int min, int max)> _options =
      [
        ('Solo', Symbols.person_rounded, 1, 1),
        ('Couple', Symbols.favorite_rounded, 2, 2),
        ('Family', Symbols.family_restroom_rounded, 2, 15),
        ('Friends', Symbols.groups_rounded, 2, 15),
      ];

  String _type = 'Couple';
  int _count = 2;

  (int, int) get _range {
    final option = _options.firstWhere(
      (o) => o.$1 == _type,
      orElse: () => _options[1],
    );
    return (option.$3, option.$4);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (min, max) = _range;
    return AlertDialog(
      // Scrolls on a short viewport (landscape, keyboard open) instead of overflowing.
      scrollable: true,
      title: const Text('Who\'s traveling?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You didn\'t mention this in the chat — pick one so the itinerary fits your group.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _options.map((option) {
              final (label, icon, optMin, optMax) = option;
              final selected = _type == label;
              return ChoiceChip(
                label: Text(label),
                avatar: Icon(icon, size: 16),
                selected: selected,
                onSelected: (_) => setState(() {
                  _type = label;
                  _count = _count.clamp(optMin, optMax);
                }),
              );
            }).toList(),
          ),
          if (min != max) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_count ${_count == 1 ? 'traveler' : 'travelers'}',
                  style: theme.textTheme.titleMedium,
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Symbols.remove_circle_outline_rounded),
                      onPressed: _count > min
                          ? () => setState(() => _count--)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Symbols.add_circle_outline_rounded),
                      onPressed: _count < max
                          ? () => setState(() => _count++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((_type, _count)),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
