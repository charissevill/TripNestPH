/// One day's platform-wide stats, written by the scheduled
/// `snapshotDailyAnalytics` Cloud Function — see that function's doc
/// comment. Backed by the `analytics_snapshots` Firestore collection
/// (one doc per UTC date, id `YYYY-MM-DD`); admin-only, never written from
/// the client.
class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.date,
    required this.travelerCount,
    required this.suspendedTravelerCount,
    required this.publishedDestinationCount,
    required this.publishedRestaurantCount,
    required this.publishedFestivalCount,
    required this.pendingBusinessCount,
    required this.approvedBusinessCount,
    required this.savedTripCount,
    required this.pendingReportCount,
  });

  final DateTime date;
  final int travelerCount;
  final int suspendedTravelerCount;
  final int publishedDestinationCount;
  final int publishedRestaurantCount;
  final int publishedFestivalCount;
  final int pendingBusinessCount;
  final int approvedBusinessCount;
  final int savedTripCount;
  final int pendingReportCount;

  factory AnalyticsSnapshot.fromMap(String id, Map<String, dynamic> map) {
    return AnalyticsSnapshot(
      date: DateTime.tryParse(map['date'] as String? ?? id) ?? DateTime.now(),
      travelerCount: (map['travelerCount'] as num?)?.toInt() ?? 0,
      suspendedTravelerCount: (map['suspendedTravelerCount'] as num?)?.toInt() ?? 0,
      publishedDestinationCount: (map['publishedDestinationCount'] as num?)?.toInt() ?? 0,
      publishedRestaurantCount: (map['publishedRestaurantCount'] as num?)?.toInt() ?? 0,
      publishedFestivalCount: (map['publishedFestivalCount'] as num?)?.toInt() ?? 0,
      pendingBusinessCount: (map['pendingBusinessCount'] as num?)?.toInt() ?? 0,
      approvedBusinessCount: (map['approvedBusinessCount'] as num?)?.toInt() ?? 0,
      savedTripCount: (map['savedTripCount'] as num?)?.toInt() ?? 0,
      pendingReportCount: (map['pendingReportCount'] as num?)?.toInt() ?? 0,
    );
  }
}
