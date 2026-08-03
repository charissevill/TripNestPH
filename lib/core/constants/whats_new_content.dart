import '../../domain/models/app_update.dart';

/// Real version history — there's only one release so far, so this list
/// has exactly one honest entry rather than invented earlier "versions".
/// Its highlights are kept current with what's actually shipped in that
/// release. Add a new [AppUpdate] at the top whenever a new version
/// actually ships (see the `version:` line in pubspec.yaml).
class WhatsNewContent {
  WhatsNewContent._();

  static const List<AppUpdate> updates = [
    AppUpdate(
      version: '1.0.0',
      date: 'August 2026',
      highlights: [
        'Browse tourist spots, restaurants, and festivals — curated by local tourism offices, plus live results from Google Places.',
        'Search and filter by province, category, and rating.',
        'Chat with the AI Travel Assistant across multiple saved conversations, or generate a full day-by-day itinerary with the AI Planner.',
        'Save favorites and itineraries, and view a saved itinerary offline with no connection.',
        'Split trip expenses with your travel companions right inside a saved itinerary.',
        'Tag your trip photos to the exact place you took them in "My Photos".',
        'Rate and review places you\'ve visited, with photos — and report anything that looks fake or abusive.',
        'Nearby You recommendations sorted by actual distance from your current location.',
        'Festival and travel alerts, with an in-app notification inbox.',
        'Choose from several color themes, each with a light and dark mode.',
        'A true desktop layout on the web version, not just a stretched mobile screen.',
        'Business owners can list and manage their own accommodations, restaurants, tours, and shops.',
        'Local tourism offices (LGUs) can manage their province\'s listings and see local engagement analytics.',
      ],
    ),
  ];
}
