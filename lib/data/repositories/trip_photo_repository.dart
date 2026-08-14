import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/trip_photo.dart';

/// Firestore access for the `trip_photos` collection backing "My Photos" —
/// a top-level collection keyed by a `userId` field (same shape as
/// `FavoritesRepository`), not a `users/{uid}` subcollection: these are rich
/// records worth querying/paginating on their own, not simple existence
/// markers like `recently_viewed`/`visited`.
class TripPhotoRepository {
  TripPhotoRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection(FirestorePaths.tripPhotos);

  Future<String> create(TripPhoto photo) async {
    try {
      final doc = await _collection.add(photo.toMap());
      return doc.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Every photo [userId] has uploaded, newest-taken first (falling back to
  /// upload time for photos with no EXIF capture date) — streamed so the
  /// grid updates live as new photos are added.
  Stream<List<TripPhoto>> streamForUser(String userId) {
    return _collection.where('userId', isEqualTo: userId).snapshots().map((snapshot) {
      final photos = snapshot.docs.map((d) => TripPhoto.fromMap(d.id, d.data())).toList();
      photos.sort((a, b) => (b.takenAt ?? b.createdAt).compareTo(a.takenAt ?? a.createdAt));
      return photos;
    });
  }

  Future<void> delete(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Every photo doc [userId] owns — the caller is responsible for also
  /// deleting each [TripPhoto.photoUrl] from Storage (see
  /// `AuthProvider.deleteAccount`), since this repository has no Storage
  /// access of its own.
  Future<List<TripPhoto>> getAllForUser(String userId) async {
    try {
      final snapshot = await _collection.where('userId', isEqualTo: userId).get();
      return snapshot.docs.map((d) => TripPhoto.fromMap(d.id, d.data())).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Deletes every photo doc [userId] owns — part of account deletion. Does
  /// NOT touch Storage; callers that also need the underlying files removed
  /// should use [getAllForUser] first and delete each [TripPhoto.photoUrl]
  /// via `StorageService.deleteByUrl`.
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
