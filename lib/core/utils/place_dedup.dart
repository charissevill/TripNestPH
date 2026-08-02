/// Live Places results shorter than this are skipped from the dedup name
/// comparison — the same reasoning `itinerary_route_matcher.dart` uses:
/// a very short name would produce meaningless/misleading containment
/// matches against unrelated curated results.
const int minDedupNameLength = 4;

/// True when [placeName] (a live Google Places result) is close enough to
/// one of [curatedNamesLower] (already-lowercased curated destination/
/// restaurant/festival names) that showing both would look like a
/// duplicate — e.g. a curated "Alona Beach" restaurant and a live Places
/// result also named "Alona Beach". Shared between `search_screen.dart` and
/// `explore_screen.dart`, both of which blend curated Firestore content
/// with live Places results and need to suppress the same kind of overlap.
bool isDuplicateOfCurated(String placeName, Set<String> curatedNamesLower) {
  final normalized = placeName.toLowerCase().trim();
  if (normalized.length < minDedupNameLength) return false;
  for (final curated in curatedNamesLower) {
    if (curated.length < minDedupNameLength) continue;
    if (curated == normalized ||
        curated.contains(normalized) ||
        normalized.contains(curated)) {
      return true;
    }
  }
  return false;
}
