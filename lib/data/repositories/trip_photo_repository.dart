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
}
