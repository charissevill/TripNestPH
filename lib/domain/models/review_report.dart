import 'package:cloud_firestore/cloud_firestore.dart';

/// A traveler's flag on a review, for the Admin Portal's moderation queue.
/// Backed by the `review_reports` Firestore collection — immutable once
/// filed (see `firestore.rules`); an admin clears it by deleting it after
/// acting (or not acting) on the underlying review.
class ReviewReport {
  const ReviewReport({
    required this.id,
    required this.reviewId,
    required this.userId,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String reviewId;
  final String userId;

  /// One of [ReportReason]'s values.
  final String reason;
  final DateTime createdAt;

  factory ReviewReport.fromMap(String id, Map<String, dynamic> map) {
    final timestamp = map['createdAt'];
    return ReviewReport(
      id: id,
      reviewId: map['reviewId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reviewId': reviewId,
      'userId': userId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class ReportReason {
  ReportReason._();

  static const String spam = 'spam';
  static const String inappropriate = 'inappropriate';
  static const String fake = 'fake';
  static const String other = 'other';

  static const List<String> all = [spam, inappropriate, fake, other];

  static String label(String reason) {
    switch (reason) {
      case spam:
        return 'Spam or advertising';
      case inappropriate:
        return 'Inappropriate or offensive';
      case fake:
        return "Fake — doesn't seem like a real visit";
      default:
        return 'Something else';
    }
  }
}
