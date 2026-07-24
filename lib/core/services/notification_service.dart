import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../constants/firestore_paths.dart';
import 'local_preferences_service.dart';

/// Requests notification permission, registers the device's FCM token
/// against the signed-in user's profile, and shows foreground pushes
/// (festival announcements, travel tips, featured destinations) as local
/// notifications. The in-app notifications list is driven separately by
/// [NotificationRepository] reading the `notifications` Firestore collection.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // A getter, not a field: touching `FirebaseMessaging.instance` throws if
  // no Firebase app has been initialized (e.g. in widget tests), and that
  // must happen inside `registerForUser`'s try/catch, not at construction
  // time when this singleton is first accessed.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final LocalPreferencesService _preferences = LocalPreferencesService();
  bool _initialized = false;

  /// Best-effort: a push-notification setup failure (no platform channel in
  /// tests, permission plumbing quirks on a given device, etc.) should never
  /// block sign-in or crash the app.
  Future<void> registerForUser(String userId) async {
    try {
      await _registerForUser(userId);
    } catch (_) {
      // Ignored — see doc comment above.
    }
  }

  Future<void> _registerForUser(String userId) async {
    await _ensureInitialized();

    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _messaging.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection(FirestorePaths.users).doc(userId).set(
        {'fcmTokens': FieldValue.arrayUnion([token])},
        SetOptions(merge: true),
      );
    }

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);

    const pushChannel = AndroidNotificationChannel(
      'tripnest_default',
      'TripNest PH Notifications',
      description: 'Festival announcements, travel tips and featured destinations',
      importance: Importance.high,
    );
    const reminderChannel = AndroidNotificationChannel(
      'tripnest_reminders',
      'TripNest PH Reminders',
      description: 'Trip, packing and festival reminders you\'ve scheduled yourself',
      importance: Importance.high,
    );
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(pushChannel);
    await androidPlugin?.createNotificationChannel(reminderChannel);

    tz_data.initializeTimeZones();
    // TripNest PH only serves Philippine tourism, so scheduling reminders in
    // Philippine time (rather than pulling in a separate package just to
    // detect the device's IANA timezone name) is a deliberate choice, not a
    // placeholder — every destination/festival in the app is already on
    // this clock.
    tz.setLocalLocation(tz.getLocation('Asia/Manila'));
  }

  /// Schedules a one-off local reminder (trip, packing, travel-day, festival)
  /// for [dateTime]. [id] should be stable per reminder so scheduling the
  /// same one twice replaces it rather than stacking duplicates — callers
  /// derive it deterministically from the itinerary/festival id.
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    await _ensureInitialized();
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(dateTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'tripnest_reminders',
          'TripNest PH Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      // Inexact is deliberate: exact alarms need the user-facing
      // SCHEDULE_EXACT_ALARM permission on Android 12+, which isn't worth
      // the extra permission prompt for a trip/packing reminder — landing
      // within a few minutes of the requested time is plenty.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder(int id) async {
    await _ensureInitialized();
    await _localNotifications.cancel(id);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    // The device still receives the push (needed so the badge/tray entry
    // exists once the traveler re-enables this) — only the foreground
    // pop-up display itself is gated by the Settings toggles.
    if (!await _preferences.getNotificationsEnabled()) return;
    final category = message.data['category'];
    if (category != null && (await _preferences.getDisabledCategories()).contains(category)) return;
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'tripnest_default',
          'TripNest PH Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
