import '../../domain/models/province.dart';
import '../models/itinerary_request.dart';

/// Builds the two-message (system + user) prompt pair that asks the model
/// for a complete, structured itinerary as strict JSON matching
/// [Itinerary]'s shape — so the repository can deserialize it directly into
/// the *existing* itinerary UI without that screen ever knowing AI wrote it.
class ItineraryPrompts {
  ItineraryPrompts._();

  /// Valid [IconRegistry] keys the model may use for activity/budget icons.
  /// Constraining the choice keeps every generated icon resolvable; an
  /// invalid key just falls back to a default rather than breaking anything.
  static const List<String> iconKeys = [
    'wb_sunny', 'wb_cloudy', 'payments', 'directions_boat', 'diversity_3',
    'sim_card', 'hotel', 'restaurant', 'hiking', 'flight_land', 'flight_takeoff',
    'beach_access', 'lunch_dining', 'local_pizza', 'shopping_bag', 'eco',
    'celebration', 'landscape', 'forest', 'account_balance',
  ];

  static const List<String> colorKeys = [
    'primary', 'primaryDark', 'secondary', 'secondaryDark', 'accent', 'accentDark', 'error',
  ];

  static String system() {
    return '''
You are the trip-planning engine inside TripNest PH, a Philippine tourism app. You produce complete, realistic, practical day-by-day travel itineraries for real Philippine destinations.

You must respond with ONLY a single JSON object — no prose before or after it, no markdown code fences. It must match this exact shape:

{
  "days": [
    {
      "dayNumber": 1,
      "dateLabel": "Day 1",
      "activities": [
        {"time": "Morning", "title": "...", "description": "1-2 sentences, concrete and specific", "iconKey": "one of the allowed keys", "location": "specific place name"},
        {"time": "Afternoon", "title": "...", "description": "...", "iconKey": "...", "location": "..."},
        {"time": "Evening", "title": "...", "description": "...", "iconKey": "...", "location": "..."}
      ]
    }
  ],
  "budgetBreakdown": [
    {"label": "Transportation", "amount": 0, "iconKey": "directions_boat", "colorKey": "primary"},
    {"label": "Food", "amount": 0, "iconKey": "restaurant", "colorKey": "secondary"},
    {"label": "Entrance Fees", "amount": 0, "iconKey": "payments", "colorKey": "accent"},
    {"label": "Accommodation", "amount": 0, "iconKey": "hotel", "colorKey": "primaryDark"},
    {"label": "Miscellaneous", "amount": 0, "iconKey": "shopping_bag", "colorKey": "secondaryDark"}
  ],
  "totalBudget": 0,
  "recommendedRestaurantNames": ["exact name from the provided restaurant list, if any are a good fit"],
  "nearbyAttractionNames": ["exact name from the provided attraction list, if any are a good fit"],
  "travelTips": ["short, punchy, single-sentence strings — see categories below"]
}

Rules:
- "iconKey" must be one of: ${iconKeys.join(', ')}.
- "colorKey" must be one of: ${colorKeys.join(', ')}.
- Every day must have exactly 3 activities: Morning, Afternoon, Evening.
- "totalBudget" must roughly equal the sum of "budgetBreakdown" amounts, in Philippine pesos (numbers only, no currency symbol), and must fit the traveler's stated budget tier. If a real daily-budget guide for the province is given in the user message, sanity-check your numbers against it — the traveler's chosen budget tier is still primary, but don't wildly exceed or undercut the province's real average without reason.
- "recommendedRestaurantNames" and "nearbyAttractionNames" must ONLY contain names copied exactly from the lists given to you in the user message — never invent a name that wasn't provided. Leave the array empty if nothing provided fits well.
- "travelTips" must include, in this order, one entry per category (skip a category only if genuinely not applicable): a suggested local delicacy/dish to try, a hidden gem worth a detour (only if you're not already covering it in the day plan), the best visiting hours/time of day to avoid crowds, a practical travel reminder (e.g. booking ahead, cash vs card), a safety reminder specific to the destination, and an eco-friendly travel tip. Prefix each with a short bold-ish label like "Local delicacy:", "Hidden gem:", "Best time to visit:", "Reminder:", "Safety:", "Eco tip:" followed by the actual tip. For the "Safety:" tip: if real emergency hotline data for the province is given in the user message, cite the actual label/number from it verbatim rather than a generic one; only fall back to general Philippines emergency guidance if none is given.
- Keep every string concise and mobile-friendly — this renders in a scrollable card UI, not a document.
- Never suggest anything illegal, unsafe, or environmentally destructive.
''';
  }

  static String user({
    required AiItineraryRequest request,
    required List<String> candidateRestaurantNames,
    required List<String> candidateAttractionNames,
    List<String> candidateHotelNames = const [],
    List<EmergencyHotline> emergencyHotlines = const [],
    List<String> provinceTravelTips = const [],
    double? provinceBudgetMin,
    double? provinceBudgetMax,
    String? accommodationName,
  }) {
    return '''
Plan a trip with these details:
- Destination: ${request.destinationName}, ${request.provinceName}, Philippines
- Trip length: ${request.days} day(s)
- Number of travelers: ${request.travelers}
- Traveler type: ${request.travelerType}
- Budget tier: ${request.budgetTierLabel} (${request.budgetRange} total for the whole trip, all travelers combined)
- Preferred transportation: ${request.transportation.isEmpty ? 'no preference' : request.transportation.join(', ')}
- Interests: ${request.interests.isEmpty ? 'general sightseeing' : request.interests.join(', ')}

Restaurants available near this destination (pick from these only, if relevant): ${candidateRestaurantNames.isEmpty ? 'none provided' : candidateRestaurantNames.join(', ')}

Other attractions available near this destination (pick from these only, if relevant): ${candidateAttractionNames.isEmpty ? 'none provided' : candidateAttractionNames.join(', ')}

Top-rated hotels near this destination, already chosen and shown to the traveler separately as "Recommended Accommodations" — do not repeat them in "recommendedRestaurantNames"/"nearbyAttractionNames", but feel free to reference one by name in a travel tip if genuinely useful (e.g. proximity to a planned activity): ${candidateHotelNames.isEmpty ? 'none available' : candidateHotelNames.join(', ')}
${accommodationName != null && accommodationName.isNotEmpty ? '\nThe traveler is staying near $accommodationName. The restaurant/attraction lists above are already sorted by distance from there — prefer picks near the top of each list when they still fit the traveler\'s interests and budget.\n' : ''}

Real safety/budget facts on file for ${request.provinceName} — use these instead of inventing generic ones:
- Emergency hotlines: ${emergencyHotlines.isEmpty ? 'none on file — give general Philippines emergency guidance (e.g. 911) and note that the traveler should confirm the local hotline on arrival' : emergencyHotlines.map((h) => '${h.label}: ${h.number}').join(', ')}
- Typical daily budget guide for this province: ${(provinceBudgetMin != null && provinceBudgetMin > 0 && provinceBudgetMax != null && provinceBudgetMax > 0) ? '₱${provinceBudgetMin.toStringAsFixed(0)}–₱${provinceBudgetMax.toStringAsFixed(0)} per day' : 'not on file'}
- Official TripNest PH travel tips on file: ${provinceTravelTips.isEmpty ? 'none' : provinceTravelTips.join('; ')}

Respond with the JSON object only.
''';
  }
}
