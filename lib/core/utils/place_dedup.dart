/// Live Places results shorter than this are skipped from the dedup name
/// comparison entirely — the same reasoning `itinerary_route_matcher.dart`
/// uses: a very short name would produce meaningless/misleading matches
/// against unrelated curated results.
const int minDedupNameLength = 4;

/// A *partial* (one name containing the other) match is only trusted once
/// both names clear this higher bar — a short, generic curated name like
/// "Cafe" or "Grill" would otherwise falsely match every unrelated live
/// result that merely happens to share that one common word. An exact match
/// still counts at any length above [minDedupNameLength].
const int minDedupPartialMatchLength = 6;

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
    if (curated == normalized) return true;
    if (curated.length < minDedupPartialMatchLength || normalized.length < minDedupPartialMatchLength) {
      continue;
    }
    if (_containsAsWholeWord(curated, normalized) || _containsAsWholeWord(normalized, curated)) {
      return true;
    }
  }
  return false;
}

/// Whether [needle] appears inside [haystack] at word boundaries — so a
/// curated "Cafe" doesn't falsely match a live "Cafeteria" (needle bleeds
/// into the next word), while a curated "Corner Cafe" still matches a live
/// "The Corner Cafe" (needle stands alone).
bool _containsAsWholeWord(String haystack, String needle) {
  final index = haystack.indexOf(needle);
  if (index == -1) return false;
  final startsAtBoundary = index == 0 || !_isWordChar(haystack[index - 1]);
  final endIndex = index + needle.length;
  final endsAtBoundary = endIndex >= haystack.length || !_isWordChar(haystack[endIndex]);
  return startsAtBoundary && endsAtBoundary;
}

final RegExp _wordChar = RegExp(r'[a-z0-9]');
bool _isWordChar(String char) => _wordChar.hasMatch(char);
