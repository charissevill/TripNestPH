import 'package:go_router/go_router.dart';

import '../../domain/models/destination.dart';
import '../../domain/models/province.dart';
import '../../presentation/admin/admin_broadcast_screen.dart';
import '../../presentation/admin/admin_business_list_screen.dart';
import '../../presentation/admin/admin_festival_form_screen.dart';
import '../../presentation/admin/admin_festival_list_screen.dart';
import '../../presentation/admin/admin_home_screen.dart';
import '../../presentation/admin/admin_province_edit_screen.dart';
import '../../presentation/admin/admin_province_list_screen.dart';
import '../../presentation/admin/admin_reported_reviews_screen.dart';
import '../../presentation/admin/admin_team_screen.dart';
import '../../presentation/admin/admin_tourist_spot_form_screen.dart';
import '../../presentation/admin/admin_tourist_spot_list_screen.dart';
import '../../presentation/business/my_business_screen.dart';
import '../../domain/models/festival.dart';
import '../../presentation/ai_chat/ai_chat_screen.dart';
import '../../presentation/ai_planner/ai_planner_screen.dart';
import '../../presentation/ai_planner/generated_itinerary_screen.dart';
import '../../presentation/auth/forgot_password_screen.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/register_screen.dart';
import '../../presentation/auth/verify_email_screen.dart';
import '../../presentation/details/festival_details_screen.dart';
import '../../presentation/details/province_details_screen.dart';
import '../../presentation/details/restaurant_details_screen.dart';
import '../../presentation/details/tourist_details_screen.dart';
import '../../presentation/explore/explore_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/itineraries/saved_itineraries_screen.dart';
import '../../presentation/itineraries/trip_calendar_screen.dart';
import '../../presentation/notifications/notifications_screen.dart';
import '../../presentation/onboarding/onboarding_screen.dart';
import '../../presentation/places/nearby_places_screen.dart';
import '../../presentation/profile/edit_profile_screen.dart';
import '../../presentation/profile/profile_screen.dart';
import '../../presentation/profile/recently_viewed_screen.dart';
import '../../presentation/saved/saved_screen.dart';
import '../../presentation/search/search_screen.dart';
import '../constants/legal_content.dart';
import '../../presentation/settings/faq_screen.dart';
import '../../presentation/settings/legal_info_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../../presentation/settings/whats_new_screen.dart';
import '../../presentation/shell/main_shell_screen.dart';
import '../../presentation/splash/splash_screen.dart';
import '../../domain/models/itinerary.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import '../utils/view_status.dart';
import 'route_paths.dart';

const _authOnlyRoutes = {
  RoutePaths.onboarding,
  RoutePaths.login,
  RoutePaths.register,
  RoutePaths.forgotPassword,
};

/// Builds the app's [GoRouter], wiring [authProvider] in as
/// `refreshListenable` so navigation reacts live to sign-in/sign-out and
/// email-verification state — the single place that decides whether a
/// visitor lands on Login, Verify Email or the main app shell.
GoRouter buildAppRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: authProvider,
    observers: [AnalyticsService.instance.observer],
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (location == RoutePaths.splash) return null;
      if (authProvider.status == ViewStatus.loading) return null;

      final signedIn = authProvider.isSignedIn;
      final verified = authProvider.isEmailVerified;

      if (!signedIn) {
        return _authOnlyRoutes.contains(location) ? null : RoutePaths.login;
      }
      if (!verified) {
        return location == RoutePaths.verifyEmail
            ? null
            : RoutePaths.verifyEmail;
      }
      if (_authOnlyRoutes.contains(location) ||
          location == RoutePaths.verifyEmail) {
        return RoutePaths.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.verifyEmail,
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: RoutePaths.search,
        builder: (context, state) =>
            SearchScreen(autoOpenFilter: state.extra == true),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.legalInfoPattern,
        builder: (context, state) =>
            LegalInfoScreen(topicKey: state.pathParameters['topicKey']!),
      ),
      GoRoute(
        path: RoutePaths.faq,
        builder: (context, state) => FaqScreen(items: LegalContent.faq),
      ),
      GoRoute(
        path: RoutePaths.whatsNew,
        builder: (context, state) => const WhatsNewScreen(),
      ),
      GoRoute(
        path: RoutePaths.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.recentlyViewed,
        builder: (context, state) => const RecentlyViewedScreen(),
      ),
      GoRoute(
        path: RoutePaths.savedItineraries,
        builder: (context, state) => const SavedItinerariesScreen(),
      ),
      GoRoute(
        path: RoutePaths.tripCalendar,
        builder: (context, state) => const TripCalendarScreen(),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.aiChat,
        builder: (context, state) => const AiChatScreen(),
      ),
      GoRoute(
        path: RoutePaths.generatedItinerary,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return GeneratedItineraryScreen(
            itinerary: extra?['itinerary'] as Itinerary?,
            savedItineraryId: extra?['savedId'] as String?,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.destinationDetailsPattern,
        builder: (context, state) =>
            TouristDetailsScreen(destinationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.restaurantDetailsPattern,
        builder: (context, state) =>
            RestaurantDetailsScreen(restaurantId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.festivalDetailsPattern,
        builder: (context, state) =>
            FestivalDetailsScreen(festivalId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.provinceDetailsPattern,
        builder: (context, state) =>
            ProvinceDetailsScreen(provinceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.nearbyPlaces,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return NearbyPlacesScreen(
            title: extra?['title'] as String? ?? 'Nearby Places',
            includedTypes: (extra?['includedTypes'] as List?)?.cast<String>(),
            latitude: extra?['latitude'] as double?,
            longitude: extra?['longitude'] as double?,
            areaLabel: extra?['areaLabel'] as String?,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.adminHome,
        builder: (context, state) => const AdminHomeScreen(),
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
          return AdminFestivalFormScreen(
            existing: extra?['existing'] as Festival?,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.adminBusinesses,
        builder: (context, state) => const AdminBusinessListScreen(),
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
        path: RoutePaths.adminTeam,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AdminTeamScreen(
            currentUid: extra?['uid'] as String? ?? '',
            currentAdminName: extra?['name'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: RoutePaths.myBusiness,
        builder: (context, state) =>
            MyBusinessScreen(uid: authProvider.firebaseUser?.uid ?? ''),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.explore,
                builder: (context, state) => ExploreScreen(
                  initialCategoryId: state.uri.queryParameters['category'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.planner,
                builder: (context, state) => const AiPlannerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.saved,
                builder: (context, state) => const SavedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
