import '../../domain/models/app_update.dart';

/// Real version history — there's only one release so far, so this list
/// has exactly one honest entry rather than invented earlier "versions".
/// Add a new [AppUpdate] at the top whenever a release actually ships.
class WhatsNewContent {
  WhatsNewContent._();

  static const List<AppUpdate> updates = [
    AppUpdate(
      version: '1.0.0',
      date: 'July 2026',
      highlights: [
        'Browse tourist spots, restaurants, and festivals across the Philippines.',
        'Search and filter by province, category, and rating.',
        'Save favorites and get AI-assisted trip planning and itineraries.',
        'Rate and review places you\'ve visited, with photos.',
        'Nearby You recommendations based on your current location.',
        'Festival and travel alerts, with an in-app notification inbox.',
        'Dark mode, and an FAQ and Privacy Policy you can actually read.',
      ],
    ),
  ];
}
