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
  });

  /// The matched activity's `time`, e.g. "Morning".
  final String time;
  final String name;
  final double latitude;
  final double longitude;

  /// Set when [name] matched a real `Destination` — mutually exclusive
  /// with [restaurantId].
  final String? destinationId;

  /// Set when [name] matched a real `Restaurant` — mutually exclusive
  /// with [destinationId].
  final String? restaurantId;
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
/// [mainDestinationName]/[mainDestinationLatitude]/[mainDestinationLongitude]
/// (and its id, [mainDestinationId], for tap-to-navigate) represent the
/// trip's own destination — checked last, since it's by far the most common
/// thing a day's activities describe ("Explore Kawasan Falls", "Canyoneering
/// at Kawasan Falls", ...), but [destinations] never includes it (that list
/// is "other nearby attractions", deliberately excluding the destination
/// itself elsewhere in the app).
///
/// Returned in activity order (Morning/Afternoon/Evening), so callers can
/// use this list directly for both markers and a connecting route line.
List<RouteStop> matchDayToRoute(
  ItineraryDay day, {
  required List<Restaurant> restaurants,
  required List<Destination> destinations,
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
