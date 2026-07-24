import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/restaurant.dart';

/// Firestore access for the `restaurants` collection.
class RestaurantRepository {
  RestaurantRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection(FirestorePaths.restaurants);

  Restaurant _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) => Restaurant.fromMap(doc.id, doc.data());

  /// Every traveler-facing query filters to `status == 'published'` so
  /// content drafted in the Admin Portal never surfaces here — direct
  /// lookups (getById/getByIds) intentionally skip this filter.
  Query<Map<String, dynamic>> get _publishedOnly => _collection.where('status', isEqualTo: 'published');

  Future<List<Restaurant>> getPopular({int limit = 10}) => _query(
        _publishedOnly.where('isPopular', isEqualTo: true).limit(limit),
      );

  Future<({List<Restaurant> items, DocumentSnapshot<Map<String, dynamic>>? lastDoc})> getPage({
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
      final snapshot = await _collection.where(FieldPath.documentId, whereIn: ids.take(30).toList()).get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Restaurant>> searchByName(String query, {int limit = 20}) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];
    try {
      final snapshot =
          await _publishedOnly.orderBy('nameLower').startAt([normalized]).endAt(['$normalized']).limit(limit).get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Restaurant>> filter({String? provinceId, String? priceRange, double? minRating, int limit = 30}) async {
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

  Future<void> updateAggregateRating(String id, {required double rating, required int reviewCount}) async {
    try {
      await _collection.doc(id).update({'rating': rating, 'reviewCount': reviewCount});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Published, coordinate-bearing restaurants whose `latitude` falls within
  /// [radiusKm] of [latitude] — see `DestinationRepository.getNearbyLatitudeBand`
  /// for why this is a latitude-band pre-filter rather than a full scan.
  Future<List<Restaurant>> getNearbyLatitudeBand({required double latitude, required double radiusKm}) async {
    try {
      final latDelta = radiusKm / 111;
      final snapshot = await _publishedOnly
          .where('latitude', isGreaterThanOrEqualTo: latitude - latDelta)
          .where('latitude', isLessThanOrEqualTo: latitude + latDelta)
          .get();
      return snapshot.docs.map(_fromDoc).where((r) => r.hasCoordinates).toList();
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
