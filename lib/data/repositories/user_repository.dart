import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/destination.dart';
import 'destination_repository.dart';

/// Firestore CRUD for the `users/{uid}` profile document and the
/// `recently_viewed` subcollection backing "Recently Viewed Destinations".
class UserRepository {
  UserRepository({
    FirebaseFirestore? firestore,
    DestinationRepository? destinationRepository,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _destinationRepository =
           destinationRepository ?? DestinationRepository();

  final FirebaseFirestore _db;
  final DestinationRepository _destinationRepository;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(FirestorePaths.users);

  /// Total traveler accounts — the Admin Portal analytics dashboard's
  /// traveler-count stat. A `count()` aggregation, not a full fetch.
  Future<int> countAll() async {
    try {
      final result = await _users.count().get();
      return result.count ?? 0;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<int> countByStatus(String status) async {
    try {
      final result = await _users
          .where('status', isEqualTo: status)
          .count()
          .get();
      return result.count ?? 0;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// A page of every traveler, newest-first — the Admin Portal's User
  /// Management list. Matches `DestinationRepository.getPage`'s shape.
  Future<
    ({List<AppUser> items, DocumentSnapshot<Map<String, dynamic>>? lastDoc})
  >
  getPage({
    int pageSize = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    try {
      // A documentId tiebreaker keeps pagination stable even when two
      // accounts share the exact same `createdAt` (e.g. both created via
      // `FieldValue.serverTimestamp()` in the same request) — without it,
      // `startAfterDocument` can't reliably tell which of a tied pair it's
      // resuming after.
      var query = _users
          .orderBy('createdAt', descending: true)
          .orderBy(FieldPath.documentId);
      // `startAfterDocument` must be chained before `limit` — real
      // Firestore doesn't care about builder call order, but
      // `fake_cloud_firestore` (this repository's test double) silently
      // returns zero results for a second page if `limit` comes first.
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      query = query.limit(pageSize);
      final snapshot = await query.get();
      return (
        items: snapshot.docs
            .map((d) => AppUser.fromMap(d.id, d.data()))
            .toList(),
        lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Server-side prefix match on email — the Admin Portal's search box
  /// otherwise only ever filtered whatever page had already been scrolled
  /// into `_users` locally, so searching for a traveler beyond the first
  /// `pageSize` accounts silently returned "No matches" even though the
  /// account genuinely exists. Case-sensitive (Firestore range queries
  /// can't do case-insensitive matching without a separate lowercased
  /// field this collection doesn't have), so the caller should lowercase
  /// [prefix] to match how email is normally typed/stored.
  Future<List<AppUser>> searchByEmailPrefix(String prefix, {int limit = 20}) async {
    if (prefix.isEmpty) return const [];
    try {
      final snapshot = await _users
          .orderBy('email')
          .startAt([prefix])
          .endAt(['$prefix'])
          .limit(limit)
          .get();
      return snapshot.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Admin Portal suspend/activate — matches `firestore.rules`'s
  /// admin-write permission on `users` exactly (status only, never any
  /// other field alongside it).
  Future<void> setStatus(String uid, String status) async {
    try {
      await _users.doc(uid).update({'status': status});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> createIfMissing({
    required String uid,
    required String name,
    required String email,
    String photoUrl = '',
  }) async {
    try {
      final doc = _users.doc(uid);
      final snapshot = await doc.get();
      if (snapshot.exists) return;
      await doc.set({
        ...AppUser(
          uid: uid,
          name: name,
          email: email,
          photoUrl: photoUrl,
        ).toMap(),
        // `AppUser.toMap()` deliberately omits `status` (so a normal profile
        // update never touches it) — but that means without writing it
        // explicitly here, a never-suspended account has no `status` field
        // at all, and Firestore's `where('status', isEqualTo: ...)` never
        // matches a missing field. Written once, at creation, so every
        // account is queryable by status from day one.
        'status': 'active',
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
    return _users
        .doc(uid)
        .snapshots()
        .map((s) => s.exists ? AppUser.fromMap(uid, s.data()!) : null);
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> fields) async {
    try {
      await _users.doc(uid).set(fields, SetOptions(merge: true));
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Doc count above which older entries get pruned — well above the 10
  /// ever actually displayed ([recentlyViewedDestinations]'s `limit`), just
  /// enough slack that pruning doesn't run on every single view.
  static const int _maxRecentlyViewed = 30;

  Future<void> recordRecentlyViewed(String uid, String destinationId) async {
    try {
      final collection = _users.doc(uid).collection(FirestorePaths.recentlyViewed);
      await collection.doc(destinationId).set({'viewedAt': FieldValue.serverTimestamp()});
      // Otherwise this subcollection grows forever — nothing ever pruned
      // it, since reads already cap at 10 and never surfaced the problem.
      final snapshot = await collection.orderBy('viewedAt', descending: true).get();
      if (snapshot.docs.length > _maxRecentlyViewed) {
        final batch = _db.batch();
        for (final doc in snapshot.docs.skip(_maxRecentlyViewed)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      // Recently-viewed tracking is best-effort; never block navigation on it.
    }
  }

  /// The user's most recently viewed destinations, newest first.
  Future<List<Destination>> recentlyViewedDestinations(
    String uid, {
    int limit = 10,
  }) async {
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
      final snapshot = await _users
          .doc(uid)
          .collection(FirestorePaths.recentlyViewed)
          .get();
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
  Future<void> recordVisit({
    required String uid,
    required String targetType,
    required String targetId,
  }) async {
    try {
      await _users
          .doc(uid)
          .collection(FirestorePaths.visited)
          .doc('${targetType}_$targetId')
          .set({
            'targetType': targetType,
            'targetId': targetId,
            'viewedAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {
      // Best-effort; see doc comment above.
    }
  }

  Future<bool> hasVisited({
    required String uid,
    required String targetType,
    required String targetId,
  }) async {
    try {
      final doc = await _users
          .doc(uid)
          .collection(FirestorePaths.visited)
          .doc('${targetType}_$targetId')
          .get();
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
      final visited = await _users
          .doc(uid)
          .collection(FirestorePaths.visited)
          .get();
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
