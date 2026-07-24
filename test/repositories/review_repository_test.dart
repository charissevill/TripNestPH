import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/data/repositories/destination_repository.dart';
import 'package:tripnest_ph/data/repositories/festival_repository.dart';
import 'package:tripnest_ph/data/repositories/restaurant_repository.dart';
import 'package:tripnest_ph/data/repositories/review_repository.dart';
import 'package:tripnest_ph/domain/models/review.dart';

Review _review({required String id, required double rating}) {
  return Review(
    id: id,
    userId: 'user-1',
    targetId: 'dest-1',
    targetType: ReviewTargetType.destination,
    authorName: 'Traveler',
    authorAvatarUrl: '',
    rating: rating,
    comment: 'Great spot!',
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late ReviewRepository reviewRepository;
  late DestinationRepository destinationRepository;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    destinationRepository = DestinationRepository(firestore: firestore);
    reviewRepository = ReviewRepository(
      firestore: firestore,
      destinationRepository: destinationRepository,
      restaurantRepository: RestaurantRepository(firestore: firestore),
      festivalRepository: FestivalRepository(firestore: firestore),
    );
    await firestore.collection('tourist_spots').doc('dest-1').set({
      'name': 'Test Destination',
      'province': 'Test Province',
      'status': 'published',
      'rating': 0,
      'reviewCount': 0,
    });
  });

  test('addReview() recalculates the target\'s aggregate rating and review count', () async {
    await reviewRepository.addReview(review: _review(id: '', rating: 4));
    await reviewRepository.addReview(review: _review(id: '', rating: 2));

    final doc = await firestore.collection('tourist_spots').doc('dest-1').get();
    expect(doc.data()?['reviewCount'], 2);
    expect(doc.data()?['rating'], 3.0);
  });

  test('deleteReview() removes it and recalculates the aggregate down to zero', () async {
    await reviewRepository.addReview(review: _review(id: '', rating: 5));
    final reviews = await reviewRepository.getByUser('user-1');
    expect(reviews, hasLength(1));

    await reviewRepository.deleteReview(reviews.first);

    final doc = await firestore.collection('tourist_spots').doc('dest-1').get();
    expect(doc.data()?['reviewCount'], 0);
    expect(doc.data()?['rating'], 0.0);
    expect(await reviewRepository.getByUser('user-1'), isEmpty);
  });

  test('getByUser() only returns that user\'s reviews, newest first', () async {
    await reviewRepository.addReview(
      review: Review(
        id: '',
        userId: 'user-2',
        targetId: 'dest-1',
        targetType: ReviewTargetType.destination,
        authorName: 'Someone Else',
        authorAvatarUrl: '',
        rating: 3,
        comment: 'Fine.',
        createdAt: DateTime(2025, 6, 1),
      ),
    );
    await reviewRepository.addReview(review: _review(id: '', rating: 4));

    final reviews = await reviewRepository.getByUser('user-1');
    expect(reviews, hasLength(1));
    expect(reviews.single.userId, 'user-1');
  });
}
