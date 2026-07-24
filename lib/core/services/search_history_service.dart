import 'package:shared_preferences/shared_preferences.dart';

/// Tracks the traveler's own recent search queries locally — not synced to
/// Firestore, since search history is inherently per-device (same reasoning
/// `AiCacheService`/`PlacesCacheService` keep their caches local). Replaces
/// what used to be four hardcoded, always-identical "Recent Searches"
/// strings shown to every user regardless of what they'd actually searched.
class SearchHistoryService {
  static const String _prefsKey = 'search_history_v1';
  static const int _maxEntries = 8;

  Future<List<String>> getRecent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsKey) ?? const [];
  }

  /// Moves [query] to the front, deduping case-insensitively, capped at
  /// [_maxEntries] most recent.
  Future<List<String>> record(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return getRecent();

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_prefsKey) ?? <String>[];
    existing.removeWhere((q) => q.toLowerCase() == trimmed.toLowerCase());
    existing.insert(0, trimmed);
    final capped = existing.length > _maxEntries ? existing.sublist(0, _maxEntries) : existing;
    await prefs.setStringList(_prefsKey, capped);
    return capped;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
