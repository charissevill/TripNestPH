import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// What kind of listing a [Review] was written for.
enum ReviewTargetType { destination, restaurant, festival }

ReviewTargetType reviewTargetTypeFromString(String value) {
  return ReviewTargetType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => ReviewTargetType.destination,
  );
}

/// A single traveler review left on a destination, restaurant or festival.
/// Backed by the `reviews` Firestore collection.
class Review {
  const Review({
    required this.id,
    required this.userId,
    required this.targetId,
    required this.targetType,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.photoUrls = const [],
    this.isHidden = false,
    this.verified = false,
  });

  final String id;
  final String userId;
  final String targetId;
  final ReviewTargetType targetType;
  final String authorName;
  final String authorAvatarUrl;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final List<String> photoUrls;

  /// Set by the Admin Portal's moderation tools — hidden reviews stay in
  /// Firestore (so they can be reviewed/restored) but never show to
  /// travelers and never count toward the target's aggregate rating.
  final bool isHidden;

  /// Whether the reviewer had opened this listing's Details screen at least
  /// once before writing this review (see [UserRepository.hasVisited]).
  /// Stamped once at creation time and never rechecked — clearing "Recently
  /// Viewed" history afterward doesn't retroactively unverify a review.
  /// Badge-only: an unverified review is exactly as valid and visible as a
  /// verified one, just without the "Verified Visit" label.
  final bool verified;

  /// Human-readable relative-ish date, e.g. "March 2026", matching the copy
  /// style used throughout the rest of the app.
  String get date => DateFormat.yMMMM().format(createdAt);

  factory Review.fromMap(String id, Map<String, dynamic> map) {
    final timestamp = map['createdAt'];
    return Review(
      id: id,
      userId: map['userId'] as String? ?? '',
      targetId: map['targetId'] as String? ?? '',
      targetType: reviewTargetTypeFromString(map['targetType'] as String? ?? 'destination'),
      authorName: map['authorName'] as String? ?? 'Traveler',
      authorAvatarUrl: map['authorAvatarUrl'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      comment: map['comment'] as String? ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      photoUrls: List<String>.from(map['photoUrls'] as List? ?? const []),
      isHidden: map['isHidden'] as bool? ?? false,
      verified: map['verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'targetId': targetId,
      'targetType': targetType.name,
      'authorName': authorName,
      'authorAvatarUrl': authorAvatarUrl,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
      'photoUrls': photoUrls,
      // Explicit (not just defaulted on read) so the mobile app's
      // `isHidden == false` display query — which can't match a document
      // where the field is simply absent — always finds new reviews.
      'isHidden': isHidden,
      'verified': verified,
    };
  }
}
