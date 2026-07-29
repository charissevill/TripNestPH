import '../../domain/models/destination.dart';
import '../../domain/models/place.dart';
import '../../domain/models/restaurant.dart';
import 'geo_distance.dart';

/// A photo's GPS coordinate resolved to a real, already-known place — see
/// [matchPhotoToPlace] for how the match is made. Never fabricated: every
/// field traces back to a real Firestore restaurant/destination or a real
/// live Google Places result.
class PhotoPlaceMatch {
  const PhotoPlaceMatch({
    required this.name,
    required this.tier,
    this.destinationId,
    this.restaurantId,
    this.placeId,
  });

  final String name;

  /// `'curated'` (a real Firestore restaurant/destination) or `'live'` (a
  /// real Google Places result) — lets the UI decide whether tapping the
  /// photo should open an in-app details page or `showPlaceDetailsSheet`.
  final String tier;

  /// Set only when [tier] is `'curated'` — mutually exclusive with
  /// [restaurantId]/[placeId].
  final String? destinationId;
  final String? restaurantId;

  /// Set only when [tier] is `'live'`.
  final String? placeId;
}

/// A place closer than this is considered "too far to confidently be the
/// same spot" — a photo's GPS fix has its own margin of error, but beyond
/// ~150m the risk of tagging the wrong nearby business/attraction outweighs
/// the convenience of an auto-tag.
const double _defaultMatchRadiusKm = 0.15;

/// Resolves a photo's GPS coordinate ([latitude]/[longitude]) to a real
/// place, mirroring `itinerary_route_matcher.dart`'s tiered, never-fabricate
/// shape: the nearest already-curated Firestore restaurant/destination
/// within [radiusKm] wins first (restaurants checked before destinations,
/// same "Lunch at X" precedence reasoning as `matchDayToRoute`), then the
/// nearest live Google Places result ([nearbyPlaces]) within the same
/// radius, else `null` — never a fabricated or low-confidence guess.
///
/// [destinations]/[restaurants] are expected to already be real,
/// coordinate-bearing candidates from a call to each repository's
/// `getNearbyLatitudeBand` (the same "Nearby You" fetch this codebase
/// already uses for "find real places near a point"). [nearbyPlaces] comes
/// from `PlacesService.searchNearby` at the same coordinate.
PhotoPlaceMatch? matchPhotoToPlace(
  double latitude,
  double longitude, {
  required List<Destination> destinations,
  required List<Restaurant> restaurants,
  List<Place> nearbyPlaces = const [],
  double radiusKm = _defaultMatchRadiusKm,
}) {
  final nearestRestaurant = _nearest(
    restaurants,
    latitude,
    longitude,
    radiusKm,
    hasCoordinates: (r) => r.hasCoordinates,
    latOf: (r) => r.latitude!,
    lngOf: (r) => r.longitude!,
  );
  if (nearestRestaurant != null) {
    return PhotoPlaceMatch(name: nearestRestaurant.name, tier: 'curated', restaurantId: nearestRestaurant.id);
  }

  final nearestDestination = _nearest(
    destinations,
    latitude,
    longitude,
    radiusKm,
    hasCoordinates: (d) => d.hasCoordinates,
    latOf: (d) => d.latitude!,
    lngOf: (d) => d.longitude!,
  );
  if (nearestDestination != null) {
    return PhotoPlaceMatch(name: nearestDestination.name, tier: 'curated', destinationId: nearestDestination.id);
  }

  final nearestPlace = _nearest(
    nearbyPlaces,
    latitude,
    longitude,
    radiusKm,
    hasCoordinates: (p) => p.hasCoordinates,
    latOf: (p) => p.latitude!,
    lngOf: (p) => p.longitude!,
  );
  if (nearestPlace != null) {
    return PhotoPlaceMatch(name: nearestPlace.name, tier: 'live', placeId: nearestPlace.id);
  }

  return null;
}

T? _nearest<T>(
  List<T> candidates,
  double latitude,
  double longitude,
  double radiusKm, {
  required bool Function(T) hasCoordinates,
  required double Function(T) latOf,
  required double Function(T) lngOf,
}) {
  T? closest;
  var closestKm = double.infinity;
  for (final candidate in candidates) {
    if (!hasCoordinates(candidate)) continue;
    final distanceKm = haversineKm(latitude, longitude, latOf(candidate), lngOf(candidate));
    if (distanceKm <= radiusKm && distanceKm < closestKm) {
      closest = candidate;
      closestKm = distanceKm;
    }
  }
  return closest;
}
