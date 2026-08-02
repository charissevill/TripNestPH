import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/place.dart';

/// Which kind of listing a favorite points at.
enum FavoriteType { destination, restaurant, festival, place }

/// Firestore access for the `favorites` collection. One document per
/// (user, type, item) with a deterministic id so toggling is idempotent.
class FavoritesRepository {
  FavoritesRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection(FirestorePaths.favorites);

  /// A Google Places id (e.g. `places/ChIJ...`, used for [FavoriteType.place])
  /// contains a literal `/` — left as-is, that slash would make Firestore
  /// treat this composite id as a multi-segment relative path instead of a
  /// single flat document id, silently writing outside the `favorites`
  /// collection entirely (so `streamFavorites`/`streamSavedPlaces`'s
  /// same-collection queries would never find it again). Replacing it keeps
  /// the id flat; destination/restaurant/festival ids never contained a
  /// slash to begin with, so this is a no-op for them.
  String _docId(String userId, FavoriteType type, String itemId) =>
      '${userId}_${type.name}_${itemId.replaceAll('/', '_')}';

  /// Streams every favorite doc for [userId], grouped by type.
  Stream<Map<FavoriteType, Set<String>>> streamFavorites(String userId) {
    return _collection.where('userId', isEqualTo: userId).snapshots().map((snapshot) {
      final result = {for (final t in FavoriteType.values) t: <String>{}};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final type = FavoriteType.values.firstWhere(
          (t) => t.name == data['itemType'],
          orElse: () => FavoriteType.destination,
        );
        result[type]!.add(data['itemId'] as String);
      }
      return result;
    });
  }

  /// [snapshot] is only ever passed for [FavoriteType.place] — a live
  /// Google Places result is never persisted to Firestore anywhere else, so
  /// there's no collection to re-fetch a saved one from later; this stores
  /// the place's own data (see [Place.toJson]) directly on its favorite doc
  /// instead. Every other type only needs the plain id (destination/
  /// restaurant/festival all have their own Firestore collection to
  /// re-resolve against).
  Future<void> add(String userId, FavoriteType type, String itemId, {Map<String, dynamic>? snapshot}) async {
    try {
      await _collection.doc(_docId(userId, type, itemId)).set({
        ...?snapshot,
        'userId': userId,
        'itemType': type.name,
        'itemId': itemId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Streams every saved [FavoriteType.place] favorite for [userId], fully
  /// hydrated straight from each doc's stored snapshot — no other
  /// collection to look these up against, unlike [streamFavorites]'s three
  /// other types.
  Stream<List<Place>> streamSavedPlaces(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .where('itemType', isEqualTo: FavoriteType.place.name)
        .snapshots()
        // `Place.toJson()`'s flat shape matches `fromCacheJson`'s expected
        // input, not `fromJson`'s (which expects Google's raw nested API
        // response shape — `displayName`/`location`/`photos`/etc.).
        .map((snapshot) => snapshot.docs.map((doc) => Place.fromCacheJson(doc.data())).toList());
  }

  /// How many travelers have favorited [itemId] — requires reading other
  /// users' favorite docs, which `firestore.rules` only grants to an
  /// active Admin Portal account of any role (see the `favorites` match
  /// block's `isActiveAdmin()` branch), not a plain traveler.
  Future<int> countForItem(FavoriteType type, String itemId) async {
    try {
      final snapshot = await _collection
          .where('itemType', isEqualTo: type.name)
          .where('itemId', isEqualTo: itemId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> remove(String userId, FavoriteType type, String itemId) async {
    try {
      await _collection.doc(_docId(userId, type, itemId)).delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Removes every favorite [userId] has — part of the account-deletion
  /// flow, so no orphaned favorites are left pointing at a deleted account.
  Future<void> deleteAllForUser(String userId) async {
    try {
      final snapshot = await _collection.where('userId', isEqualTo: userId).get();
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
