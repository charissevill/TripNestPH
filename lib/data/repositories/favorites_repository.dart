import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/favorite_collection.dart';
import '../../domain/models/place.dart';

/// Which kind of listing a favorite points at.
enum FavoriteType { destination, restaurant, festival, place }

/// One favorite doc's type/id/collection membership — enough for
/// [SavedScreen] to filter each tab by the selected [FavoriteCollection]
/// without needing the item's full hydrated data (that still comes from
/// [FavoritesProvider]/each type's own repository, same as before this
/// existed).
class FavoriteDoc {
  const FavoriteDoc({required this.type, required this.itemId, this.collectionId});

  final FavoriteType type;
  final String itemId;
  final String? collectionId;
}

/// Firestore access for the `favorites` collection. One document per
/// (user, type, item) with a deterministic id so toggling is idempotent.
class FavoritesRepository {
  FavoritesRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection(FirestorePaths.favorites);
  CollectionReference<Map<String, dynamic>> get _collectionsRef => _db.collection(FirestorePaths.favoriteCollections);

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

  /// Streams every favorite doc's type/id/collection membership for
  /// [userId] — the richer sibling of [streamFavorites], used only by
  /// [SavedScreen] to filter by [FavoriteCollection] (everywhere else in
  /// the app just needs the simple "is this saved" membership check
  /// [streamFavorites] already provides).
  Stream<List<FavoriteDoc>> streamFavoriteDocs(String userId) {
    return _collection.where('userId', isEqualTo: userId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final type = FavoriteType.values.firstWhere(
          (t) => t.name == data['itemType'],
          orElse: () => FavoriteType.destination,
        );
        return FavoriteDoc(type: type, itemId: data['itemId'] as String, collectionId: data['collectionId'] as String?);
      }).toList();
    });
  }

  /// Assigns (or clears, via `null`) which [FavoriteCollection] this
  /// already-saved item belongs to — the item must already be favorited;
  /// this only ever changes the `collectionId` field, matching
  /// `firestore.rules`'s `onlyChangedFields(['collectionId'])` branch.
  Future<void> setCollection(String userId, FavoriteType type, String itemId, String? collectionId) async {
    try {
      await _collection.doc(_docId(userId, type, itemId)).update({'collectionId': collectionId});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Stream<List<FavoriteCollection>> streamCollections(String userId) {
    return _collectionsRef.where('userId', isEqualTo: userId).orderBy('createdAt').snapshots().map(
      (s) => s.docs.map((d) => FavoriteCollection.fromMap(d.id, d.data())).toList(),
    );
  }

  Future<String> createCollection(String userId, String name) async {
    try {
      final doc = await _collectionsRef.add(
        FavoriteCollection(id: '', userId: userId, name: name, createdAt: DateTime.now()).toMap(),
      );
      return doc.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> renameCollection(String collectionId, String name) async {
    try {
      await _collectionsRef.doc(collectionId).update({'name': name});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Deletes the collection itself and un-assigns it from every favorite
  /// that pointed at it — otherwise those favorites would carry a
  /// `collectionId` referencing a doc that no longer exists, the same
  /// dangling-reference problem this app's other delete flows already
  /// guard against (see e.g. `AdminBusinessListScreen._delete`).
  Future<void> deleteCollection(String userId, String collectionId) async {
    try {
      final orphaned = await _collection
          .where('userId', isEqualTo: userId)
          .where('collectionId', isEqualTo: collectionId)
          .get();
      final batch = _db.batch();
      for (final doc in orphaned.docs) {
        batch.update(doc.reference, {'collectionId': null});
      }
      batch.delete(_collectionsRef.doc(collectionId));
      await batch.commit();
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

  /// Removes every favorite (and named collection) [userId] has — part of
  /// the account-deletion flow, so nothing is left pointing at a deleted
  /// account.
  Future<void> deleteAllForUser(String userId) async {
    try {
      final favorites = await _collection.where('userId', isEqualTo: userId).get();
      final collections = await _collectionsRef.where('userId', isEqualTo: userId).get();
      final batch = _db.batch();
      for (final doc in favorites.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in collections.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Removes every traveler's favorite pointing at [itemId] — admin cleanup
  /// when a listing itself is deleted (see AdminBusinessListScreen), so
  /// those favorites don't become permanently dangling references to an id
  /// that no longer resolves to anything.
  Future<void> deleteAllForItem(FavoriteType type, String itemId) async {
    try {
      final snapshot = await _collection.where('itemType', isEqualTo: type.name).where('itemId', isEqualTo: itemId).get();
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
