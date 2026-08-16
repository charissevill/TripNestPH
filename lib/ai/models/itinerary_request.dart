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
    this.priorConversationContext,
    this.refinementInstruction,
    this.tripPace,
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

  /// Set by `AiChatScreen._generateFromChat` to the assistant's own reply
  /// when "Generate Full Itinerary" is tapped from a chat conversation —
  /// the itinerary-generation prompt is otherwise a completely separate AI
  /// call with no knowledge of what was actually discussed in chat, so
  /// without this the generated day plan could recommend different
  /// restaurants/attractions than the ones the traveler just read. Null for
  /// a Planner-form-built request, which has no prior conversation to match.
  final String? priorConversationContext;

  /// Set by "Refine with AI" on an already-generated itinerary — a specific,
  /// free-text change the traveler wants (e.g. "make day 2 cheaper", "swap
  /// the beach activity for a hike") applied on top of an otherwise normal
  /// regeneration for the same destination/days/budget/travelers. Null for
  /// every other request, which has no such instruction to apply.
  final String? refinementInstruction;

  /// One of the Planner form's Trip Pace options (e.g. "Relaxed",
  /// "Adventure-Packed", "Foodie Focus") — how densely-packed the days
  /// should feel and which kind of activity to weight, woven into the same
  /// single generation call as every other form field. Null for a request
  /// built outside the Planner form (chat-driven or refine-only), where the
  /// prompt just omits any pacing guidance rather than assuming one.
  final String? tripPace;
}
