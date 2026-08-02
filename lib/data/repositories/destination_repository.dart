import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/destination.dart';

/// Firestore access for the `tourist_spots` collection: Home carousels,
/// Explore/Search browsing (with pagination) and Details lookups.
class DestinationRepository {
  DestinationRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection(FirestorePaths.touristSpots);

  Destination _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      Destination.fromMap(doc.id, doc.data());

  /// Every traveler-facing query filters to `status == 'published'` so
  /// content drafted in the Admin Portal (Phase 4) never surfaces here —
  /// `getById` intentionally skips this filter so an already-favorited or
  /// already-linked spot doesn't 404 if an admin later drafts it, but
  /// `getByIds` (a batch *query*, not a single-doc lookup) can't skip it:
  /// firestore.rules requires a `list` operation to be provably
  /// published-only, so an unfiltered batch query would be rejected
  /// outright rather than just missing the drafted item.
  Query<Map<String, dynamic>> get _publishedOnly =>
      _collection.where('status', isEqualTo: 'published');

  Future<List<Destination>> getFeatured({int limit = 10}) =>
      _query(_publishedOnly.where('isFeatured', isEqualTo: true).limit(limit));

  Future<List<Destination>> getHiddenGems({int limit = 10}) =>
      _query(_publishedOnly.where('isHiddenGem', isEqualTo: true).limit(limit));

  Future<List<Destination>> getPopular({int limit = 10}) => _query(
    _publishedOnly.orderBy('reviewCount', descending: true).limit(limit),
  );

  /// Total published destinations — the Admin Portal analytics dashboard's
  /// content-coverage stat. A `count()` aggregation query, not a full
  /// fetch, so this stays cheap as the catalog grows.
  Future<int> countPublished() async {
    try {
      final result = await _publishedOnly.count().get();
      return result.count ?? 0;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Destination>> getByCategory(
    String categoryId, {
    int limit = 30,
  }) => _query(
    _publishedOnly.where('categoryId', isEqualTo: categoryId).limit(limit),
  );

  /// A page of every destination, ordered by name — used by Explore's grid.
  Future<
    ({List<Destination> items, DocumentSnapshot<Map<String, dynamic>>? lastDoc})
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

  Future<Destination?> getById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) return null;
      return Destination.fromMap(doc.id, doc.data()!);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Destination>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      // Firestore whereIn supports at most 30 values per query.
      final chunks = <List<String>>[];
      for (var i = 0; i < ids.length; i += 30) {
        chunks.add(ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30));
      }
      final results = <Destination>[];
      for (final chunk in chunks) {
        final snapshot = await _collection
            .where(FieldPath.documentId, whereIn: chunk)
            .where('status', isEqualTo: 'published')
            .get();
        results.addAll(snapshot.docs.map(_fromDoc));
      }
      return results;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Case-insensitive "starts with" search against the seeded `nameLower`
  /// field — the standard Firestore-native way to support search without a
  /// third-party indexing service.
  Future<List<Destination>> searchByName(String query, {int limit = 20}) async {
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

  Future<List<Destination>> filter({
    String? provinceId,
    String? categoryId,
    double? minRating,
    int limit = 30,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _publishedOnly;
      if (provinceId != null && provinceId.isNotEmpty) {
        query = query.where('provinceId', isEqualTo: provinceId);
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.where('categoryId', isEqualTo: categoryId);
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

  Future<void> updateAggregateRating(
    String id, {
    required double rating,
    required int reviewCount,
  }) async {
    try {
      await _collection.doc(id).update({
        'rating': rating,
        'reviewCount': reviewCount,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Published, coordinate-bearing destinations whose `latitude` falls
  /// within [radiusKm] of [latitude] — a coarse pre-filter for "Nearby You"
  /// (Firestore can only range-query one field per query, so longitude and
  /// the real circular distance are narrowed client-side by the caller).
  /// Searches the full catalog rather than a pre-loaded candidate list, and
  /// stays index-cheap as the catalog grows since it never fetches more
  /// than the requested latitude band.
  Future<List<Destination>> getNearbyLatitudeBand({
    required double latitude,
    required double radiusKm,
  }) async {
    try {
      final latDelta = radiusKm / 111; // ~111 km per degree of latitude
      final snapshot = await _publishedOnly
          .where('latitude', isGreaterThanOrEqualTo: latitude - latDelta)
          .where('latitude', isLessThanOrEqualTo: latitude + latDelta)
          .get();
      return snapshot.docs
          .map(_fromDoc)
          .where((d) => d.hasCoordinates)
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Every tourist spot in [provinceId] regardless of `status` — the
  /// Admin/LGU Portal's own listing view, deliberately not filtered through
  /// [_publishedOnly] so an admin can find and fix a spot even if it's ever
  /// in a non-published state.
  Future<List<Destination>> getAllForProvinceAdmin(String provinceId) async {
    try {
      final snapshot = await _collection
          .where('provinceId', isEqualTo: provinceId)
          .orderBy('name')
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Admin/LGU Portal write — matches `firestore.rules`'s
  /// `hasAdminRole(['admin', 'lgu'])` create permission on `tourist_spots`.
  /// Published immediately (no draft/review workflow in this pass).
  Future<String> create(Destination destination) async {
    try {
      final doc = await _collection.add({
        ...destination.toMap(),
        'nameLower': destination.name.toLowerCase(),
        'status': 'published',
      });
      return doc.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Admin/LGU Portal write — matches `firestore.rules`'s
  /// `hasAdminRole(['admin', 'lgu'])` update permission (no field
  /// restriction for that role, unlike the traveler
  /// rating/reviewCount-only path above).
  Future<void> update(String id, Destination destination) async {
    try {
      await _collection.doc(id).update({
        ...destination.toMap(),
        'nameLower': destination.name.toLowerCase(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Admin/LGU Portal write — matches `firestore.rules`'s
  /// `hasAdminRole(['admin', 'lgu'])` delete permission on `tourist_spots`.
  Future<void> delete(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Destination>> _query(Query<Map<String, dynamic>> query) async {
    try {
      final snapshot = await query.get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
