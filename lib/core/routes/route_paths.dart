/// Centralized route path strings for go_router. Screens should navigate
/// via these constants rather than hard-coded path literals.
class RoutePaths {
  RoutePaths._();

  static const String splash = '/splash';
  static const String onboarding = '/onboarding';

  // Auth flow — outside the bottom-nav shell.
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String verifyEmail = '/verify-email';

  // Bottom-nav shell branches.
  static const String home = '/home';
  static const String explore = '/explore';
  static const String planner = '/planner';
  static const String saved = '/saved';
  static const String profile = '/profile';

  // Pushed on top of the shell.
  static const String search = '/search';
  static const String settings = '/settings';
  static const String generatedItinerary = '/planner/itinerary';
  static const String aiChat = '/ai-chat';
  static const String savedItineraries = '/saved-itineraries';
  static const String notifications = '/notifications';
  static const String editProfile = '/profile/edit';
  static const String recentlyViewed = '/profile/recently-viewed';
  static const String myPhotos = '/profile/my-photos';
  static String legalInfo(String topicKey) => '/settings/legal/$topicKey';
  static const String legalInfoPattern = '/settings/legal/:topicKey';
  static const String faq = '/settings/faq';
  static const String whatsNew = '/settings/whats-new';
  static const String tripCalendar = '/trip-calendar';
  static const String nearbyPlaces = '/nearby-places';

  // Admin Portal — built into this app, gated by an active admin_users doc.
  static const String adminHome = '/admin';
  static const String adminProvinces = '/admin/provinces';
  static String adminProvinceEdit(String id) => '/admin/provinces/$id/edit';
  static const String adminProvinceEditPattern = '/admin/provinces/:id/edit';
  static const String adminTouristSpots = '/admin/tourist-spots';
  static const String adminTouristSpotForm = '/admin/tourist-spots/form';
  static const String adminFestivals = '/admin/festivals';
  static const String adminFestivalForm = '/admin/festivals/form';
  static const String adminBusinesses = '/admin/businesses';
  static const String adminTeam = '/admin/team';
  static const String adminReportedReviews = '/admin/reported-reviews';
  static const String adminBroadcast = '/admin/broadcast';
  static const String myBusiness = '/my-business';

  // Detail routes, parameterized by id.
  static String destinationDetails(String id) => '/destination/$id';
  static String restaurantDetails(String id) => '/restaurant/$id';
  static String festivalDetails(String id) => '/festival/$id';
  static String provinceDetails(String id) => '/province/$id';

  static const String destinationDetailsPattern = '/destination/:id';
  static const String restaurantDetailsPattern = '/restaurant/:id';
  static const String festivalDetailsPattern = '/festival/:id';
  static const String provinceDetailsPattern = '/province/:id';
}
