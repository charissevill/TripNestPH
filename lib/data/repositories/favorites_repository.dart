import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';

/// Which kind of listing a favorite points at.
enum FavoriteType { destination, restaurant, festival }

/// Firestore access for the `favorites` collection. One document per
/// (user, type, item) with a deterministic id so toggling is idempotent.
class FavoritesRepository {
  FavoritesRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection(FirestorePaths.favorites);

  String _docId(String userId, FavoriteType type, String itemId) => '${userId}_${type.name}_$itemId';

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

  Future<void> add(String userId, FavoriteType type, String itemId) async {
    try {
      await _collection.doc(_docId(userId, type, itemId)).set({
        'userId': userId,
        'itemType': type.name,
        'itemId': itemId,
        'createdAt': FieldValue.serverTimestamp(),
      });
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
