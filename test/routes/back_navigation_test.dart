import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tripnest_ph/core/providers/auth_provider.dart';
import 'package:tripnest_ph/core/providers/connectivity_provider.dart';
import 'package:tripnest_ph/core/routes/back_navigation.dart';
import 'package:tripnest_ph/core/routes/route_paths.dart';
import 'package:tripnest_ph/core/services/auth_service.dart';
import 'package:tripnest_ph/core/services/otp_service.dart';
import 'package:tripnest_ph/core/widgets/dialogs/discard_changes_scope.dart';
import 'package:tripnest_ph/data/repositories/destination_repository.dart';
import 'package:tripnest_ph/data/repositories/user_repository.dart';
import 'package:tripnest_ph/presentation/shell/main_shell_screen.dart';

/// A screen whose only control is an in-app Back button wired the way
/// every real screen's is.
class _Page extends StatelessWidget {
  const _Page(this.label, {this.fallback = '/home', this.dirty = false});

  final String label;
  final String fallback;
  final bool dirty;

  @override
  Widget build(BuildContext context) {
    return DiscardChangesScope(
      isDirty: dirty,
      child: Scaffold(
        body: Column(
          children: [
            Text(label),
            IconButton(
              key: const Key('back'),
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.popOrGo(fallback),
            ),
          ],
        ),
      ),
    );
  }
}

/// Always-online stand-in; the shell's offline banner only reads [isOnline].
class _OnlineConnectivity extends ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isOnline => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpRouter(WidgetTester tester, GoRouter router) async {
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  group('popOrGo', () {
    testWidgets('pops back to the previous screen when there is one', (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const _Page('Home')),
          GoRoute(path: '/details', builder: (_, _) => const _Page('Details', fallback: '/fallback')),
          GoRoute(path: '/fallback', builder: (_, _) => const _Page('Fallback')),
        ],
      );
      await _pumpRouter(tester, router);
      router.push('/details');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('back')));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Fallback'), findsNothing);
    });

    testWidgets('goes to the fallback instead of throwing on a lone route (deep link / web refresh)', (tester) async {
      final router = GoRouter(
        initialLocation: '/details',
        routes: [
          GoRoute(path: '/details', builder: (_, _) => const _Page('Details', fallback: '/fallback')),
          GoRoute(path: '/fallback', builder: (_, _) => const _Page('Fallback')),
        ],
      );
      await _pumpRouter(tester, router);

      await tester.tap(find.byKey(const Key('back')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Fallback'), findsOneWidget);
    });

    testWidgets('falls back inside a ShellRoute reached with go (Admin Portal sidebar)', (tester) async {
      final router = GoRouter(
        initialLocation: '/admin',
        routes: [
          ShellRoute(
            builder: (_, _, child) => child,
            routes: [
              GoRoute(path: '/admin', builder: (_, _) => const _Page('Overview')),
              GoRoute(path: '/admin/provinces', builder: (_, _) => const _Page('Provinces', fallback: '/admin')),
            ],
          ),
        ],
      );
      await _pumpRouter(tester, router);
      router.go('/admin/provinces');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('back')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Overview'), findsOneWidget);
    });

    testWidgets('asks before discarding unsaved changes, like device back does', (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const _Page('Home')),
          GoRoute(path: '/form', builder: (_, _) => const _Page('Form', dirty: true)),
        ],
      );
      await _pumpRouter(tester, router);
      router.push('/form');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('back')));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Form'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });
  });

  group('MainShellScreen device back', () {
    late GoRouter router;

    setUp(() {
      final firestore = FakeFirebaseFirestore();
      final authProvider = AuthProvider(
        authService: AuthService(auth: MockFirebaseAuth()),
        otpService: OtpService(caller: (name, data) async => {'success': true}),
        userRepository: UserRepository(firestore: firestore, destinationRepository: DestinationRepository(firestore: firestore)),
      );
      StatefulShellBranch branch(String path, String label) =>
          StatefulShellBranch(routes: [GoRoute(path: path, builder: (_, _) => Text('$label tab'))]);
      router = GoRouter(
        initialLocation: RoutePaths.home,
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
                ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _OnlineConnectivity()),
              ],
              child: MainShellScreen(navigationShell: shell),
            ),
            branches: [
              branch(RoutePaths.home, 'Home'),
              branch(RoutePaths.explore, 'Explore'),
              branch(RoutePaths.planner, 'Planner'),
              branch(RoutePaths.saved, 'Saved'),
              branch(RoutePaths.profile, 'Profile'),
            ],
          ),
        ],
      );
    });

    Future<bool> pressDeviceBack(WidgetTester tester) async {
      final handled = await router.routerDelegate.popRoute();
      await tester.pumpAndSettle();
      return handled;
    }

    bool onTab(WidgetTester tester, String label) =>
        tester.widget<Offstage>(find.ancestor(of: find.text('$label tab'), matching: find.byType(Offstage)).first).offstage == false;

    testWidgets('returns to Home from another tab instead of exiting', (tester) async {
      await _pumpRouter(tester, router);
      router.go(RoutePaths.explore);
      await tester.pumpAndSettle();
      expect(onTab(tester, 'Explore'), isTrue);

      expect(await pressDeviceBack(tester), isTrue);
      expect(onTab(tester, 'Home'), isTrue);
    });

    testWidgets('lets the system handle back on Home (exits the app)', (tester) async {
      await _pumpRouter(tester, router);

      expect(await pressDeviceBack(tester), isFalse);
      expect(onTab(tester, 'Home'), isTrue);
    });
  });
}
