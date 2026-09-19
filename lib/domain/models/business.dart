import 'restaurant.dart' show MenuItem;

/// A `businessOwner` account's self-service listing (accommodation, food
/// stall, tour operator, shop, etc.) — separate from the curated
/// `tourist_spots` collection, which stays Admin/LGU-authored. A
/// `foodAndDining` listing is the *only* way a `restaurants` doc gets
/// created: once approved, it's mirrored into `restaurants` (see
/// `RestaurantRepository.createFromBusiness`) so it shows up in Explore/
/// Search like any other restaurant, kept in sync on every edit, and
/// unpublished (not deleted) if the business is later suspended. See
/// `firestore.rules` for the owner-scoped write rules and admin approval
/// workflow.
class Business {
  const Business({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.category,
    required this.description,
    required this.provinceId,
    required this.provinceName,
    this.regionId = '',
    this.address = '',
    this.contactNumber = '',
    this.websiteUrl = '',
    this.heroImageUrl = '',
    this.cuisine = '',
    this.priceRange = '₱',
    this.openingHours = '',
    this.status = 'pending',
    this.rejectionReason = '',
    this.restaurantId = '',
    this.accessibilityTags = const [],
    this.viewCount = 0,
    this.menuItems = const [],
    this.latitude,
    this.longitude,
    this.rating = 0,
    this.reviewCount = 0,
  });

  final String id;
  final String ownerId;
  final String name;

  /// One of [BusinessCategory.all].
  final String category;
  final String description;

  /// References `provinces/{provinceId}`.
  final String provinceId;
  final String provinceName;

  /// Denormalized from the selected province — needed on the mirrored
  /// `restaurants` doc for region-level filtering, same reasoning as
  /// [RestaurantRepository]'s other denormalized `regionId` fields.
  final String regionId;
  final String address;
  final String contactNumber;
  final String websiteUrl;
  final String heroImageUrl;

  /// [category] == [BusinessCategory.foodAndDining] only — ignored
  /// otherwise. Mirrored onto the linked `restaurants` doc.
  final String cuisine;
  final String priceRange;
  final String openingHours;

  /// 'pending' | 'approved' | 'rejected' | 'suspended' — only an admin can
  /// change this (see `firestore.rules`); the owner can move a 'rejected'
  /// listing back to 'pending' by resubmitting.
  final String status;

  /// Set by an admin alongside `status: 'rejected'`; cleared on resubmit.
  final String rejectionReason;

  /// The linked `restaurants/{id}` doc, set once an admin first approves a
  /// [BusinessCategory.foodAndDining] listing — empty until then, and for
  /// every non-food category. System-managed, same as [status]: the owner
  /// can never set this themselves (see `firestore.rules`).
  final String restaurantId;

  /// Owner-declared accessibility notes (e.g. "Step-free entrance") — see
  /// [kAccessibilityTagOptions]. Mirrored onto the linked `restaurants` doc
  /// like [cuisine]/[priceRange]; stored here regardless of category so it
  /// isn't lost if a listing's category ever changes.
  final List<String> accessibilityTags;

  /// How many times a traveler has opened this listing — every category,
  /// not just [isFoodAndDining] (which has its own richer restaurant-page
  /// view count baked into this same field via `RestaurantRepository`
  /// incrementing it by [restaurantId]). System-managed like [status]: never
  /// set directly by the owner, only ever atomically incremented by
  /// `BusinessRepository.incrementViewCount` (see `firestore.rules`'
  /// `isValidViewCountIncrement`).
  final int viewCount;

  /// A simple name/price/photo catalog — a cafe's menu, a hotel's room
  /// types, a tour operator's packages, a shop's products, a transport
  /// service's rates, all the same shape (see `_CatalogLabels` on
  /// `MyBusinessScreen`, which is the only place this differs per
  /// [category]: the section/item labels shown to the owner, not the data
  /// itself). Only [isFoodAndDining] currently mirrors onto anything a
  /// traveler can see (the linked `restaurants` doc's own `menuHighlights`
  /// field — see `RestaurantRepository.createFromBusiness`/
  /// `updateFromBusiness`) — every other category has no public-facing
  /// listing page yet (see this class's own doc comment), so its catalog is
  /// saved but not shown anywhere outside the owner's own edit screen until
  /// one exists.
  final List<MenuItem> menuItems;

  /// Set via the Address field's "Pin on Map" picker (see
  /// `MyBusinessScreen._pickAddressOnMap`) — null for a listing created
  /// before that existed, or whose owner only ever typed the address by
  /// hand. Null means Explore's map view for this listing's category just
  /// skips it, the same "best-effort, never fabricated" rule every other
  /// optional coordinate in this app already follows.
  final double? latitude;
  final double? longitude;

  /// System-managed, same as [viewCount]: only ever recalculated by
  /// `ReviewRepository` after a traveler writes/edits/removes a review
  /// targeting this listing (`ReviewTargetType.business`) — the owner's own
  /// `toInfoMap()` edit path never touches either field.
  final double rating;
  final int reviewCount;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isSuspended => status == 'suspended';
  bool get isFoodAndDining => category == BusinessCategory.foodAndDining;

  factory Business.fromMap(String id, Map<String, dynamic> map) {
    return Business(
      id: id,
      ownerId: map['ownerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? BusinessCategory.other,
      description: map['description'] as String? ?? '',
      provinceId: map['provinceId'] as String? ?? '',
      provinceName: map['provinceName'] as String? ?? '',
      regionId: map['regionId'] as String? ?? '',
      address: map['address'] as String? ?? '',
      contactNumber: map['contactNumber'] as String? ?? '',
      websiteUrl: map['websiteUrl'] as String? ?? '',
      heroImageUrl: map['heroImageUrl'] as String? ?? '',
      cuisine: map['cuisine'] as String? ?? '',
      priceRange: map['priceRange'] as String? ?? '₱',
      openingHours: map['openingHours'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      rejectionReason: map['rejectionReason'] as String? ?? '',
      restaurantId: map['restaurantId'] as String? ?? '',
      accessibilityTags: List<String>.from(
        map['accessibilityTags'] as List? ?? const [],
      ),
      viewCount: (map['viewCount'] as num?)?.toInt() ?? 0,
      menuItems: (map['menuItems'] as List? ?? const [])
          .map((e) => MenuItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Info fields only — never includes `ownerId`/`status`/`rejectionReason`/
  /// `restaurantId`, which `BusinessRepository` writes separately so a plain
  /// info-edit save can never accidentally trip the rules' status-change or
  /// restaurant-linking branches.
  Map<String, dynamic> toInfoMap() {
    return {
      'name': name,
      'category': category,
      'description': description,
      'provinceId': provinceId,
      'provinceName': provinceName,
      'regionId': regionId,
      'address': address,
      'contactNumber': contactNumber,
      'websiteUrl': websiteUrl,
      'heroImageUrl': heroImageUrl,
      'cuisine': cuisine,
      'priceRange': priceRange,
      'openingHours': openingHours,
      'accessibilityTags': accessibilityTags,
      'menuItems': menuItems.map((m) => m.toMap()).toList(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

/// Fixed vocabulary offered on the business listing form and the Search/
/// Explore accessibility filter — kept short and concrete rather than
/// free-text, so a filter can match against it reliably.
const List<String> kAccessibilityTagOptions = [
  'Step-free entrance',
  'Accessible restroom',
  'Wheelchair-friendly seating',
  'Senior/PWD priority lane',
];

class BusinessCategory {
  BusinessCategory._();

  static const String accommodation = 'accommodation';
  static const String foodAndDining = 'foodAndDining';
  static const String tourOperator = 'tourOperator';
  static const String shop = 'shop';
  static const String transport = 'transport';
  static const String other = 'other';

  static const List<String> all = [
    accommodation,
    foodAndDining,
    tourOperator,
    shop,
    transport,
    other,
  ];

  static String label(String category) {
    switch (category) {
      case accommodation:
        return 'Accommodation';
      case foodAndDining:
        return 'Food & Dining';
      case tourOperator:
        return 'Tour Operator';
      case shop:
        return 'Shop';
      case transport:
        return 'Transport';
      default:
        return 'Other';
    }
  }
}
