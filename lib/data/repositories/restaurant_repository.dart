import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/business.dart';
import '../../domain/models/restaurant.dart';

/// Firestore access for the `restaurants` collection.
class RestaurantRepository {
  RestaurantRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection(FirestorePaths.restaurants);

  Restaurant _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      Restaurant.fromMap(doc.id, doc.data());

  /// Every traveler-facing query filters to `status == 'published'` so
  /// content drafted in the Admin Portal never surfaces here — `getById`
  /// intentionally skips this filter (an already-linked restaurant
  /// shouldn't 404 if it's since gone back to draft), but `getByIds` can't:
  /// firestore.rules requires a `list` query to be provably published-only.
  Query<Map<String, dynamic>> get _publishedOnly =>
      _collection.where('status', isEqualTo: 'published');

  Future<List<Restaurant>> getPopular({int limit = 10}) =>
      _query(_publishedOnly.where('isPopular', isEqualTo: true).limit(limit));

  /// Total published restaurants — the Admin Portal analytics dashboard's
  /// content-coverage stat.
  Future<int> countPublished() async {
    try {
      final result = await _publishedOnly.count().get();
      return result.count ?? 0;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<
    ({List<Restaurant> items, DocumentSnapshot<Map<String, dynamic>>? lastDoc})
  >
  getPage({
    int pageSize = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    try {
      var query = _publishedOnly.orderBy('name').limit(pageSize);
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snapshot = await query.get();
      return (
        items: snapshot.docs.map(_fromDoc).toList(),
        lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Restaurant?> getById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) return null;
      return Restaurant.fromMap(doc.id, doc.data()!);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Restaurant>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final snapshot = await _collection
          .where(FieldPath.documentId, whereIn: ids.take(30).toList())
          .where('status', isEqualTo: 'published')
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Restaurant>> searchByName(String query, {int limit = 20}) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];
    try {
      final snapshot = await _publishedOnly
          .orderBy('nameLower')
          .startAt([normalized])
          .endAt(['$normalized'])
          .limit(limit)
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Restaurant>> filter({
    String? provinceId,
    String? priceRange,
    double? minRating,
    int limit = 30,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _publishedOnly;
      if (provinceId != null && provinceId.isNotEmpty) {
        query = query.where('provinceId', isEqualTo: provinceId);
      }
      if (priceRange != null && priceRange.isNotEmpty) {
        query = query.where('priceRange', isEqualTo: priceRange);
      }
      if (minRating != null) {
        query = query.where('rating', isGreaterThanOrEqualTo: minRating);
      }
      final snapshot = await query.limit(limit).get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Overwrites just the average — [ReviewRepository] owns `reviewCount`
  /// separately via [adjustReviewCount], which is atomic and must never be
  /// clobbered by a plain overwrite based on a possibly-stale read.
  Future<void> updateAggregateRating(String id, {required double rating}) async {
    try {
      await _collection.doc(id).update({'rating': rating});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Atomically bumps `reviewCount` by [delta] (+1/-1) server-side — see
  /// `DestinationRepository.adjustReviewCount` for the full reasoning.
  Future<void> adjustReviewCount(String id, int delta) async {
    try {
      await _collection.doc(id).update({'reviewCount': FieldValue.increment(delta)});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Published, coordinate-bearing restaurants whose `latitude` falls within
  /// [radiusKm] of [latitude] — see `DestinationRepository.getNearbyLatitudeBand`
  /// for why this is a latitude-band pre-filter rather than a full scan.
  Future<List<Restaurant>> getNearbyLatitudeBand({
    required double latitude,
    required double radiusKm,
  }) async {
    try {
      final latDelta = radiusKm / 111;
      final snapshot = await _publishedOnly
          .where('latitude', isGreaterThanOrEqualTo: latitude - latDelta)
          .where('latitude', isLessThanOrEqualTo: latitude + latDelta)
          .get();
      return snapshot.docs
          .map(_fromDoc)
          .where((r) => r.hasCoordinates)
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Mirrors a just-approved [BusinessCategory.foodAndDining] business into
  /// a brand-new `restaurants` doc — the *only* way a restaurant gets
  /// created (see the class doc on [Business]). Called once, from
  /// `AdminBusinessListScreen._approve`, the first time that business is
  /// approved; the returned id is saved back onto the business as
  /// `restaurantId` via `BusinessRepository.setRestaurantId`. Published
  /// immediately since the business was just approved.
  Future<String> createFromBusiness(Business business) async {
    try {
      final doc = await _collection.add({
        'name': business.name,
        'cuisine': business.cuisine,
        'provinceId': business.provinceId,
        'provinceName': business.provinceName,
        'regionId': business.regionId,
        'cityId': '',
        'heroImageUrl': business.heroImageUrl,
        'galleryImageUrls': <String>[],
        'rating': 0,
        'reviewCount': 0,
        'priceRange': business.priceRange,
        'description': business.description,
        'openingHours': business.openingHours,
        'menuHighlights': <Map<String, dynamic>>[],
        'isPopular': false,
        'phoneNumber': business.contactNumber,
        'websiteUrl': business.websiteUrl,
        'facebookUrl': '',
        'ownerId': business.ownerId,
        'businessId': business.id,
        'nameLower': business.name.toLowerCase(),
        'status': 'published',
      });
      return doc.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Pushes edited business info into its already-linked restaurant doc —
  /// called whenever the owner (or admin) saves changes to a business that
  /// already has a [Business.restaurantId]. Never touches
  /// status/rating/reviewCount, matching `firestore.rules`'s owner-update
  /// field restriction.
  Future<void> updateFromBusiness(
    String restaurantId,
    Business business,
  ) async {
    try {
      await _collection.doc(restaurantId).update({
        'name': business.name,
        'cuisine': business.cuisine,
        'provinceId': business.provinceId,
        'provinceName': business.provinceName,
        'regionId': business.regionId,
        'heroImageUrl': business.heroImageUrl,
        'priceRange': business.priceRange,
        'description': business.description,
        'openingHours': business.openingHours,
        'phoneNumber': business.contactNumber,
        'websiteUrl': business.websiteUrl,
        'nameLower': business.name.toLowerCase(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Publishes/unpublishes a restaurant — the mirror of its linked business
  /// being reactivated/suspended by an admin. Unpublishing (not deleting)
  /// keeps the restaurant's existing reviews intact for if it comes back.
  Future<void> setPublished(String restaurantId, bool published) async {
    try {
      await _collection.doc(restaurantId).update({
        'status': published ? 'published' : 'draft',
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Removes a restaurant outright — only when its linked business is
  /// deleted entirely (see `AdminBusinessListScreen._delete`), as opposed
  /// to suspended (see [setPublished]).
  Future<void> delete(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Restaurant>> _query(Query<Map<String, dynamic>> query) async {
    try {
      final snapshot = await query.get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
