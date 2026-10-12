import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/business.dart';
import '../../domain/models/business_permit.dart';

/// Firestore access for the `businesses` collection — a `businessOwner`
/// account's own self-service listing(s), separate from the curated
/// `restaurants`/`tourist_spots` collections. See `firestore.rules` for the
/// owner-scoped write rules and admin approval workflow.
class BusinessRepository {
  BusinessRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection(FirestorePaths.businesses);

  Business _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      Business.fromMap(doc.id, doc.data());

  /// `businesses/{id}/private/permit` — see [BusinessPermit]'s doc comment
  /// for why this lives outside the main doc.
  DocumentReference<Map<String, dynamic>> _permitDoc(String id) => _collection
      .doc(id)
      .collection(FirestorePaths.businessPrivate)
      .doc('permit');

  Future<BusinessPermit?> getPermit(String id) async {
    try {
      final doc = await _permitDoc(id).get();
      return doc.data() == null ? null : BusinessPermit.fromMap(doc.data()!);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Stream<BusinessPermit?> streamPermit(String id) {
    return _permitDoc(id).snapshots().map(
      (doc) => doc.data() == null ? null : BusinessPermit.fromMap(doc.data()!),
    );
  }

  /// The only field a client may ever write here — see firestore.rules,
  /// which forbids `permitOcrText` from every client write branch on this
  /// doc (only the `extractPermitText` Cloud Function sets that, via the
  /// Admin SDK).
  Future<void> setPermitUrl(String id, String url) async {
    try {
      await _permitDoc(id).set({'permitUrl': url}, SetOptions(merge: true));
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Batched lookup by id — see `RestaurantRepository.getByIds` for the same
  /// pattern, `status` filter included. Security rules aren't filters:
  /// `firestore.rules` only lets a traveler read a listing that's
  /// 'approved', and Firestore rejects a whole query that *could* return
  /// anything else — so without the filter this failed with
  /// permission-denied for every traveler and their saved Local Finds
  /// came back empty. A since-suspended/rejected listing just drops out.
  Future<List<Business>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final snapshot = await _collection
          .where(FieldPath.documentId, whereIn: ids.take(30).toList())
          .where('status', isEqualTo: 'approved')
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Approved listings whose mirrored `restaurants` doc is one of
  /// [restaurantIds]. A Food & Dining listing is saved (and reviewed) under
  /// that restaurant id rather than its own — see
  /// `businessFavoriteAndReviewTarget` — so this is how a saved one is found
  /// again as the Local Find it was saved from.
  Future<List<Business>> getApprovedByRestaurantIds(
    List<String> restaurantIds,
  ) async {
    if (restaurantIds.isEmpty) return [];
    try {
      final snapshot = await _collection
          .where('status', isEqualTo: 'approved')
          .where('restaurantId', whereIn: restaurantIds.take(30).toList())
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Every listing owned by [uid] — a business owner can have more than one.
  Stream<List<Business>> streamForOwner(String uid) {
    return _collection
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  /// Goes live straight away: holding the `businessOwner` role already
  /// means an admin verified this owner (their application's permit and ID,
  /// or a direct invite), so there's no second review of the listing — an
  /// admin/LGU moderates it afterwards by suspending it instead.
  Future<String> create(Business business) async {
    try {
      final doc = await _collection.add({
        ...business.toInfoMap(),
        'ownerId': business.ownerId,
        'status': 'approved',
        'rejectionReason': '',
        'viewCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Atomic +1, never a read-then-write — the same reasoning
  /// `ReviewRepository`'s count adjustments already document: two travelers
  /// opening this listing at nearly the same moment must never silently
  /// clobber each other's increment. Any signed-in traveler may call this
  /// (not just the owner — see `firestore.rules`' `isValidViewCountIncrement`
  /// branch), since it's their own view being counted.
  Future<void> incrementViewCount(String id) async {
    try {
      await _collection.doc(id).update({'viewCount': FieldValue.increment(1)});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Atomically bumps `reviewCount` by [delta] (+1/-1) server-side — see
  /// `DestinationRepository.adjustReviewCount` for the full reasoning;
  /// called by `ReviewRepository` after a traveler writes/removes a review
  /// targeting this listing (`ReviewTargetType.business`).
  Future<void> adjustReviewCount(String id, int delta) async {
    try {
      await _collection.doc(id).update({
        'reviewCount': FieldValue.increment(delta),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Overwrites just the average — [ReviewRepository] owns `reviewCount`
  /// separately via [adjustReviewCount], which is atomic and must never be
  /// clobbered by a plain overwrite based on a possibly-stale read.
  Future<void> updateAggregateRating(
    String id, {
    required double rating,
  }) async {
    try {
      await _collection.doc(id).update({'rating': rating});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// A plain info edit — never touches status/rejectionReason/ownerId.
  Future<void> update(String id, Business business) async {
    try {
      await _collection.doc(id).update(business.toInfoMap());
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Moves a rejected listing back to 'pending' for re-review, optionally
  /// saving edited info in the same write (both are allowed together by
  /// `firestore.rules`'s resubmit branch).
  Future<void> resubmit(String id, Business business) async {
    try {
      await _collection.doc(id).update({
        ...business.toInfoMap(),
        'status': 'pending',
        'rejectionReason': '',
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Admin-only queue — every business regardless of status, matching the
  /// `getAllForProvinceAdmin` pattern in `DestinationRepository`.
  ///
  /// An 'lgu' account has to pass its own [provinceId]: `firestore.rules`
  /// only lets it read listings in that province, and rejects a query that
  /// isn't provably limited to them. That query is sorted here rather than
  /// by Firestore, which would need a composite index for it.
  Stream<List<Business>> streamAllForAdmin({String? provinceId}) {
    if (provinceId != null) {
      return _collection
          .where('provinceId', isEqualTo: provinceId)
          .snapshots()
          .map((s) {
            // Newest first; a listing whose server timestamp hasn't
            // resolved yet is the newest of all.
            int millis(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
              final createdAt = doc.data()['createdAt'];
              return createdAt is Timestamp
                  ? createdAt.millisecondsSinceEpoch
                  : DateTime.now().millisecondsSinceEpoch;
            }

            final docs = [...s.docs]
              ..sort((a, b) => millis(b).compareTo(millis(a)));
            return docs.map(_fromDoc).toList();
          });
    }
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  Future<void> setStatus(
    String id, {
    required String status,
    String rejectionReason = '',
  }) async {
    try {
      await _collection.doc(id).update({
        'status': status,
        'rejectionReason': rejectionReason,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Records the `restaurants/{id}` doc created for this business on its
  /// first approval — see `RestaurantRepository.createFromBusiness` and
  /// `AdminBusinessListScreen._approve`.
  Future<void> setRestaurantId(String id, String restaurantId) async {
    try {
      await _collection.doc(id).update({'restaurantId': restaurantId});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _collection.doc(id).delete();
      // Best-effort — an admin-only delete right, same as the parent doc's;
      // leaving this orphaned isn't a leak (its rules gate on the now-gone
      // parent's ownerId), just clutter.
      await _permitDoc(id).delete().catchError((_) {});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Approved listings for a province — the traveler-facing "Local
  /// Businesses" read on `ProvinceDetailsScreen`.
  Future<List<Business>> getApprovedForProvince(String provinceId) async {
    try {
      final snapshot = await _collection
          .where('provinceId', isEqualTo: provinceId)
          .where('status', isEqualTo: 'approved')
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Every approved listing across the whole country, optionally narrowed
  /// to one province and/or [BusinessCategory] — backs Explore's
  /// "Businesses" tab. [status] must stay an equality filter for
  /// firestore.rules' `list` check to accept this query (same reasoning as
  /// [getApprovedForProvince]), so this always fetches everything matching
  /// in one shot rather than paginating.
  Future<List<Business>> getAllApproved({
    String? provinceId,
    String? category,
    int limit = 200,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _collection.where(
        'status',
        isEqualTo: 'approved',
      );
      if (provinceId != null)
        query = query.where('provinceId', isEqualTo: provinceId);
      if (category != null)
        query = query.where('category', isEqualTo: category);
      final snapshot = await query.limit(limit).get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
