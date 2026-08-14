import 'package:cloud_firestore/cloud_firestore.dart';

/// What a notification is about, used to pick an icon and route on tap.
enum NotificationCategory {
  festival,
  travelTip,
  featuredDestination,
  general,
  maintenanceNotice,
  emergencyAlert,
}

NotificationCategory _categoryFromString(String value) {
  return NotificationCategory.values.firstWhere(
    (c) => c.name == value,
    orElse: () => NotificationCategory.general,
  );
}

/// Display label and Settings-toggleability for each category.
extension NotificationCategoryLabel on NotificationCategory {
  String get label {
    switch (this) {
      case NotificationCategory.festival:
        return 'Festival Announcements';
      case NotificationCategory.travelTip:
        return 'Travel Tips';
      case NotificationCategory.featuredDestination:
        return 'Featured Destinations';
      case NotificationCategory.general:
        return 'General';
      case NotificationCategory.maintenanceNotice:
        return 'Maintenance Notices';
      case NotificationCategory.emergencyAlert:
        return 'Emergency Alerts';
    }
  }

  /// Emergency alerts and maintenance notices are safety/service-critical —
  /// same reasoning phones use for not letting you disable OS-level
  /// emergency broadcasts — so Settings never offers a switch for them.
  bool get isUserToggleable {
    return this != NotificationCategory.emergencyAlert && this != NotificationCategory.maintenanceNotice;
  }
}

/// A push/in-app notification, persisted at `notifications/{id}`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    this.isRead = false,
    this.readBy = const [],
    this.relatedId,
    this.imageUrl = '',
  });

  final String id;

  /// Empty for a broadcast notification sent to every user.
  final String userId;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime createdAt;

  /// Read state for a *personal* notification (`userId` non-empty). Ignored
  /// for a broadcast, which has no single owner — see [readBy].
  final bool isRead;

  /// Read state for a *broadcast* notification (`userId == ''`): the uids of
  /// every traveler who's opened it. One shared doc has no single "read"
  /// flag to flip, since that would mark it read for every recipient at
  /// once — see [isReadBy].
  final List<String> readBy;

  /// The read state to actually show a given viewer — [isRead] for a
  /// personal notification, whether they're in [readBy] for a broadcast.
  bool isReadBy(String? uid) => userId.isEmpty ? readBy.contains(uid) : isRead;

  /// Id of the festival/destination this notification links to, if any.
  final String? relatedId;
  final String imageUrl;

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    final timestamp = map['createdAt'];
    return AppNotification(
      id: id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      category: _categoryFromString(map['category'] as String? ?? 'general'),
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      isRead: map['isRead'] as bool? ?? false,
      readBy: (map['readBy'] as List<dynamic>?)?.cast<String>() ?? const [],
      relatedId: map['relatedId'] as String?,
      imageUrl: map['imageUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'category': category.name,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': isRead,
      'relatedId': relatedId,
      'imageUrl': imageUrl,
    };
  }
}
