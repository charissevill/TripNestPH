/// Centralized Cloud Firestore collection names, matching the schema in
/// `firestore.rules`. Repositories should always read paths from here
/// instead of hard-coding collection strings.
class FirestorePaths {
  FirestorePaths._();

  static const String users = 'users';
  static const String touristSpots = 'tourist_spots';
  static const String restaurants = 'restaurants';
  static const String festivals = 'festivals';
  static const String favorites = 'favorites';
  static const String favoriteCollections = 'favorite_collections';
  static const String savedItineraries = 'saved_itineraries';
  static const String reviews = 'reviews';
  static const String notifications = 'notifications';
  static const String travelTips = 'travel_tips';
  static const String regions = 'regions';
  static const String provinces = 'provinces';
  static const String adminUsers = 'admin_users';
  static const String adminInvites = 'admin_invites';
  static const String businesses = 'businesses';
  static const String reviewReports = 'review_reports';
  static const String tripPhotos = 'trip_photos';
  static const String searchTrends = 'search_trends';

  // Subcollections.
  static const String recentlyViewed = 'recently_viewed';
  static const String visited = 'visited';
  static const String expenses = 'expenses';
  static const String cities = 'cities';

  // Storage folders.
  static const String storageProfilePhotos = 'profile_photos';
  static const String storageReviewPhotos = 'review_photos';
  static const String storageDestinationPhotos = 'destination_photos';
  static const String storageBusinessGallery = 'business_gallery';
  static const String storageTripPhotos = 'trip_photos';
}
