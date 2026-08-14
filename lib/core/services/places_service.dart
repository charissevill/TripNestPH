import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/models/place.dart';
import '../utils/function_caller.dart';
import 'places_cache_service.dart';

/// Curated Places API (New) `includedTypes` per category this app surfaces.
/// 'beach' has no dedicated Places type, so it's handled via [PlacesService.searchText]
/// by callers instead of appearing here.
class PlaceCategory {
  PlaceCategory._();

  static const attractions = ['tourist_attraction', 'historical_landmark', 'museum', 'park'];
  static const lodging = ['lodging'];
  static const dining = ['restaurant', 'cafe'];
  static const shopping = ['shopping_mall'];
  static const gasStations = ['gas_station'];
  static const pharmacies = ['pharmacy'];
  static const hospitals = ['hospital'];
  static const atms = ['atm'];
  static const transportTerminals = ['bus_station', 'train_station', 'airport'];
}

/// Thin wrapper around the `placesSearchNearby`/`placesSearchText`/
/// `placesPhoto` Cloud Functions, which themselves proxy Places API (New) —
/// the live source for hotels, restaurants, attractions and other nearby
/// businesses throughout the app, replacing hand-storing this kind of data
/// in Firestore.
///
/// Deliberately routed through Cloud Functions rather than calling Google
/// directly from the client: `flutter_dotenv` loads `.env` as a plain app
/// asset, so a client-embedded `GOOGLE_PLACES_API_KEY` would ship inside
/// the APK/web build in cleartext. The Cloud Functions hold the real key in
/// Secret Manager instead (see `functions/index.js`).
///
/// Best-effort by design (same reasoning as `WeatherService`): a Places
/// lookup is always a supplementary UI section, never something worth
/// failing a page load or itinerary generation over, so every failure mode
/// returns an empty list rather than throwing.
class PlacesService {
  PlacesService({FirebaseFunctions? functions, FunctionCaller? caller, PlacesCacheService? cache})
      : _call = caller ?? firebaseFunctionCaller(functions),
        _cache = cache ?? PlacesCacheService();

  final FunctionCaller _call;
  final PlacesCacheService _cache;

  static const String _photoBaseUrl = 'https://asia-southeast1-tripnest-ph.cloudfunctions.net/placesPhoto';

  /// Rounds a coordinate to ~111m of precision for cache-key purposes only
  /// (never for the actual API call, which keeps full GPS precision).
  /// `Geolocator.getCurrentPosition` returns a slightly different reading
  /// almost every call, so keying the 24h cache off raw full-precision
  /// lat/lng meant a stationary traveler refreshing seconds apart almost
  /// never hit the cache at all — this coarsens the key well under a 5km+
  /// search radius, where that much drift can't meaningfully change results.
  static double _roundForCacheKey(double coordinate) => (coordinate * 1000).round() / 1000;

  /// Live nearby businesses around a known point (a destination's stored
  /// coordinates, for example) — use [searchText] instead when there's no
  /// single coordinate to search around (e.g. a whole province).
  Future<List<Place>> searchNearby({
    required double latitude,
    required double longitude,
    required List<String> includedTypes,
    double radiusMeters = 5000,
    int maxResultCount = 20,
    // See searchText's doc for what this changes.
    bool rethrowOnError = false,
  }) async {
    final sortedTypes = [...includedTypes]..sort();
    final signature =
        'nearby|${_roundForCacheKey(latitude)}|${_roundForCacheKey(longitude)}|${sortedTypes.join(',')}|$radiusMeters';

    final cached = await _cache.get(signature);
    if (cached != null) return cached;

    try {
      final result = await _call('placesSearchNearby', {
        'latitude': latitude,
        'longitude': longitude,
        'includedTypes': includedTypes,
        'radiusMeters': radiusMeters,
        'maxResultCount': maxResultCount,
      });
      final places = _parsePlaces(result)
          .map((p) => p.copyWithDistanceFrom(latitude: latitude, longitude: longitude))
          .toList();
      await _cache.set(signature, places);
      return places;
    } catch (_) {
      if (rethrowOnError) rethrow;
      return const [];
    }
  }

  /// Text-query search, e.g. "hotels in Palawan, Philippines" — lets Google
  /// resolve the location itself, so it works for areas (provinces) that
  /// don't have a single stored coordinate. Optionally biased toward a
  /// point ([biasLatitude]/[biasLongitude]) without requiring one — used
  /// for categories with no dedicated Places type (e.g. beaches) on a
  /// destination page that *does* have coordinates on file.
  Future<List<Place>> searchText({
    required String textQuery,
    int maxResultCount = 20,
    double? biasLatitude,
    double? biasLongitude,
    double biasRadiusMeters = 15000,
    // Every failure (network, rate limit, quota) is otherwise swallowed
    // into an empty list — fine for a purely supplementary caller, but a
    // screen with its own error+Retry UI (Explore's Destinations tab,
    // NearbyPlacesScreen) needs to actually see a real outage instead of it
    // rendering identically to "zero results" with no way to retry.
    bool rethrowOnError = false,
  }) async {
    final roundedBiasLat = biasLatitude == null ? null : _roundForCacheKey(biasLatitude);
    final roundedBiasLng = biasLongitude == null ? null : _roundForCacheKey(biasLongitude);
    final signature = 'text|$textQuery|$maxResultCount|$roundedBiasLat|$roundedBiasLng';

    final cached = await _cache.get(signature);
    if (cached != null) return cached;

    try {
      final result = await _call('placesSearchText', {
        'textQuery': textQuery,
        'maxResultCount': maxResultCount,
        if (biasLatitude != null) 'biasLatitude': biasLatitude,
        if (biasLongitude != null) 'biasLongitude': biasLongitude,
        'biasRadiusMeters': biasRadiusMeters,
      });
      var places = _parsePlaces(result);
      if (biasLatitude != null && biasLongitude != null) {
        places = places.map((p) => p.copyWithDistanceFrom(latitude: biasLatitude, longitude: biasLongitude)).toList();
      }
      await _cache.set(signature, places);
      return places;
    } catch (_) {
      if (rethrowOnError) rethrow;
      return const [];
    }
  }

  /// Builds a displayable image URL from a `Place.photoNames` entry — routed
  /// through the `placesPhoto` Cloud Function rather than Google's media
  /// endpoint directly, so the raw API key never has to appear in a URL
  /// handed to `CachedNetworkImage`.
  String photoUrl(String photoName, {int maxWidthPx = 800}) {
    return '$_photoBaseUrl?photoName=${Uri.encodeQueryComponent(photoName)}&maxWidthPx=$maxWidthPx';
  }

  List<Place> _parsePlaces(Map<String, dynamic> data) {
    final places = data['places'] as List? ?? const [];
    return places.map((p) => Place.fromJson(Map<String, dynamic>.from(p as Map))).toList();
  }
}
