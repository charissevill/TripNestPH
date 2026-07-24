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

  Future<void> addReview({required Review review, List<File> photos = const []}) async {
    try {
      var photoUrls = review.photoUrls;
      if (photos.isNotEmpty) {
        photoUrls = await _storage.uploadFiles(
          folder: FirestorePaths.storageReviewPhotos,
          ownerId: review.userId,
          files: photos,
        );
      }
      await _collection.add(review.toMap()..['photoUrls'] = photoUrls);
      await _recalculateAggregate(review.targetId, review.targetType);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> updateReview(Review review) async {
    try {
      await _collection.doc(review.id).update({
        'rating': review.rating,
        'comment': review.comment,
        'photoUrls': review.photoUrls,
      });
      await _recalculateAggregate(review.targetId, review.targetType);
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
      await _recalculateAggregate(review.targetId, review.targetType);
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
      await _recalculateAggregate(review.targetId, review.targetType);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> _recalculateAggregate(String targetId, ReviewTargetType targetType) async {
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
        await _destinationRepository.updateAggregateRating(targetId, rating: rounded, reviewCount: count);
      case ReviewTargetType.restaurant:
        await _restaurantRepository.updateAggregateRating(targetId, rating: rounded, reviewCount: count);
      case ReviewTargetType.festival:
        await _festivalRepository.updateAggregateRating(targetId, rating: rounded, reviewCount: count);
    }
  }
}
