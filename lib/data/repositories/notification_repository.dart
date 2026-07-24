import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/app_notification.dart';

/// Firestore access for the `notifications` collection. A notification with
/// an empty `userId` is a broadcast (festival announcements, travel tips,
/// featured destinations) shown to every signed-in user.
class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection(FirestorePaths.notifications);

  /// Personal notifications for [userId] plus every broadcast notification,
  /// merged and sorted newest-first.
  Stream<List<AppNotification>> streamForUser(String userId) {
    final personal = _collection.where('userId', isEqualTo: userId).snapshots();
    final broadcast = _collection.where('userId', isEqualTo: '').snapshots();

    return personal.asyncMap((personalSnapshot) async {
      final broadcastSnapshot = await broadcast.first;
      final all = [...personalSnapshot.docs, ...broadcastSnapshot.docs]
          .map((d) => AppNotification.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return all;
    });
  }

  Future<void> markAsRead(String id) async {
    try {
      await _collection.doc(id).update({'isRead': true});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Admin/LGU/eventOrganizer "Compose Announcement" — an empty [userId]
  /// makes this a broadcast every traveler's `streamForUser` picks up
  /// immediately. This only ever populates the in-app notification bell;
  /// it does not by itself deliver an OS-level push to a closed/backgrounded
  /// app — that's handled separately by the `sendPushOnNotificationCreated`
  /// Cloud Function, which reacts to this same write (confirmed firing via
  /// a direct Cloud Run instance-log check, not just a clean deploy).
  Future<void> createBroadcast({
    required String title,
    required String body,
    required NotificationCategory category,
  }) async {
    try {
      await _collection.add(
        AppNotification(id: '', userId: '', title: title, body: body, category: category, createdAt: DateTime.now()).toMap(),
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
