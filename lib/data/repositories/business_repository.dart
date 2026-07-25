import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/business.dart';

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

  /// Every listing owned by [uid] — a business owner can have more than one.
  Stream<List<Business>> streamForOwner(String uid) {
    return _collection
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  Future<String> create(Business business) async {
    try {
      final doc = await _collection.add({
        ...business.toInfoMap(),
        'ownerId': business.ownerId,
        'status': 'pending',
        'rejectionReason': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
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
  Stream<List<Business>> streamAllForAdmin() {
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
}
