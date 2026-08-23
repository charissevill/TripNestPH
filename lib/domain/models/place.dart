import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A single result from the Google Places API (New) — live business/POI
/// data, never persisted to Firestore. Cached locally with a TTL (see
/// `PlacesCacheService`) and, for AI-recommended accommodations, snapshotted
/// into the lightweight `PlaceRecommendation` instead of stored as-is (see
/// `itinerary.dart`).
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.types,
    this.photoNames = const [],
    this.rating,
    this.userRatingCount,
    this.address = '',
    this.phoneNumber = '',
    this.websiteUri = '',
    this.priceLevel,
    this.isOpenNow,
    this.latitude,
    this.longitude,
    this.distanceMeters,
    this.googleMapsUri = '',
    this.weekdayDescriptions = const [],
    this.editorialSummary = '',
  });

  final String id;
  final String name;

  /// Raw Places API type strings (e.g. 'lodging', 'restaurant') — used to
  /// derive [categoryLabel] and for category-filter matching.
  final List<String> types;

  /// `photos[].name` values from the API response — pass to
  /// `PlacesService.photoUrl` to build an actual image URL on demand,
  /// rather than storing resolved URLs (the API key would need to be baked
  /// into a stored URL otherwise).
  final List<String> photoNames;

  final double? rating;
  final int? userRatingCount;
  final String address;
  final String phoneNumber;
  final String websiteUri;

  /// 0 (free) - 4 (very expensive), matching Places API's `priceLevel`
  /// enum ordinal; null when the place doesn't report one.
  final int? priceLevel;
  final bool? isOpenNow;
  final double? latitude;
  final double? longitude;

  /// Straight-line distance from the query origin, set by whichever
  /// `PlacesService` call produced this result — null for text searches
  /// with no origin point.
  final double? distanceMeters;

  /// A real Google-resolved place page — preferred over building a search
  /// URL from [latitude]/[longitude] when present (see `MapsLauncher`).
  final String googleMapsUri;

  /// Pre-formatted weekly hours, one line per day (e.g. "Monday: 9:00 AM –
  /// 5:00 PM"), distinct from [isOpenNow]'s live right-now boolean.
  final List<String> weekdayDescriptions;

  /// A short Google-authored description, when available.
  final String editorialSummary;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// A human-readable category label derived from the highest-priority
  /// recognized type present in [types], e.g. 'lodging' -> 'Hotel'. Falls
  /// back to the raw first type string (title-cased) for anything not in
  /// the curated map.
  ///
  /// Walks [_typeLabels] in *our* priority order rather than [types] in
  /// whatever order Google returned them — Places API has no dedicated
  /// "heritage site" type, so a UNESCO landscape like the Banaue/Batad Rice
  /// Terraces can come back tagged both 'tourist_attraction' and 'museum',
  /// sometimes with 'museum' listed first. Trusting that order mislabeled a
  /// rice terrace as a "Museum"; our map already lists the more generic
  /// landmark/outdoor types before 'museum', so iterating it instead picks
  /// those first whenever both are present.
  String get categoryLabel {
    for (final entry in _typeLabels.entries) {
      if (types.contains(entry.key)) return entry.value;
    }
    if (types.isEmpty) return 'Place';
    final raw = types.first.replaceAll('_', ' ');
    return raw.isEmpty ? 'Place' : raw[0].toUpperCase() + raw.substring(1);
  }

  /// The category badge's fill color — one hue per category family (see
  /// [_typeColors]) so "Attraction", "Restaurant", "Hotel" etc. read as
  /// visually distinct at a glance instead of all sharing the same accent
  /// color. Falls back to [AppColors.primary] for any type not in the map.
  /// Same priority-order reasoning as [categoryLabel] above.
  Color get categoryColor {
    for (final entry in _typeColors.entries) {
      if (types.contains(entry.key)) return entry.value;
    }
    return AppColors.primary;
  }

  String get priceLevelLabel =>
      priceLevel == null ? '' : '₱' * (priceLevel! + 1);

  Place copyWithDistanceFrom({
    required double latitude,
    required double longitude,
  }) {
    if (!hasCoordinates) return this;
    return Place(
      id: id,
      name: name,
      types: types,
      photoNames: photoNames,
      rating: rating,
      userRatingCount: userRatingCount,
      address: address,
      phoneNumber: phoneNumber,
      websiteUri: websiteUri,
      priceLevel: priceLevel,
      isOpenNow: isOpenNow,
      latitude: this.latitude,
      longitude: this.longitude,
      distanceMeters: _haversineMeters(
        latitude,
        longitude,
        this.latitude!,
        this.longitude!,
      ),
      googleMapsUri: googleMapsUri,
      weekdayDescriptions: weekdayDescriptions,
      editorialSummary: editorialSummary,
    );
  }

  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180);

  factory Place.fromJson(Map<String, dynamic> json) {
    final location = _asStringMap(json['location']);
    return Place(
      id: json['id'] as String? ?? '',
      name: _asStringMap(json['displayName'])?['text'] as String? ?? '',
      types: List<String>.from(json['types'] as List? ?? const []),
      photoNames: (json['photos'] as List? ?? const [])
          .map((p) => _asStringMap(p)?['name'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toList(),
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingCount: (json['userRatingCount'] as num?)?.toInt(),
      address: json['formattedAddress'] as String? ?? '',
      phoneNumber: json['nationalPhoneNumber'] as String? ?? '',
      websiteUri: json['websiteUri'] as String? ?? '',
      priceLevel: _priceLevelFromJson(json['priceLevel']),
      isOpenNow: _asStringMap(json['currentOpeningHours'])?['openNow'] as bool?,
      latitude: (location?['latitude'] as num?)?.toDouble(),
      longitude: (location?['longitude'] as num?)?.toDouble(),
      googleMapsUri: json['googleMapsUri'] as String? ?? '',
      weekdayDescriptions: List<String>.from(
        _asStringMap(json['regularOpeningHours'])?['weekdayDescriptions']
                as List? ??
            const [],
      ),
      editorialSummary:
          _asStringMap(json['editorialSummary'])?['text'] as String? ?? '',
    );
  }

  /// Cloud Functions' platform channel decodes nested maps as
  /// `Map<Object?, Object?>`, not `Map<String, dynamic>` — only the
  /// top-level place map arrives pre-converted (see `PlacesService._parsePlaces`).
  /// A direct `as Map<String, dynamic>` cast on a nested field (`location`,
  /// `displayName`, each `photos` entry, etc.) throws at runtime, which
  /// `PlacesService.searchText`/`searchNearby`'s catch-all then silently
  /// swallows into an empty result list — this is why real Places results
  /// with a location/displayName (i.e. every real result) never showed up.
  static Map<String, dynamic>? _asStringMap(Object? value) {
    if (value == null) return null;
    return Map<String, dynamic>.from(value as Map);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'types': types,
      'photoNames': photoNames,
      'rating': rating,
      'userRatingCount': userRatingCount,
      'address': address,
      'phoneNumber': phoneNumber,
      'websiteUri': websiteUri,
      'priceLevel': priceLevel,
      'isOpenNow': isOpenNow,
      'latitude': latitude,
      'longitude': longitude,
      'distanceMeters': distanceMeters,
      'googleMapsUri': googleMapsUri,
      'weekdayDescriptions': weekdayDescriptions,
      'editorialSummary': editorialSummary,
    };
  }

  factory Place.fromCacheJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      types: List<String>.from(json['types'] as List? ?? const []),
      photoNames: List<String>.from(json['photoNames'] as List? ?? const []),
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingCount: (json['userRatingCount'] as num?)?.toInt(),
      address: json['address'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      websiteUri: json['websiteUri'] as String? ?? '',
      priceLevel: (json['priceLevel'] as num?)?.toInt(),
      isOpenNow: json['isOpenNow'] as bool?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      googleMapsUri: json['googleMapsUri'] as String? ?? '',
      weekdayDescriptions: List<String>.from(
        json['weekdayDescriptions'] as List? ?? const [],
      ),
      editorialSummary: json['editorialSummary'] as String? ?? '',
    );
  }

  /// Places API (New) returns priceLevel as a string enum
  /// (PRICE_LEVEL_INEXPENSIVE..PRICE_LEVEL_VERY_EXPENSIVE), not a number.
  static int? _priceLevelFromJson(Object? value) {
    const order = [
      'PRICE_LEVEL_FREE',
      'PRICE_LEVEL_INEXPENSIVE',
      'PRICE_LEVEL_MODERATE',
      'PRICE_LEVEL_EXPENSIVE',
      'PRICE_LEVEL_VERY_EXPENSIVE',
    ];
    if (value is! String) return null;
    final index = order.indexOf(value);
    return index == -1 ? null : index;
  }

  static const Map<String, String> _typeLabels = {
    'lodging': 'Hotel',
    'hotel': 'Hotel',
    'resort_hotel': 'Resort',
    'hostel': 'Hostel',
    'restaurant': 'Restaurant',
    'cafe': 'Café',
    'coffee_shop': 'Café',
    // Ordered most-specific-first within the "culture/sightseeing" family —
    // a UNESCO landscape like the Banaue/Batad Rice Terraces can come back
    // tagged 'cultural_landmark' *and* 'museum' with no 'tourist_attraction'
    // or 'historical_landmark' at all (Places API's newer Culture-category
    // types, added after this map was first written), so the generic
    // 'Attraction'/'Museum' fallbacks need to sit behind the more precise
    // types or they win by default.
    'cultural_landmark': 'Cultural Landmark',
    'historical_landmark': 'Historical Landmark',
    'historical_place': 'Historical Site',
    'monument': 'Monument',
    'castle': 'Castle',
    'scenic_spot': 'Scenic Spot',
    'national_park': 'National Park',
    'nature_preserve': 'Nature Reserve',
    'mountain_peak': 'Mountain',
    'botanical_garden': 'Garden',
    'tourist_attraction': 'Attraction',
    'visitor_center': 'Visitor Center',
    'art_gallery': 'Art Gallery',
    'art_museum': 'Museum',
    'history_museum': 'Museum',
    'museum': 'Museum',
    'park': 'Park',
    'beach': 'Beach',
    'amusement_park': 'Amusement Park',
    'zoo': 'Zoo',
    'shopping_mall': 'Shopping Mall',
    'gas_station': 'Gas Station',
    'pharmacy': 'Pharmacy',
    'hospital': 'Hospital',
    'atm': 'ATM',
    'bus_station': 'Bus Terminal',
    'train_station': 'Train Station',
    'airport': 'Airport',
  };

  static const Map<String, Color> _typeColors = {
    // Same priority order as _typeLabels — grouped into the existing family
    // hues rather than minting a new color per type (see `dataviz` skill:
    // categorical hues stay small and fixed, extras fold into a family).
    'cultural_landmark': AppColors.categoryLandmark,
    'historical_landmark': AppColors.categoryLandmark,
    'historical_place': AppColors.categoryLandmark,
    'monument': AppColors.categoryLandmark,
    'castle': AppColors.categoryLandmark,
    'scenic_spot': AppColors.categoryNature,
    'national_park': AppColors.categoryNature,
    'nature_preserve': AppColors.categoryNature,
    'mountain_peak': AppColors.categoryNature,
    'botanical_garden': AppColors.categoryNature,
    'tourist_attraction': AppColors.categorySightseeing,
    'visitor_center': AppColors.categorySightseeing,
    'art_gallery': AppColors.categoryMuseum,
    'art_museum': AppColors.categoryMuseum,
    'history_museum': AppColors.categoryMuseum,
    'museum': AppColors.categoryMuseum,
    'park': AppColors.categoryNature,
    'beach': AppColors.categoryNature,
    'amusement_park': AppColors.categorySightseeing,
    'zoo': AppColors.categoryNature,
    'restaurant': AppColors.categoryDining,
    'cafe': AppColors.categoryFoodDrink,
    'coffee_shop': AppColors.categoryFoodDrink,
    'shopping_mall': AppColors.categoryShopping,
    'lodging': AppColors.categoryLodging,
    'hotel': AppColors.categoryLodging,
    'resort_hotel': AppColors.categoryResort,
    'hostel': AppColors.categoryHostel,
    'gas_station': AppColors.categoryTransport,
    'pharmacy': AppColors.categoryTransport,
    'hospital': AppColors.categoryTransport,
    'atm': AppColors.categoryTransport,
    'bus_station': AppColors.categoryTransport,
    'train_station': AppColors.categoryTransport,
    'airport': AppColors.categoryTransport,
  };
}
