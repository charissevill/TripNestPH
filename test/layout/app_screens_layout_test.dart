import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
// The mock helpers live in firebase_core's own platform interface package.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tripnest_ph/ai/providers/ai_chat_provider.dart';
import 'package:tripnest_ph/ai/providers/ai_planner_provider.dart';
import 'package:tripnest_ph/core/providers/accent_color_provider.dart';
import 'package:tripnest_ph/core/providers/auth_provider.dart';
import 'package:tripnest_ph/core/providers/connectivity_provider.dart';
import 'package:tripnest_ph/core/providers/favorites_provider.dart';
import 'package:tripnest_ph/core/providers/theme_mode_provider.dart';
import 'package:tripnest_ph/core/providers/typography_provider.dart';
import 'package:tripnest_ph/core/services/auth_service.dart';
import 'package:tripnest_ph/data/mock/mock_itinerary.dart';
import 'package:tripnest_ph/data/repositories/destination_repository.dart';
import 'package:tripnest_ph/data/repositories/favorites_repository.dart';
import 'package:tripnest_ph/data/repositories/user_repository.dart';
import 'package:tripnest_ph/data/mock/mock_provinces.dart';
import 'package:tripnest_ph/presentation/admin/admin_broadcast_screen.dart';
import 'package:tripnest_ph/presentation/admin/admin_business_list_screen.dart';
import 'package:tripnest_ph/presentation/admin/admin_business_owner_applications_screen.dart';
import 'package:tripnest_ph/presentation/admin/admin_festival_form_screen.dart';
import 'package:tripnest_ph/presentation/admin/admin_festival_list_screen.dart';
import 'package:tripnest_ph/presentation/admin/admin_home_screen.dart';
import 'package:tripnest_ph/presentation/admin/admin_province_edit_screen.dart';
import 'package:tripnest_ph/presentation/admin/admin_province_list_screen.dart';
import 'package:tripnest_ph/presentation/admin/admin_reported_reviews_screen.dart';
import 'package:tripnest_ph/presentation/admin/admin_team_screen.dart';
import 'package:tripnest_ph/presentation/admin/admin_tourist_spot_form_screen.dart';
import 'package:tripnest_ph/presentation/admin/admin_tourist_spot_list_screen.dart';
import 'package:tripnest_ph/presentation/auth/business_owner_application_screen.dart';
import 'package:tripnest_ph/presentation/ai_chat/ai_chat_screen.dart';
import 'package:tripnest_ph/presentation/ai_planner/ai_planner_screen.dart';
import 'package:tripnest_ph/presentation/ai_planner/generated_itinerary_screen.dart';
import 'package:tripnest_ph/presentation/ai_planner/manual_itinerary_screen.dart';
import 'package:tripnest_ph/presentation/business/business_dashboard_screen.dart';
import 'package:tripnest_ph/presentation/business/my_business_screen.dart';
import 'package:tripnest_ph/presentation/details/festival_details_screen.dart';
import 'package:tripnest_ph/presentation/details/province_details_screen.dart';
import 'package:tripnest_ph/presentation/details/restaurant_details_screen.dart';
import 'package:tripnest_ph/presentation/details/tourist_details_screen.dart';
import 'package:tripnest_ph/presentation/festivals/upcoming_festivals_screen.dart';
import 'package:tripnest_ph/presentation/itineraries/saved_itineraries_screen.dart';
import 'package:tripnest_ph/presentation/itineraries/trip_calendar_screen.dart';
import 'package:tripnest_ph/presentation/notifications/notifications_screen.dart';
import 'package:tripnest_ph/presentation/places/nearby_places_screen.dart';
import 'package:tripnest_ph/presentation/profile/edit_profile_screen.dart';
import 'package:tripnest_ph/presentation/profile/my_reviews_screen.dart';
import 'package:tripnest_ph/presentation/profile/profile_screen.dart';
import 'package:tripnest_ph/presentation/profile/recently_viewed_screen.dart';
import 'package:tripnest_ph/presentation/saved/saved_screen.dart';
import 'package:tripnest_ph/presentation/settings/settings_screen.dart';

import '../support/fake_image_http_overrides.dart';
import 'layout_harness.dart';

/// The signed-in, Firebase-backed screens. `firebase_core` is mocked so their
/// default repositories construct; their Firestore reads can't complete, so
/// what's exercised is each screen's primary layout (app bar, headers, tabs,
/// forms, empty/loading states) at every size and Text Size. Screens that
/// take injected fakes are covered with real data in the sibling test files.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = FakeImageHttpOverrides();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget withProviders(Widget app) {
    final firestore = FakeFirebaseFirestore();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(
          value: AuthProvider(
            authService: AuthService(auth: MockFirebaseAuth(signedIn: true)),
            userRepository: UserRepository(
              firestore: firestore,
              destinationRepository: DestinationRepository(firestore: firestore),
            ),
          ),
        ),
        ChangeNotifierProvider<FavoritesProvider>.value(
          value: FavoritesProvider(repository: FavoritesRepository(firestore: firestore)),
        ),
        ChangeNotifierProvider<ThemeModeProvider>(create: (_) => ThemeModeProvider()),
        ChangeNotifierProvider<AccentColorProvider>(create: (_) => AccentColorProvider()),
        ChangeNotifierProvider<TypographyProvider>(create: (_) => TypographyProvider()),
        ChangeNotifierProvider<ConnectivityProvider>(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider<AiPlannerProvider>(create: (_) => AiPlannerProvider()),
        ChangeNotifierProvider<AiChatProvider>(create: (_) => AiChatProvider()),
      ],
      child: app,
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void screen(String name, Widget Function() build) =>
      layoutMatrix(name, build, wrap: withProviders, act: settle);

  screen('Settings', () => const SettingsScreen());
  screen('Profile', () => const ProfileScreen());
  screen('Edit profile', () => const EditProfileScreen());
  screen('My reviews', () => const MyReviewsScreen());
  screen('Recently viewed', () => const RecentlyViewedScreen());
  screen('Saved', () => const SavedScreen());
  screen('Saved itineraries', () => const SavedItinerariesScreen());
  screen('Trip calendar', () => const TripCalendarScreen());
  screen('Notifications', () => const NotificationsScreen());
  screen('Nearby places', () => const NearbyPlacesScreen(title: 'Nearby Restaurants and Cafés'));
  screen('Upcoming festivals', () => const UpcomingFestivalsScreen());
  screen('AI chat', () => const AiChatScreen());
  screen('AI planner', () => const AiPlannerScreen());
  screen('Manual itinerary', () => const ManualItineraryScreen());
  screen('Generated itinerary', () => GeneratedItineraryScreen(itinerary: mockItinerary));
  screen('Business dashboard', () => const BusinessDashboardScreen(uid: 'mock_uid'));
  screen('My business', () => const MyBusinessScreen(uid: 'mock_uid'));
  screen('Tourist details', () => const TouristDetailsScreen(destinationId: 'x'));
  screen('Restaurant details', () => const RestaurantDetailsScreen(restaurantId: 'x'));
  screen('Festival details', () => const FestivalDetailsScreen(festivalId: 'x'));
  screen('Province details', () => const ProvinceDetailsScreen(provinceId: 'x'));
  screen('Business owner application', () => const BusinessOwnerApplicationScreen());

  // Admin portal screens (also reachable on a phone-sized window).
  screen('Admin: home', () => const AdminHomeScreen());
  screen('Admin: provinces', () => const AdminProvinceListScreen());
  screen('Admin: province edit', () => const AdminProvinceEditScreen(provinceId: 'x'));
  screen('Admin: tourist spots', () => const AdminTouristSpotListScreen());
  screen('Admin: tourist spot form', () => AdminTouristSpotFormScreen(province: mockProvinces.first));
  screen('Admin: festivals', () => const AdminFestivalListScreen());
  screen('Admin: festival form', () => const AdminFestivalFormScreen());
  screen('Admin: businesses', () => const AdminBusinessListScreen());
  screen('Admin: business applications', () => const AdminBusinessOwnerApplicationsScreen());
  screen('Admin: reported reviews', () => const AdminReportedReviewsScreen());
  screen('Admin: broadcast', () => const AdminBroadcastScreen());
  screen('Admin: team', () => const AdminTeamScreen(currentUid: 'mock_uid', currentAdminName: 'Bob Builder'));
}
