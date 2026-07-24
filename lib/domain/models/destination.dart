/// A tourist spot, natural attraction or landmark shown across Home,
/// Explore and the Tourist Details screen. Backed by the `tourist_spots`
/// Firestore collection; traveler reviews live separately in `reviews`.
class Destination {
  const Destination({
    required this.id,
    required this.name,
    required this.provinceId,
    required this.provinceName,
    required this.regionId,
    this.cityId = '',
    required this.categoryId,
    required this.heroImageUrl,
    required this.galleryImageUrls,
    required this.rating,
    required this.reviewCount,
    required this.shortDescription,
    required this.longDescription,
    required this.entranceFee,
    required this.bestTimeToVisit,
    required this.travelTips,
    required this.highlights,
    this.isHiddenGem = false,
    this.isFeatured = false,
    this.nearbyRestaurantIds = const [],
    this.nearbyDestinationIds = const [],
    this.latitude,
    this.longitude,
    this.phoneNumber = '',
    this.websiteUrl = '',
    this.facebookUrl = '',
    this.openingHours = '',
  });

  final String id;
  final String name;

  /// References `provinces/{provinceId}`.
  final String provinceId;

  /// Denormalized display name — avoids an extra province lookup on every
  /// card/list that shows a location label.
  final String provinceName;

  /// Denormalized — lets region-level filtering/display skip a province
  /// lookup, same reasoning as [provinceName].
  final String regionId;

  /// References `provinces/{provinceId}/cities/{cityId}`, empty when this
  /// destination isn't tied to an on-demand city doc.
  final String cityId;

  final String categoryId;
  final String heroImageUrl;
  final List<String> galleryImageUrls;
  final double rating;
  final int reviewCount;
  final String shortDescription;
  final String longDescription;
  final String entranceFee;
  final String bestTimeToVisit;
  final List<String> travelTips;
  final List<String> highlights;
  final bool isHiddenGem;
  final bool isFeatured;
  final List<String> nearbyRestaurantIds;
  final List<String> nearbyDestinationIds;
  final double? latitude;
  final double? longitude;
  final String phoneNumber;
  final String websiteUrl;
  final String facebookUrl;
  final String openingHours;

  String get locationLabel => provinceName;
  bool get hasCoordinates => latitude != null && longitude != null;

  factory Destination.fromMap(String id, Map<String, dynamic> map) {
    return Destination(
      id: id,
      name: map['name'] as String? ?? '',
      provinceId: map['provinceId'] as String? ?? '',
      provinceName: map['provinceName'] as String? ?? '',
      regionId: map['regionId'] as String? ?? '',
      cityId: map['cityId'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? '',
      heroImageUrl: map['heroImageUrl'] as String? ?? '',
      galleryImageUrls: List<String>.from(map['galleryImageUrls'] as List? ?? const []),
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      shortDescription: map['shortDescription'] as String? ?? '',
      longDescription: map['longDescription'] as String? ?? '',
      entranceFee: map['entranceFee'] as String? ?? '',
      bestTimeToVisit: map['bestTimeToVisit'] as String? ?? '',
      travelTips: List<String>.from(map['travelTips'] as List? ?? const []),
      highlights: List<String>.from(map['highlights'] as List? ?? const []),
      isHiddenGem: map['isHiddenGem'] as bool? ?? false,
      isFeatured: map['isFeatured'] as bool? ?? false,
      nearbyRestaurantIds: List<String>.from(map['nearbyRestaurantIds'] as List? ?? const []),
      nearbyDestinationIds: List<String>.from(map['nearbyDestinationIds'] as List? ?? const []),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      phoneNumber: map['phoneNumber'] as String? ?? '',
      websiteUrl: map['websiteUrl'] as String? ?? '',
      facebookUrl: map['facebookUrl'] as String? ?? '',
      openingHours: map['openingHours'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'provinceId': provinceId,
      'provinceName': provinceName,
      'regionId': regionId,
      'cityId': cityId,
      'categoryId': categoryId,
      'heroImageUrl': heroImageUrl,
      'galleryImageUrls': galleryImageUrls,
      'rating': rating,
      'reviewCount': reviewCount,
      'shortDescription': shortDescription,
      'longDescription': longDescription,
      'entranceFee': entranceFee,
      'bestTimeToVisit': bestTimeToVisit,
      'travelTips': travelTips,
      'highlights': highlights,
      'isHiddenGem': isHiddenGem,
      'isFeatured': isFeatured,
      'nearbyRestaurantIds': nearbyRestaurantIds,
      'nearbyDestinationIds': nearbyDestinationIds,
      'latitude': latitude,
      'longitude': longitude,
      'phoneNumber': phoneNumber,
      'websiteUrl': websiteUrl,
      'facebookUrl': facebookUrl,
      'openingHours': openingHours,
    };
  }

  Destination copyWith({double? rating, int? reviewCount}) {
    return Destination(
      id: id,
      name: name,
      provinceId: provinceId,
      provinceName: provinceName,
      regionId: regionId,
      cityId: cityId,
      categoryId: categoryId,
      heroImageUrl: heroImageUrl,
      galleryImageUrls: galleryImageUrls,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      shortDescription: shortDescription,
      longDescription: longDescription,
      entranceFee: entranceFee,
      bestTimeToVisit: bestTimeToVisit,
      travelTips: travelTips,
      highlights: highlights,
      isHiddenGem: isHiddenGem,
      isFeatured: isFeatured,
      nearbyRestaurantIds: nearbyRestaurantIds,
      nearbyDestinationIds: nearbyDestinationIds,
      latitude: latitude,
      longitude: longitude,
      phoneNumber: phoneNumber,
      websiteUrl: websiteUrl,
      facebookUrl: facebookUrl,
      openingHours: openingHours,
    );
  }
}
