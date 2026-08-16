import 'package:cloud_firestore/cloud_firestore.dart';

/// Which kind of listing a [ContentReport] points at — the same three
/// browsable target types as [ReviewTargetType], kept as a separate enum
/// since a content report and a review report are otherwise unrelated data.
enum ContentTargetType { destination, restaurant, festival }

ContentTargetType contentTargetTypeFromString(String value) {
  return ContentTargetType.values.firstWhere((t) => t.name == value, orElse: () => ContentTargetType.destination);
}

/// A traveler's flag on a destination/restaurant/festival listing itself —
/// wrong info, permanently closed, an inappropriate photo — as opposed to
/// [ReviewReport], which flags a specific review. Backed by the
/// `content_reports` Firestore collection; same immutable-once-filed,
/// admin-clears-by-deleting shape.
class ContentReport {
  const ContentReport({
    required this.id,
    required this.targetId,
    required this.targetType,
    required this.userId,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String targetId;
  final ContentTargetType targetType;
  final String userId;

  /// One of [ContentReportReason]'s values.
  final String reason;
  final DateTime createdAt;

  factory ContentReport.fromMap(String id, Map<String, dynamic> map) {
    final timestamp = map['createdAt'];
    return ContentReport(
      id: id,
      targetId: map['targetId'] as String? ?? '',
      targetType: contentTargetTypeFromString(map['targetType'] as String? ?? 'destination'),
      userId: map['userId'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetId': targetId,
      'targetType': targetType.name,
      'userId': userId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class ContentReportReason {
  ContentReportReason._();

  static const String outdated = 'outdated';
  static const String closed = 'closed';
  static const String inappropriatePhoto = 'inappropriatePhoto';
  static const String other = 'other';

  static const List<String> all = [outdated, closed, inappropriatePhoto, other];

  static String label(String reason) {
    switch (reason) {
      case outdated:
        return 'Info is outdated or wrong';
      case closed:
        return 'Permanently closed';
      case inappropriatePhoto:
        return 'Inappropriate photo';
      default:
        return 'Something else';
    }
  }
}
