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
    this.accommodationName,
    this.accommodationLatitude,
    this.accommodationLongitude,
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

  /// The destination's coordinates, used to fetch a real weather forecast
  /// and to anchor the day route map. Null for a "whole province" trip (no
  /// single destination picked) — [AiRepository] falls back to geocoding
  /// [provinceName] itself in that case (see `_resolveDestinationCoordinates`),
  /// so those features degrade to "centered on the province" rather than
  /// not working at all.
  final double? latitude;
  final double? longitude;

  /// Optional — where the traveler said they're staying (searched via
  /// [PlacesService], not a stored destination/restaurant). When set,
  /// [AiRepository] sorts candidate restaurants/attractions by distance
  /// from here before they're shown to the AI. Null just means "no
  /// preference," generating exactly as it did before this existed.
  final String? accommodationName;
  final double? accommodationLatitude;
  final double? accommodationLongitude;
}
