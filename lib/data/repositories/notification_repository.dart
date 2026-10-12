import 'dart:async';

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

  /// Personal notifications for [userId] plus every broadcast notification
  /// they haven't deleted (see [delete]), merged and sorted newest-first.
  /// Either side updating in real time refreshes the merged list — a
  /// broadcast being marked read or deleted only ever touches the broadcast
  /// query, so that one has to be listened to rather than read once. Waits
  /// for both queries to report at least once before emitting.
  Stream<List<AppNotification>> streamForUser(String userId) {
    final personal = _collection.where('userId', isEqualTo: userId).snapshots();
    final broadcast = _collection.where('userId', isEqualTo: '').snapshots();

    var personalDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var broadcastDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var hasPersonal = false;
    var hasBroadcast = false;

    late StreamController<List<AppNotification>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? personalSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? broadcastSub;

    void emit() {
      if (!hasPersonal || !hasBroadcast) return;
      final all =
          [...personalDocs, ...broadcastDocs]
              .map((d) => AppNotification.fromMap(d.id, d.data()))
              .where((n) => !n.dismissedBy.contains(userId))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(all);
    }

    controller = StreamController<List<AppNotification>>(
      onListen: () {
        personalSub = personal.listen((snapshot) {
          personalDocs = snapshot.docs;
          hasPersonal = true;
          emit();
        }, onError: controller.addError);
        broadcastSub = broadcast.listen((snapshot) {
          broadcastDocs = snapshot.docs;
          hasBroadcast = true;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await personalSub?.cancel();
        await broadcastSub?.cancel();
      },
    );
    return controller.stream;
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

  /// Removes [notification] from [uid]'s inbox. A personal notification is
  /// deleted outright. A broadcast is one doc shared by every traveler, so
  /// deleting it would take it away from everyone — instead [uid] is
  /// appended to its `dismissedBy` array and [streamForUser] stops
  /// returning it for that traveler only.
  Future<void> delete(AppNotification notification, String uid) =>
      deleteAll([notification], uid);

  /// [delete] for a whole list at once — the inbox's "Clear all".
  Future<void> deleteAll(List<AppNotification> notifications, String uid) async {
    try {
      // Firestore caps a write batch at 500 operations.
      for (var start = 0; start < notifications.length; start += 500) {
        final batch = _db.batch();
        for (final notification in notifications.skip(start).take(500)) {
          final doc = _collection.doc(notification.id);
          if (notification.userId.isEmpty) {
            batch.update(doc, {
              'dismissedBy': FieldValue.arrayUnion([uid]),
            });
          } else {
            batch.delete(doc);
          }
        }
        await batch.commit();
      }
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// An admin's "Compose Announcement" (an LGU's goes through
  /// [createProvinceAnnouncement] instead) — an empty [userId]
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

  /// An LGU account's "Compose Announcement" — unlike [createBroadcast] this
  /// isn't a notification anyone reads directly. It's a request the
  /// `deliverProvinceAnnouncement` Cloud Function picks up and delivers as a
  /// personal notification (and push) to each traveler with a saved trip or
  /// a favorite in [provinceId]. `firestore.rules` only accepts an LGU's own
  /// province here, and no longer lets one write a nationwide broadcast.
  Future<void> createProvinceAnnouncement({
    required String provinceId,
    required String provinceName,
    required String createdBy,
    required String title,
    required String body,
    required NotificationCategory category,
  }) async {
    try {
      await _db.collection(FirestorePaths.provinceAnnouncements).add({
        'provinceId': provinceId,
        'provinceName': provinceName,
        'createdBy': createdBy,
        'title': title,
        'body': body,
        'category': category.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
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
  /// send. `firestore.rules` lets an 'admin' or 'lgu' account write one
  /// (either can be the one approving or suspending a listing).
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
