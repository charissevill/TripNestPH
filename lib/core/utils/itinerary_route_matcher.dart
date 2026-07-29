import '../../domain/models/destination.dart';
import '../../domain/models/itinerary.dart';
import '../../domain/models/restaurant.dart';

/// One of a day's activities, resolved to a real, coordinate-bearing place —
/// never invented. See [matchDayToRoute] for how the match is made.
class RouteStop {
  const RouteStop({
    required this.time,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.destinationId,
    this.restaurantId,
    this.placeMapsUri,
  });

  /// The matched activity's `time`, e.g. "Morning".
  final String time;
  final String name;
  final double latitude;
  final double longitude;

  /// Set when [name] matched a real `Destination` — mutually exclusive
  /// with [restaurantId]/[placeMapsUri].
  final String? destinationId;

  /// Set when [name] matched a real `Restaurant` — mutually exclusive
  /// with [destinationId]/[placeMapsUri].
  final String? restaurantId;

  /// Set when [name] matched a live Places API recommendation
  /// (`Itinerary.recommendedAccommodations`/`recommendedPlaceAttractions`) —
  /// those have no Firestore id to navigate to in-app, so callers should
  /// open this real Google Maps link instead. Mutually exclusive with
  /// [destinationId]/[restaurantId].
  final String? placeMapsUri;
}

/// Names shorter than this are skipped when matching — a name that short
/// (e.g. "Spa") would match almost any activity text and produce a
/// meaningless/misleading pin.
const int _minMatchableNameLength = 4;

/// Resolves [day]'s activities against [restaurants]/[destinations] — both
/// already-loaded, real Firestore data with real coordinates — by checking
/// whether an activity's title/location/description text contains one of
/// their names. Description is included because the AI often names the
/// specific place there (e.g. "Visit Magellan's Cross and Basilica del
/// Santo Niño") rather than in the shorter title/location fields.
/// Deliberately never asks an AI model for coordinates directly: an LLM
/// inventing lat/lng for a "specific place name" it wrote itself is a
/// hallucination risk, and a wrong pin is worse than no pin. Restaurants are
/// checked before destinations, since "Lunch/Dinner at X" activities are
/// common and should resolve to the restaurant, not a same-named attraction.
///
/// [placeRecommendations] covers `Itinerary.recommendedAccommodations`/
/// `recommendedPlaceAttractions` — live Places API picks with no Firestore
/// id, checked after [restaurants]/[destinations] but before the main
/// destination (they're just as specific as a curated destination, unlike
/// the broader main-destination fallback).
///
/// An activity with its own [ItineraryActivity.latitude]/`longitude` —
/// resolved once at generation time by geocoding its stated location via a
/// live Places search (see `AiRepository._geocodeActivities`) — is checked
/// next, after the curated lists but before the main-destination fallback:
/// this catches real places that were never in any pre-fetched candidate
/// list (a beach, say — Places has no dedicated "beach" type, so one never
/// appears in [placeRecommendations]).
///
/// [mainDestinationName]/[mainDestinationLatitude]/[mainDestinationLongitude]
/// (and its id, [mainDestinationId], for tap-to-navigate) represent the
/// trip's own destination — checked last, since it's by far the most common
/// thing a day's activities describe ("Explore Kawasan Falls", "Canyoneering
/// at Kawasan Falls", ...), but [destinations] never includes it (that list
/// is "other nearby attractions", deliberately excluding the destination
/// itself elsewhere in the app).
///
/// Returned in activity order (Morning/Afternoon/Evening). If fewer than 2
/// activities resolve this way — a day of generic activities like "Beach
/// Relaxation"/"Farewell Dinner" with no specific real place named anywhere
/// — a trailing anchor stop for the trip's own destination is appended
/// (when its coordinates are available), so every day still centers on
/// somewhere real instead of showing nothing. This never fabricates a
/// specific activity's location — it's just the one thing genuinely true of
/// every activity in a destination-based trip: it happens in/around there.
List<RouteStop> matchDayToRoute(
  ItineraryDay day, {
  required List<Restaurant> restaurants,
  required List<Destination> destinations,
  List<PlaceRecommendation> placeRecommendations = const [],
  String? mainDestinationId,
  String? mainDestinationName,
  double? mainDestinationLatitude,
  double? mainDestinationLongitude,
}) {
  final stops = <RouteStop>[];
  for (final activity in day.activities) {
    final haystack = '${activity.title} ${activity.location} ${activity.description}'.toLowerCase();

    final restaurant = _firstMatch(haystack, restaurants, (r) => r.name, (r) => r.hasCoordinates);
    if (restaurant != null) {
      stops.add(
        RouteStop(
          time: activity.time,
          name: restaurant.name,
          latitude: restaurant.latitude!,
          longitude: restaurant.longitude!,
          restaurantId: restaurant.id,
        ),
      );
      continue;
    }

    final destination = _firstMatch(haystack, destinations, (d) => d.name, (d) => d.hasCoordinates);
    if (destination != null) {
      stops.add(
        RouteStop(
          time: activity.time,
          name: destination.name,
          latitude: destination.latitude!,
          longitude: destination.longitude!,
          destinationId: destination.id,
        ),
      );
      continue;
    }

    final place = _firstMatch(haystack, placeRecommendations, (p) => p.name, (p) => p.hasCoordinates);
    if (place != null) {
      stops.add(
        RouteStop(
          time: activity.time,
          name: place.name,
          latitude: place.latitude!,
          longitude: place.longitude!,
          placeMapsUri: place.mapsUri.isEmpty ? null : place.mapsUri,
        ),
      );
      continue;
    }

    if (activity.latitude != null && activity.longitude != null) {
      stops.add(
        RouteStop(time: activity.time, name: activity.title, latitude: activity.latitude!, longitude: activity.longitude!),
      );
      continue;
    }

    if (mainDestinationName != null &&
        mainDestinationName.length >= _minMatchableNameLength &&
        mainDestinationLatitude != null &&
        mainDestinationLongitude != null &&
        haystack.contains(mainDestinationName.toLowerCase())) {
      stops.add(
        RouteStop(
          time: activity.time,
          name: mainDestinationName,
          latitude: mainDestinationLatitude,
          longitude: mainDestinationLongitude,
          destinationId: mainDestinationId,
        ),
      );
    }
  }

  final alreadyAnchored = stops.any((s) => s.destinationId != null && s.destinationId == mainDestinationId);
  if (stops.length < 2 &&
      !alreadyAnchored &&
      mainDestinationName != null &&
      mainDestinationLatitude != null &&
      mainDestinationLongitude != null) {
    stops.add(
      RouteStop(
        time: 'Overview',
        name: mainDestinationName,
        latitude: mainDestinationLatitude,
        longitude: mainDestinationLongitude,
        destinationId: mainDestinationId,
      ),
    );
  }
  return stops;
}

T? _firstMatch<T>(String haystack, List<T> candidates, String Function(T) nameOf, bool Function(T) hasCoordinates) {
  for (final candidate in candidates) {
    final name = nameOf(candidate);
    if (name.length < _minMatchableNameLength) continue;
    if (hasCoordinates(candidate) && haystack.contains(name.toLowerCase())) return candidate;
  }
  return null;
}
