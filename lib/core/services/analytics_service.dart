import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

/// Thin wrapper around [FirebaseAnalytics.instance]. Exposes [observer] for
/// GoRouter (automatic screen-view logging) and [logEvent]/[setUserId] for
/// call sites that want to record something more specific than a screen view.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  // Null when no Firebase app has been initialized — touching
  // FirebaseAnalytics.instance in that case throws, which would otherwise
  // take down widget tests (they build the router with no real Firebase app).
  FirebaseAnalytics? get _analytics => Firebase.apps.isEmpty ? null : FirebaseAnalytics.instance;

  NavigatorObserver get observer {
    final analytics = _analytics;
    return analytics == null ? NavigatorObserver() : FirebaseAnalyticsObserver(analytics: analytics);
  }

  Future<void> setUserId(String? uid) async {
    final analytics = _analytics;
    if (analytics == null) return;
    await analytics.setUserId(id: uid);
  }

  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    final analytics = _analytics;
    if (analytics == null) return;
    await analytics.logEvent(name: name, parameters: parameters);
  }
}
