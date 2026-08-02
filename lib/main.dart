import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'ai/providers/ai_chat_provider.dart';
import 'ai/providers/ai_planner_provider.dart';
import 'core/constants/app_strings.dart';
import 'core/providers/accent_color_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/providers/favorites_provider.dart';
import 'core/providers/theme_mode_provider.dart';
import 'core/providers/typography_provider.dart';
import 'core/routes/app_router.dart';
import 'core/services/analytics_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/accent_colors.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

/// Must be a top-level function: the platform invokes this in a background
/// isolate (app killed/backgrounded) to hand off data-only FCM messages.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? initError;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Crashlytics has no web SDK at all — calling it there throws a
    // MissingPluginException, which (before this guard) got caught below as
    // a fatal `initError` and blocked the entire web app from loading.
    if (!kIsWeb) {
      // Debug builds report to the console instead of Crashlytics, so local
      // crashes during development don't pollute production crash-free rates.
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      ui.PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  } catch (e) {
    initError = e;
  }

  runApp(TripNestApp(initError: initError));
}

/// Root widget: wires up Firebase-backed providers, the light/dark theme
/// pair and the go_router configuration for the whole app.
class TripNestApp extends StatefulWidget {
  const TripNestApp({super.key, this.initError, this.authProvider, this.favoritesProvider});

  /// Set when [Firebase.initializeApp] throws — shown as a friendly full-screen
  /// error instead of crashing, since nothing in the app works without it.
  final Object? initError;

  /// Test-only injection points: widget tests construct [AuthProvider] and
  /// [FavoritesProvider] with fake/mocked Firebase instances and pass them
  /// in here instead of letting the app build its own real ones.
  final AuthProvider? authProvider;
  final FavoritesProvider? favoritesProvider;

  @override
  State<TripNestApp> createState() => _TripNestAppState();
}

class _TripNestAppState extends State<TripNestApp> {
  late final AuthProvider _authProvider;
  late final FavoritesProvider _favoritesProvider;
  late final ThemeModeProvider _themeModeProvider;
  late final AccentColorProvider _accentColorProvider;
  late final TypographyProvider _typographyProvider;
  late final ConnectivityProvider _connectivityProvider;
  late final AiPlannerProvider _aiPlannerProvider;
  late final AiChatProvider _aiChatProvider;
  late final GoRouter _router;
  String? _boundUserId;

  @override
  void initState() {
    super.initState();
    if (widget.initError != null) return;
    _authProvider = widget.authProvider ?? AuthProvider();
    _favoritesProvider = widget.favoritesProvider ?? FavoritesProvider();
    _themeModeProvider = ThemeModeProvider();
    _accentColorProvider = AccentColorProvider();
    _typographyProvider = TypographyProvider();
    _connectivityProvider = ConnectivityProvider();
    _aiPlannerProvider = AiPlannerProvider();
    _aiChatProvider = AiChatProvider();
    _router = buildAppRouter(_authProvider);
    _authProvider.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final userId = _authProvider.firebaseUser?.uid;
    if (userId == _boundUserId) return;
    _boundUserId = userId;
    _favoritesProvider.bindToUser(userId);
    AnalyticsService.instance.setUserId(userId);
    // Best-effort, same as NotificationService below — no Firebase app
    // exists in widget tests, and a crash-reporting hookup should never be
    // what takes down sign-in. Crashlytics has no web SDK at all, so skip
    // it there outright rather than throw-and-swallow on every auth change.
    if (!kIsWeb) {
      try {
        FirebaseCrashlytics.instance.setUserIdentifier(userId ?? '');
      } catch (_) {}
    }
    if (userId != null) {
      NotificationService.instance.registerForUser(userId);
    }
  }

  @override
  void dispose() {
    if (widget.initError == null) {
      _authProvider.removeListener(_onAuthChanged);
      _authProvider.dispose();
      _favoritesProvider.dispose();
      _themeModeProvider.dispose();
      _accentColorProvider.dispose();
      _typographyProvider.dispose();
      _connectivityProvider.dispose();
      _aiPlannerProvider.dispose();
      _aiChatProvider.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(themePresets.first),
        home: _FirebaseInitErrorScreen(error: widget.initError!),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _favoritesProvider),
        ChangeNotifierProvider.value(value: _themeModeProvider),
        ChangeNotifierProvider.value(value: _accentColorProvider),
        ChangeNotifierProvider.value(value: _typographyProvider),
        ChangeNotifierProvider.value(value: _connectivityProvider),
        ChangeNotifierProvider.value(value: _aiPlannerProvider),
        ChangeNotifierProvider.value(value: _aiChatProvider),
      ],
      child: Consumer3<ThemeModeProvider, AccentColorProvider, TypographyProvider>(
        builder: (context, themeModeProvider, accentColorProvider, typographyProvider, _) {
          return MaterialApp.router(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(accentColorProvider.preset, fontFamily: typographyProvider.fontFamily),
            darkTheme: AppTheme.dark(accentColorProvider.preset, fontFamily: typographyProvider.fontFamily),
            themeMode: themeModeProvider.mode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(typographyProvider.fontScale)),
              child: child!,
            ),
            routerConfig: _router,
          );
        },
      ),
    );
  }
}

class _FirebaseInitErrorScreen extends StatelessWidget {
  const _FirebaseInitErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  'TripNest PH couldn\'t connect',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Something went wrong starting the app\'s backend services. '
                  'Please check your connection and try again.\n\n$error',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
