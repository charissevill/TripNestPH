import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/app_notification.dart';

/// Firestore access for the `notifications` collection. A notification with
/// an empty `userId` is a broadcast (festival announcements, travel tips,
/// featured destinations) shown to every signed-in user.
class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection(FirestorePaths.notifications);

  /// Personal notifications for [userId] plus every broadcast notification,
  /// merged and sorted newest-first.
  Stream<List<AppNotification>> streamForUser(String userId) {
    final personal = _collection.where('userId', isEqualTo: userId).snapshots();
    final broadcast = _collection.where('userId', isEqualTo: '').snapshots();

    return personal.asyncMap((personalSnapshot) async {
      final broadcastSnapshot = await broadcast.first;
      final all =
          [
              ...personalSnapshot.docs,
              ...broadcastSnapshot.docs,
            ].map((d) => AppNotification.fromMap(d.id, d.data())).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return all;
    });
  }

  /// Marks [notification] read for [uid]. A broadcast (empty `userId`) has
  /// no single owner, so this appends [uid] to a shared `readBy` array
  /// instead of flipping `isRead` — otherwise the first traveler to open a
  /// festival announcement would mark it read for every other traveler too.
  Future<void> markAsRead(AppNotification notification, String uid) async {
    try {
      if (notification.userId.isEmpty) {
        await _collection.doc(notification.id).update({
          'readBy': FieldValue.arrayUnion([uid]),
        });
      } else {
        await _collection.doc(notification.id).update({'isRead': true});
      }
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Admin/LGU "Compose Announcement" — an empty [userId]
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
        AppNotification(
          id: '',
          userId: '',
          title: title,
          body: body,
          category: category,
          createdAt: DateTime.now(),
        ).toMap(),
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Deletes every *personal* notification [userId] owns — part of account
  /// deletion. Broadcasts are never touched here: they belong to no single
  /// user and stay visible to everyone else.
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

  /// A notification aimed at exactly one traveler — e.g. "your business
  /// listing was approved" — rather than [createBroadcast]'s every-user
  /// send. `firestore.rules` only lets an 'admin' account write a non-empty
  /// `userId` here (not 'lgu', which only ever sends broadcasts).
  Future<void> createForUser({
    required String userId,
    required String title,
    required String body,
    required NotificationCategory category,
    String? relatedId,
  }) async {
    try {
      await _collection.add(
        AppNotification(
          id: '',
          userId: userId,
          title: title,
          body: body,
          category: category,
          createdAt: DateTime.now(),
          relatedId: relatedId,
        ).toMap(),
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
