import 'dart:math' as math;

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

  /// A human-readable category label derived from the first recognized
  /// type, e.g. 'lodging' -> 'Hotel'. Falls back to the raw type string
  /// (title-cased) for anything not in the curated map.
  String get categoryLabel {
    for (final type in types) {
      final label = _typeLabels[type];
      if (label != null) return label;
    }
    if (types.isEmpty) return 'Place';
    final raw = types.first.replaceAll('_', ' ');
    return raw.isEmpty ? 'Place' : raw[0].toUpperCase() + raw.substring(1);
  }

  String get priceLevelLabel => priceLevel == null ? '' : '₱' * (priceLevel! + 1);

  Place copyWithDistanceFrom({required double latitude, required double longitude}) {
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
      distanceMeters: _haversineMeters(latitude, longitude, this.latitude!, this.longitude!),
      googleMapsUri: googleMapsUri,
      weekdayDescriptions: weekdayDescriptions,
      editorialSummary: editorialSummary,
    );
  }

  static double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180);

  factory Place.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>?;
    return Place(
      id: json['id'] as String? ?? '',
      name: (json['displayName'] as Map<String, dynamic>?)?['text'] as String? ?? '',
      types: List<String>.from(json['types'] as List? ?? const []),
      photoNames: (json['photos'] as List? ?? const [])
          .map((p) => (p as Map<String, dynamic>)['name'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toList(),
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingCount: (json['userRatingCount'] as num?)?.toInt(),
      address: json['formattedAddress'] as String? ?? '',
      phoneNumber: json['nationalPhoneNumber'] as String? ?? '',
      websiteUri: json['websiteUri'] as String? ?? '',
      priceLevel: _priceLevelFromJson(json['priceLevel']),
      isOpenNow: (json['currentOpeningHours'] as Map<String, dynamic>?)?['openNow'] as bool?,
      latitude: (location?['latitude'] as num?)?.toDouble(),
      longitude: (location?['longitude'] as num?)?.toDouble(),
      googleMapsUri: json['googleMapsUri'] as String? ?? '',
      weekdayDescriptions: List<String>.from(
        (json['regularOpeningHours'] as Map<String, dynamic>?)?['weekdayDescriptions'] as List? ?? const [],
      ),
      editorialSummary: (json['editorialSummary'] as Map<String, dynamic>?)?['text'] as String? ?? '',
    );
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
      weekdayDescriptions: List<String>.from(json['weekdayDescriptions'] as List? ?? const []),
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
    'tourist_attraction': 'Attraction',
    'historical_landmark': 'Historical Landmark',
    'museum': 'Museum',
    'park': 'Park',
    'beach': 'Beach',
    'shopping_mall': 'Shopping Mall',
    'gas_station': 'Gas Station',
    'pharmacy': 'Pharmacy',
    'hospital': 'Hospital',
    'atm': 'ATM',
    'bus_station': 'Bus Terminal',
    'train_station': 'Train Station',
    'airport': 'Airport',
  };
}
