import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/itinerary.dart';
import '../../domain/models/restaurant.dart';
import 'local_preferences_service.dart';

/// Makes a saved trip deterministically usable with no connectivity —
/// beyond Firestore's own incidental offline cache (see
/// `LocalPreferencesService.getOfflineItineraryIds` for why that's not
/// enough on its own): warms the Firestore cache for every restaurant/
/// destination the itinerary references (the same `getByIds` calls
/// `GeneratedItineraryScreen` already makes at view time, which otherwise
/// silently fail offline the first time they run) and precaches every
/// photo the itinerary screen shows.
class ItineraryOfflineService {
  ItineraryOfflineService({
    RestaurantRepository? restaurantRepository,
    DestinationRepository? destinationRepository,
    LocalPreferencesService? preferencesService,
  })  : _restaurantRepository = restaurantRepository ?? RestaurantRepository(),
        _destinationRepository = destinationRepository ?? DestinationRepository(),
        _preferencesService = preferencesService ?? LocalPreferencesService();

  final RestaurantRepository _restaurantRepository;
  final DestinationRepository _destinationRepository;
  final LocalPreferencesService _preferencesService;

  /// Every non-empty, deduplicated photo URL relevant to [itinerary] —
  /// the cover image plus every recommendation/restaurant/destination photo
  /// its screens render.
  List<String> imageUrlsFor(Itinerary itinerary, List<Restaurant> restaurants, List<Destination> destinations) {
    final urls = <String>{
      itinerary.coverImageUrl,
      ...itinerary.recommendedAccommodations.map((p) => p.photoUrl),
      ...itinerary.recommendedPlaceAttractions.map((p) => p.photoUrl),
      ...restaurants.map((r) => r.heroImageUrl),
      ...destinations.map((d) => d.heroImageUrl),
    }..removeWhere((url) => url.isEmpty);
    return urls.toList();
  }

  /// Warms Firestore's cache and precaches photos so [itineraryId] opens
  /// fully offline afterwards, then marks it as such. Each image is
  /// precached independently — one broken URL doesn't abort the rest.
  Future<void> makeAvailableOffline({
    required BuildContext context,
    required String itineraryId,
    required Itinerary itinerary,
  }) async {
    final restaurants = await _restaurantRepository.getByIds(itinerary.recommendedRestaurantIds);
    final destinations = await _destinationRepository.getByIds(itinerary.nearbyAttractionIds);

    for (final url in imageUrlsFor(itinerary, restaurants, destinations)) {
      if (!context.mounted) break;
      try {
        await precacheImage(CachedNetworkImageProvider(url), context);
      } catch (_) {
        // Best-effort: a single unreachable/broken photo shouldn't block the
        // rest of the trip from being marked available offline.
      }
    }

    await _preferencesService.setItineraryAvailableOffline(itineraryId, true);
  }
}
