import '../../domain/models/place.dart';

/// Best-effort mapping from TripNest's 6 browsing categories
/// (`mock_categories.dart`) to the Google Places API types that most
/// overlap with them. Places has no clean 1:1 category taxonomy of its own
/// — `explore_screen.dart`'s own category chips already fall back to
/// free-text search phrases for beaches/mountains/historical/nature for
/// this same reason — so a category with no confident match ('festivals':
/// Places models points of interest, not time-bound events) is simply
/// never boosted rather than guessed at.
const Map<String, Set<String>> _categoryPlaceTypes = {
  'beaches': {'beach'},
  'mountains': {'park'},
  'historical': {'historical_landmark', 'museum'},
  'nature': {'park'},
  'food': {'restaurant', 'cafe'},
};

/// Stable-sorts [places] so any place matching one of the traveler's
/// [favoriteCategories] (`AppUser.favoriteCategories`) leads, without
/// reordering within either group — a lightweight, rule-based
/// personalization pass over data already being shown, not a ranking
/// model. A no-op (returns [places] unchanged, same instance) whenever the
/// traveler has no favorite categories set, so a new or signed-out
/// session sees exactly the order it always has.
List<Place> rankByFavoriteCategories(
  List<Place> places,
  List<String> favoriteCategories,
) {
  if (favoriteCategories.isEmpty) return places;
  final favoriteTypes = <String>{
    for (final categoryId in favoriteCategories)
      ...?_categoryPlaceTypes[categoryId],
  };
  if (favoriteTypes.isEmpty) return places;

  final matched = <Place>[];
  final rest = <Place>[];
  for (final place in places) {
    (place.types.any(favoriteTypes.contains) ? matched : rest).add(place);
  }
  return [...matched, ...rest];
}
