/// Mock signed-in traveler shown on the Profile screen. No auth in Phase 1.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.memberSince,
    required this.placesVisited,
    required this.tripsPlanned,
    required this.savedCount,
    required this.reviewsWritten,
    required this.travelPreferences,
  });

  final String name;
  final String email;
  final String avatarUrl;
  final String memberSince;
  final int placesVisited;
  final int tripsPlanned;
  final int savedCount;
  final int reviewsWritten;
  final List<String> travelPreferences;
}
