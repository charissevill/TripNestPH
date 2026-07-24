import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'ai/providers/ai_chat_provider.dart';
import 'ai/providers/ai_planner_provider.dart';
import 'core/constants/app_strings.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/providers/favorites_provider.dart';
import 'core/providers/theme_mode_provider.dart';
import 'core/routes/app_router.dart';
import 'core/services/notification_service.dart';
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
        theme: AppTheme.light,
        home: _FirebaseInitErrorScreen(error: widget.initError!),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _favoritesProvider),
        ChangeNotifierProvider.value(value: _themeModeProvider),
        ChangeNotifierProvider.value(value: _connectivityProvider),
        ChangeNotifierProvider.value(value: _aiPlannerProvider),
        ChangeNotifierProvider.value(value: _aiChatProvider),
      ],
      child: Consumer<ThemeModeProvider>(
        builder: (context, themeModeProvider, _) {
          return MaterialApp.router(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeModeProvider.mode,
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
