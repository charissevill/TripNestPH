import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_strings.dart';
import 'core/providers/accent_color_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/providers/favorites_provider.dart';
import 'core/providers/theme_mode_provider.dart';
import 'core/providers/typography_provider.dart';
import 'core/routes/admin_router.dart';
import 'core/services/analytics_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/accent_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_exception.dart';
import 'core/utils/safe_launch.dart';
import 'firebase_options.dart';

/// Dedicated entrypoint for the Admin Portal's own deployed site — same
/// Firebase/provider setup as `main.dart`, but wired to [buildAdminRouter]
/// instead of the traveler app's router, and never importing a single
/// traveler-facing screen. Traveler screens simply don't exist in this
/// build's dependency graph, so they're excluded from the compiled output —
/// see the plan doc's Context section for why this exists alongside (not
/// instead of) the traveler app's own in-app Admin Portal.
///
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
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      ui.PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  } catch (e, stack) {
    // Kept out of the UI on purpose — the full error only goes to the debug
    // log; the error screen shows a plain-language message.
    logTechnicalError(e, stack);
    initError = e;
  }

  runApp(TripNestAdminApp(initError: initError));
}

/// Root widget for the Admin Portal site — mirrors `main.dart`'s
/// `TripNestApp` structure but with [buildAdminRouter] and without the
/// traveler-only `AiPlannerProvider`/`AiChatProvider` (nothing admin-only
/// touches either, and dropping them keeps their code out of this bundle).
class TripNestAdminApp extends StatefulWidget {
  const TripNestAdminApp({super.key, this.initError, this.authProvider, this.favoritesProvider});

  final Object? initError;
  final AuthProvider? authProvider;
  final FavoritesProvider? favoritesProvider;

  @override
  State<TripNestAdminApp> createState() => _TripNestAdminAppState();
}

class _TripNestAdminAppState extends State<TripNestAdminApp> {
  late final AuthProvider _authProvider;
  late final FavoritesProvider _favoritesProvider;
  late final ThemeModeProvider _themeModeProvider;
  late final AccentColorProvider _accentColorProvider;
  late final TypographyProvider _typographyProvider;
  late final ConnectivityProvider _connectivityProvider;
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
    _router = buildAdminRouter(_authProvider);
    _authProvider.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final userId = _authProvider.firebaseUser?.uid;
    if (userId == _boundUserId) return;
    _boundUserId = userId;
    _favoritesProvider.bindToUser(userId);
    AnalyticsService.instance.setUserId(userId);
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
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(themePresets.first),
        home: _AdminFirebaseInitErrorScreen(error: widget.initError!),
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
      ],
      child: Consumer3<ThemeModeProvider, AccentColorProvider, TypographyProvider>(
        builder: (context, themeModeProvider, accentColorProvider, typographyProvider, _) {
          return MaterialApp.router(
            scaffoldMessengerKey: appMessengerKey,
            title: '${AppStrings.appName} Admin',
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

class _AdminFirebaseInitErrorScreen extends StatelessWidget {
  const _AdminFirebaseInitErrorScreen({required this.error});

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
                  'TripNest PH Admin couldn\'t connect',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Something went wrong while starting the app. '
                  'Please check your internet connection, then close and reopen the app.',
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
