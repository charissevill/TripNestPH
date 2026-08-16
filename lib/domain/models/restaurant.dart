import 'package:cloud_firestore/cloud_firestore.dart';

/// A "Travelers say..." summary generated from a restaurant's own review
/// text by the scheduled `generateReviewDigests` Cloud Function — never
/// generated on-demand from the app, so opening a details page never
/// triggers a billed AI call. Null until the listing has enough reviews
/// (see that function's `REVIEW_DIGEST_MIN_REVIEWS`) for a first one.
class ReviewDigest {
  const ReviewDigest({required this.summary, required this.reviewCountAtGeneration, required this.generatedAt});

  final String summary;
  final int reviewCountAtGeneration;
  final DateTime generatedAt;

  factory ReviewDigest.fromMap(Map<String, dynamic> map) {
    final timestamp = map['generatedAt'];
    return ReviewDigest(
      summary: map['summary'] as String? ?? '',
      reviewCountAtGeneration: (map['reviewCountAtGeneration'] as num?)?.toInt() ?? 0,
      generatedAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }
}

/// A restaurant, cafe or eatery surfaced on Home, Explore, and details
/// screens. Backed by the `restaurants` Firestore collection; traveler
/// reviews live separately in `reviews`.
class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.provinceId,
    required this.provinceName,
    required this.regionId,
    this.cityId = '',
    required this.heroImageUrl,
    required this.galleryImageUrls,
    required this.rating,
    required this.reviewCount,
    required this.priceRange,
    required this.description,
    required this.openingHours,
    required this.menuHighlights,
    this.isPopular = false,
    this.latitude,
    this.longitude,
    this.phoneNumber = '',
    this.websiteUrl = '',
    this.facebookUrl = '',
    this.ownerId = '',
    this.businessId = '',
    this.accessibilityTags = const [],
    this.reviewDigest,
  });

  final String id;
  final String name;
  final String cuisine;

  /// References `provinces/{provinceId}`.
  final String provinceId;

  /// Denormalized display name — avoids an extra province lookup on every
  /// card/list that shows a location label.
  final String provinceName;

  /// Denormalized — lets region-level filtering/display skip a province
  /// lookup, same reasoning as [provinceName].
  final String regionId;

  /// References `provinces/{provinceId}/cities/{cityId}`, empty when this
  /// restaurant isn't tied to an on-demand city doc.
  final String cityId;

  final String heroImageUrl;
  final List<String> galleryImageUrls;
  final double rating;
  final int reviewCount;

  /// Displayed as a ₱ scale, e.g. "₱₱" for mid-range.
  final String priceRange;
  final String description;
  final String openingHours;
  final List<MenuItem> menuHighlights;
  final bool isPopular;
  final double? latitude;
  final double? longitude;
  final String phoneNumber;
  final String websiteUrl;
  final String facebookUrl;

  /// Uid of the `businessOwner` account whose approved `businesses` listing
  /// this was mirrored from — every restaurant has one now (see
  /// `RestaurantRepository.createFromBusiness`); empty only for legacy
  /// restaurants seeded before the Admin Portal used to curate this
  /// collection directly. `firestore.rules` uses this to let the owner keep
  /// their own listing's info in sync.
  final String ownerId;

  /// Back-reference to the `businesses/{id}` doc this was mirrored from —
  /// empty for the same legacy restaurants as [ownerId].
  final String businessId;

  /// Owner-declared accessibility notes, mirrored from `Business` — see
  /// `kAccessibilityTagOptions`.
  final List<String> accessibilityTags;

  /// Set by the scheduled `generateReviewDigests` Cloud Function — see
  /// [ReviewDigest]'s doc comment.
  final ReviewDigest? reviewDigest;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory Restaurant.fromMap(String id, Map<String, dynamic> map) {
    return Restaurant(
      id: id,
      name: map['name'] as String? ?? '',
      cuisine: map['cuisine'] as String? ?? '',
      provinceId: map['provinceId'] as String? ?? '',
      provinceName: map['provinceName'] as String? ?? '',
      regionId: map['regionId'] as String? ?? '',
      cityId: map['cityId'] as String? ?? '',
      heroImageUrl: map['heroImageUrl'] as String? ?? '',
      galleryImageUrls: List<String>.from(
        map['galleryImageUrls'] as List? ?? const [],
      ),
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      priceRange: map['priceRange'] as String? ?? '₱',
      description: map['description'] as String? ?? '',
      openingHours: map['openingHours'] as String? ?? '',
      menuHighlights: (map['menuHighlights'] as List? ?? const [])
          .map((e) => MenuItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      isPopular: map['isPopular'] as bool? ?? false,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      phoneNumber: map['phoneNumber'] as String? ?? '',
      websiteUrl: map['websiteUrl'] as String? ?? '',
      facebookUrl: map['facebookUrl'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      businessId: map['businessId'] as String? ?? '',
      accessibilityTags: List<String>.from(map['accessibilityTags'] as List? ?? const []),
      reviewDigest: map['reviewDigest'] is Map
          ? ReviewDigest.fromMap(Map<String, dynamic>.from(map['reviewDigest'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'cuisine': cuisine,
      'provinceId': provinceId,
      'provinceName': provinceName,
      'regionId': regionId,
      'cityId': cityId,
      'heroImageUrl': heroImageUrl,
      'galleryImageUrls': galleryImageUrls,
      'rating': rating,
      'reviewCount': reviewCount,
      'priceRange': priceRange,
      'description': description,
      'openingHours': openingHours,
      'menuHighlights': menuHighlights.map((m) => m.toMap()).toList(),
      'isPopular': isPopular,
      'latitude': latitude,
      'longitude': longitude,
      'phoneNumber': phoneNumber,
      'websiteUrl': websiteUrl,
      'facebookUrl': facebookUrl,
      'ownerId': ownerId,
      'businessId': businessId,
      'accessibilityTags': accessibilityTags,
    };
  }

  Restaurant copyWith({double? rating, int? reviewCount}) {
    return Restaurant(
      id: id,
      name: name,
      cuisine: cuisine,
      provinceId: provinceId,
      provinceName: provinceName,
      regionId: regionId,
      cityId: cityId,
      heroImageUrl: heroImageUrl,
      galleryImageUrls: galleryImageUrls,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      priceRange: priceRange,
      description: description,
      openingHours: openingHours,
      menuHighlights: menuHighlights,
      isPopular: isPopular,
      latitude: latitude,
      longitude: longitude,
      phoneNumber: phoneNumber,
      websiteUrl: websiteUrl,
      facebookUrl: facebookUrl,
      ownerId: ownerId,
      businessId: businessId,
      accessibilityTags: accessibilityTags,
      reviewDigest: reviewDigest,
    );
  }
}

class MenuItem {
  const MenuItem({
    required this.name,
    required this.price,
    required this.imageUrl,
  });

  final String name;
  final String price;
  final String imageUrl;

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      name: map['name'] as String? ?? '',
      price: map['price'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'price': price,
    'imageUrl': imageUrl,
  };
}
