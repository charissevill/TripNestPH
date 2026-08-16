import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/review.dart';
import 'destination_repository.dart';
import 'festival_repository.dart';
import 'restaurant_repository.dart';

/// Firestore access for the `reviews` collection, plus the aggregate
/// rating/reviewCount recalculation on whichever listing a review targets.
class ReviewRepository {
  ReviewRepository({
    FirebaseFirestore? firestore,
    StorageService? storageService,
    DestinationRepository? destinationRepository,
    RestaurantRepository? restaurantRepository,
    FestivalRepository? festivalRepository,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storageOverride = storageService,
        _destinationRepository = destinationRepository ?? DestinationRepository(),
        _restaurantRepository = restaurantRepository ?? RestaurantRepository(),
        _festivalRepository = festivalRepository ?? FestivalRepository();

  final FirebaseFirestore _db;
  final DestinationRepository _destinationRepository;
  final RestaurantRepository _restaurantRepository;
  final FestivalRepository _festivalRepository;

  // Lazy: only reviews with photos ever touch Firebase Storage, so a plain
  // text-only review (or a test using a Firestore-only fake) never pays for
  // constructing it.
  final StorageService? _storageOverride;
  StorageService? _storageInstance;
  StorageService get _storage => _storageOverride ?? (_storageInstance ??= StorageService());

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection(FirestorePaths.reviews);

  /// One review per traveler per listing, enforced structurally rather than
  /// just by UI convention: the doc id is deterministic, so a second
  /// "Write a Review" for the same person+listing overwrites their existing
  /// review instead of creating a duplicate — the same pattern
  /// `FavoritesRepository` already uses for exactly this reason.
  String _docId({required String userId, required String targetId, required ReviewTargetType targetType}) =>
      '${userId}_${targetType.name}_$targetId';

  Stream<List<Review>> streamForTarget(String targetId, ReviewTargetType targetType) {
    return _collection
        .where('targetId', isEqualTo: targetId)
        .where('targetType', isEqualTo: targetType.name)
        .where('isHidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Review.fromMap(d.id, d.data())).toList());
  }

  /// Direct lookup by id, skipping the `isHidden` filter — used by the
  /// Admin Portal's moderation queue, which must be able to show an
  /// already-hidden review too.
  Future<Review?> getById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) return null;
      return Review.fromMap(doc.id, doc.data()!);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Review>> getByUser(String userId) async {
    try {
      final snapshot =
          await _collection.where('userId', isEqualTo: userId).orderBy('createdAt', descending: true).get();
      return snapshot.docs.map((d) => Review.fromMap(d.id, d.data())).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Creates this traveler's review for [review.targetId]. If they already
  /// have one (the deterministic id already exists — see [_docId]), this
  /// overwrites it in place instead of creating a duplicate; the review
  /// count only changes for a genuinely new review.
  Future<void> addReview({required Review review, List<File> photos = const []}) async {
    final id = _docId(userId: review.userId, targetId: review.targetId, targetType: review.targetType);
    try {
      final existing = await _collection.doc(id).get();
      var photoUrls = review.photoUrls;
      if (photos.isNotEmpty) {
        photoUrls = await _storage.uploadFiles(
          folder: FirestorePaths.storageReviewPhotos,
          ownerId: review.userId,
          files: photos,
        );
      }
      try {
        await _collection.doc(id).set(review.toMap()..['photoUrls'] = photoUrls);
      } catch (e) {
        // The photo(s) above already uploaded successfully — without this,
        // a failure right here (dropped connection, rules mismatch) would
        // leave them as permanently orphaned files with no Firestore doc
        // ever referencing them.
        if (photos.isNotEmpty) {
          for (final url in photoUrls) {
            await _storage.deleteByUrl(url);
          }
        }
        rethrow;
      }
      try {
        if (!existing.exists) {
          await _adjustReviewCount(review.targetId, review.targetType, 1);
        }
        await _recalculateRating(review.targetId, review.targetType);
      } catch (e) {
        // The listing itself was deleted between the traveler opening its
        // page and submitting this review — the review doc above already
        // wrote successfully, but it would be left as a permanently
        // orphaned record referencing a target that no longer exists. Roll
        // it back (only for a brand-new review — an edit to an existing one
        // stays in place) so the "something went wrong" this throws next
        // is actually true, instead of implying nothing was saved while a
        // ghost review sits unreachable in Firestore.
        if (!existing.exists) {
          await _collection.doc(id).delete();
        }
        rethrow;
      }
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Updates an existing review's rating/comment and (unlike before) its
  /// photos too: [keptPhotoUrls] is the subset of [review.photoUrls] the
  /// traveler chose to keep — anything removed gets deleted from Storage —
  /// and [newPhotos] are freshly picked files to upload and append.
  Future<void> updateReview(
    Review review, {
    List<String>? keptPhotoUrls,
    List<File> newPhotos = const [],
  }) async {
    try {
      final kept = keptPhotoUrls ?? review.photoUrls;
      final removed = review.photoUrls.where((url) => !kept.contains(url)).toList();
      var photoUrls = kept;
      List<String> uploaded = const [];
      if (newPhotos.isNotEmpty) {
        uploaded = await _storage.uploadFiles(
          folder: FirestorePaths.storageReviewPhotos,
          ownerId: review.userId,
          files: newPhotos,
        );
        photoUrls = [...kept, ...uploaded];
      }
      try {
        await _collection.doc(review.id).update({
          'rating': review.rating,
          'comment': review.comment,
          'photoUrls': photoUrls,
        });
      } catch (e) {
        // Same reasoning as addReview: the new photo(s) already uploaded
        // successfully, so a failure right here would otherwise orphan them
        // with nothing ever pointing back at them.
        for (final url in uploaded) {
          await _storage.deleteByUrl(url);
        }
        rethrow;
      }
      for (final url in removed) {
        await _storage.deleteByUrl(url);
      }
      await _recalculateRating(review.targetId, review.targetType);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Admin moderation: hide (or restore) a review — matches
  /// `firestore.rules`'s admin-only `onlyChangedFields(['isHidden'])`
  /// branch. Recalculates the target's aggregate rating either way, since
  /// a hidden review no longer counts toward it.
  Future<void> setHidden(Review review, bool hidden) async {
    try {
      await _collection.doc(review.id).update({'isHidden': hidden});
      // Only adjust the count on an actual state change — guards against a
      // caller re-hiding an already-hidden review (or restoring an
      // already-visible one) double-counting.
      if (review.isHidden != hidden) {
        await _adjustReviewCount(review.targetId, review.targetType, hidden ? -1 : 1);
      }
      await _recalculateRating(review.targetId, review.targetType);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Sets (or edits) the restaurant owner's public reply to [review].
  /// Firestore rules restrict this write to the uid on `restaurants/
  /// {review.targetId}.ownerId`, and to exactly these two fields — matches
  /// the `onlyChangedFields(['ownerReply', 'ownerRepliedAt'])` branch there.
  Future<void> setOwnerReply(Review review, String replyText) async {
    try {
      await _collection.doc(review.id).update({
        'ownerReply': replyText.trim(),
        'ownerRepliedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> deleteReview(Review review) async {
    try {
      await _collection.doc(review.id).delete();
      for (final url in review.photoUrls) {
        await _storage.deleteByUrl(url);
      }
      // A hidden review was never counted in the first place — deleting it
      // shouldn't double-decrement.
      if (!review.isHidden) {
        await _adjustReviewCount(review.targetId, review.targetType, -1);
      }
      await _recalculateRating(review.targetId, review.targetType);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Removes every review left on [targetId] — admin cleanup when the
  /// listing itself is deleted (see AdminBusinessListScreen), so its
  /// reviews don't survive as dangling records referencing an id that no
  /// longer resolves to anything (previously surfaced only defensively,
  /// e.g. the moderation queue's "This review no longer exists"). No
  /// aggregate recalculation needed after — the target document is gone
  /// too.
  Future<void> deleteAllForTarget(String targetId, ReviewTargetType targetType) async {
    try {
      final snapshot = await _collection
          .where('targetId', isEqualTo: targetId)
          .where('targetType', isEqualTo: targetType.name)
          .get();
      for (final doc in snapshot.docs) {
        final review = Review.fromMap(doc.id, doc.data());
        for (final url in review.photoUrls) {
          await _storage.deleteByUrl(url);
        }
      }
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Atomic, race-free regardless of how many reviews are being added/
  /// removed/hidden for this listing at once — `FieldValue.increment` is
  /// applied server-side, so two simultaneous calls always both land
  /// instead of the read-then-write recalculation this replaced, where one
  /// could silently clobber the other and leave the count permanently
  /// wrong. Self-migrating: works correctly against existing documents that
  /// already carry a real `reviewCount`, no backfill needed.
  Future<void> _adjustReviewCount(String targetId, ReviewTargetType targetType, int delta) async {
    switch (targetType) {
      case ReviewTargetType.destination:
        await _destinationRepository.adjustReviewCount(targetId, delta);
      case ReviewTargetType.restaurant:
        await _restaurantRepository.adjustReviewCount(targetId, delta);
      case ReviewTargetType.festival:
        await _festivalRepository.adjustReviewCount(targetId, delta);
    }
  }

  /// The average itself still comes from a fresh read of every current
  /// non-hidden review — Firestore's client SDK can't run this as a query
  /// inside a transaction, so it can very briefly lag under concurrent
  /// writes. Unlike `reviewCount` (now atomic, see [_adjustReviewCount]),
  /// that's a self-correcting, sub-decimal display value rather than a
  /// permanently wrong number of reviews.
  Future<void> _recalculateRating(String targetId, ReviewTargetType targetType) async {
    final snapshot = await _collection
        .where('targetId', isEqualTo: targetId)
        .where('targetType', isEqualTo: targetType.name)
        .where('isHidden', isEqualTo: false)
        .get();
    final ratings = snapshot.docs.map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0).toList();
    final count = ratings.length;
    final average = count == 0 ? 0.0 : ratings.reduce((a, b) => a + b) / count;
    final rounded = double.parse(average.toStringAsFixed(1));

    switch (targetType) {
      case ReviewTargetType.destination:
        await _destinationRepository.updateAggregateRating(targetId, rating: rounded);
      case ReviewTargetType.restaurant:
        await _restaurantRepository.updateAggregateRating(targetId, rating: rounded);
      case ReviewTargetType.festival:
        await _festivalRepository.updateAggregateRating(targetId, rating: rounded);
    }
  }
}
