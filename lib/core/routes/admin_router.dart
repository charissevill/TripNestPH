import 'package:go_router/go_router.dart';

import '../../domain/models/destination.dart';
import '../../domain/models/festival.dart';
import '../../domain/models/province.dart';
import '../../presentation/admin/admin_analytics_screen.dart';
import '../../presentation/admin/admin_broadcast_screen.dart';
import '../../presentation/admin/admin_bulk_import_screen.dart';
import '../../presentation/admin/admin_bulk_province_content_screen.dart';
import '../../presentation/admin/admin_business_list_screen.dart';
import '../../presentation/admin/admin_business_owner_applications_screen.dart';
import '../../presentation/admin/admin_festival_form_screen.dart';
import '../../presentation/admin/admin_festival_list_screen.dart';
import '../../presentation/admin/admin_home_screen.dart';
import '../../presentation/admin/admin_province_edit_screen.dart';
import '../../presentation/admin/admin_province_list_screen.dart';
import '../../presentation/admin/admin_reported_reviews_screen.dart';
import '../../presentation/admin/admin_team_screen.dart';
import '../../presentation/admin/admin_tourist_spot_form_screen.dart';
import '../../presentation/admin/admin_tourist_spot_list_screen.dart';
import '../../presentation/admin/admin_user_management_screen.dart';
import '../../presentation/admin/widgets/admin_sidebar_shell.dart';
import '../../presentation/auth/forgot_password_screen.dart';
import '../../presentation/business/my_business_screen.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/verify_email_screen.dart';
import '../../presentation/splash/splash_screen.dart';
import '../providers/auth_provider.dart';
import '../utils/view_status.dart';
import 'route_paths.dart';

const _adminAuthOnlyRoutes = {RoutePaths.login, RoutePaths.forgotPassword};

/// Router for the dedicated Admin Portal build (`lib/main_admin.dart`) —
/// deliberately never imports a single traveler-facing screen, so none of
/// them end up in this build's compiled output. Every admin screen already
/// does its own live `admin_users` check (see `AdminHomeScreen`), so the
/// only job here is auth routing: signed-out goes to Login, signed-in lands
/// on [RoutePaths.adminHome] instead of the traveler app's Home, and there's
/// simply no route for anything traveler-facing to redirect to even if
/// someone tries.
GoRouter buildAdminRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: authProvider,
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (location == RoutePaths.splash) return null;
      if (authProvider.status == ViewStatus.loading) return null;

      final signedIn = authProvider.isSignedIn;
      final verified = authProvider.isEmailVerified;

      if (!signedIn) {
        return _adminAuthOnlyRoutes.contains(location) ? null : RoutePaths.login;
      }
      if (!verified) {
        return location == RoutePaths.verifyEmail ? null : RoutePaths.verifyEmail;
      }
      if (_adminAuthOnlyRoutes.contains(location) || location == RoutePaths.verifyEmail) {
        return RoutePaths.adminHome;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) =>
            const LoginScreen(homeRedirect: RoutePaths.adminHome, showRegisterLink: false),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.verifyEmail,
        builder: (context, state) => const VerifyEmailScreen(verifiedRedirect: RoutePaths.adminHome),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AdminSidebarShell(currentPath: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: RoutePaths.adminHome,
            builder: (context, state) => const AdminHomeScreen(),
          ),
          GoRoute(
            path: RoutePaths.myBusiness,
            builder: (context, state) =>
                MyBusinessScreen(uid: authProvider.firebaseUser?.uid ?? ''),
          ),
          GoRoute(
            path: RoutePaths.adminProvinces,
            builder: (context, state) => const AdminProvinceListScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminProvinceEditPattern,
            builder: (context, state) =>
                AdminProvinceEditScreen(provinceId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: RoutePaths.adminTouristSpots,
            builder: (context, state) => const AdminTouristSpotListScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminTouristSpotForm,
            // The province only travels via `extra`, which a web refresh or
            // browser back/forward drops — go to the list instead of
            // crashing on the cast below.
            redirect: (context, state) =>
                (state.extra as Map?)?['province'] is Province
                    ? null
                    : RoutePaths.adminTouristSpots,
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return AdminTouristSpotFormScreen(
                province: extra?['province'] as Province,
                existing: extra?['destination'] as Destination?,
              );
            },
          ),
          GoRoute(
            path: RoutePaths.adminFestivals,
            builder: (context, state) => const AdminFestivalListScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminFestivalForm,
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return AdminFestivalFormScreen(existing: extra?['existing'] as Festival?);
            },
          ),
          GoRoute(
            path: RoutePaths.adminBusinesses,
            builder: (context, state) => const AdminBusinessListScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminBusinessOwnerApplications,
            builder: (context, state) => const AdminBusinessOwnerApplicationsScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminReportedReviews,
            builder: (context, state) => const AdminReportedReviewsScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminBroadcast,
            builder: (context, state) => const AdminBroadcastScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminAnalytics,
            builder: (context, state) => const AdminAnalyticsScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminUsers,
            builder: (context, state) => const AdminUserManagementScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminBulkImport,
            builder: (context, state) => const AdminBulkImportScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminBulkProvinceContent,
            builder: (context, state) => const AdminBulkProvinceContentScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminTeam,
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return AdminTeamScreen(
                currentUid: extra?['uid'] as String? ?? '',
                currentAdminName: extra?['name'] as String? ?? '',
              );
            },
          ),
        ],
      ),
    ],
  );
}
