import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/destination.dart';
import 'destination_repository.dart';

/// Firestore CRUD for the `users/{uid}` profile document and the
/// `recently_viewed` subcollection backing "Recently Viewed Destinations".
class UserRepository {
  UserRepository({FirebaseFirestore? firestore, DestinationRepository? destinationRepository})
      : _db = firestore ?? FirebaseFirestore.instance,
        _destinationRepository = destinationRepository ?? DestinationRepository();

  final FirebaseFirestore _db;
  final DestinationRepository _destinationRepository;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection(FirestorePaths.users);

  Future<void> createIfMissing({required String uid, required String name, required String email, String photoUrl = ''}) async {
    try {
      final doc = _users.doc(uid);
      final snapshot = await doc.get();
      if (snapshot.exists) return;
      await doc.set({
        ...AppUser(uid: uid, name: name, email: email, photoUrl: photoUrl).toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<AppUser?> getUser(String uid) async {
    try {
      final snapshot = await _users.doc(uid).get();
      if (!snapshot.exists) return null;
      return AppUser.fromMap(uid, snapshot.data()!);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Stream<AppUser?> streamUser(String uid) {
    return _users.doc(uid).snapshots().map((s) => s.exists ? AppUser.fromMap(uid, s.data()!) : null);
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> fields) async {
    try {
      await _users.doc(uid).set(fields, SetOptions(merge: true));
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> recordRecentlyViewed(String uid, String destinationId) async {
    try {
      await _users
          .doc(uid)
          .collection(FirestorePaths.recentlyViewed)
          .doc(destinationId)
          .set({'viewedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      // Recently-viewed tracking is best-effort; never block navigation on it.
    }
  }

  /// The user's most recently viewed destinations, newest first.
  Future<List<Destination>> recentlyViewedDestinations(String uid, {int limit = 10}) async {
    try {
      final snapshot = await _users
          .doc(uid)
          .collection(FirestorePaths.recentlyViewed)
          .orderBy('viewedAt', descending: true)
          .limit(limit)
          .get();
      final ids = snapshot.docs.map((d) => d.id).toList();
      if (ids.isEmpty) return [];
      return _destinationRepository.getByIds(ids);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Wipes the "Recently Viewed" history — the Settings "Clear Recently
  /// Viewed" action, and also used as a step of account deletion.
  Future<void> clearRecentlyViewed(String uid) async {
    try {
      final snapshot = await _users.doc(uid).collection(FirestorePaths.recentlyViewed).get();
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Records that [uid] opened a listing's Details screen — the "been
  /// there" signal behind a review's Verified Visit badge (see
  /// [hasVisited]). Deliberately separate from "Recently Viewed": that
  /// history is user-clearable for privacy, but a review's verified badge
  /// must stay accurate even after it's cleared, since it's stamped once at
  /// review-creation time and never rechecked. Best-effort — a tracking
  /// write failing should never block viewing the page itself.
  Future<void> recordVisit({required String uid, required String targetType, required String targetId}) async {
    try {
      await _users.doc(uid).collection(FirestorePaths.visited).doc('${targetType}_$targetId').set({
        'targetType': targetType,
        'targetId': targetId,
        'viewedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Best-effort; see doc comment above.
    }
  }

  Future<bool> hasVisited({required String uid, required String targetType, required String targetId}) async {
    try {
      final doc = await _users.doc(uid).collection(FirestorePaths.visited).doc('${targetType}_$targetId').get();
      return doc.exists;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Removes the profile document, its recently-viewed history and its
  /// visited-listing records — the Firestore side of account deletion. The
  /// Firebase Auth user itself is deleted separately by
  /// [AuthService.deleteAccount].
  Future<void> deleteAccountData(String uid) async {
    try {
      await clearRecentlyViewed(uid);
      final visited = await _users.doc(uid).collection(FirestorePaths.visited).get();
      final batch = _db.batch();
      for (final doc in visited.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      await _users.doc(uid).delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
