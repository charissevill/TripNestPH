/// Everything the AI Planner form collects, handed to [AiRepository] to
/// build a grounded prompt. Kept separate from [Itinerary] itself since this
/// is the *request*, not the generated result.
class AiItineraryRequest {
  const AiItineraryRequest({
    required this.destinationId,
    required this.destinationName,
    required this.provinceId,
    required this.provinceName,
    required this.budgetTierLabel,
    required this.budgetRange,
    required this.days,
    required this.travelers,
    required this.travelerType,
    required this.transportation,
    required this.interests,
    this.latitude,
    this.longitude,
  });

  final String destinationId;
  final String destinationName;
  final String provinceId;
  final String provinceName;
  final String budgetTierLabel;
  final String budgetRange;
  final int days;
  final int travelers;
  final String travelerType;
  final Set<String> transportation;
  final Set<String> interests;

  /// The destination's coordinates, used to fetch a real weather forecast.
  /// Null for destinations without coordinates on file — the itinerary
  /// still generates, it just has no "Weather Outlook" section.
  final double? latitude;
  final double? longitude;
}
