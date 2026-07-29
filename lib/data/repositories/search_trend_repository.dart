import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';

/// Tracks how often each search term is used across ALL travelers (unlike
/// `SearchHistoryService`, which is per-device recent history) so the
/// empty-query suggestions view can show real "Trending Searches" instead
/// of only rating-based "Popular Destinations". One doc per normalized
/// (lowercased/trimmed) term, incremented via a transaction so concurrent
/// searches from different travelers never race-lose an increment.
class SearchTrendRepository {
  SearchTrendRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection(FirestorePaths.searchTrends);

  /// Best-effort and fire-and-forget by every caller — a failed trend
  /// write should never slow down or block the traveler's own search.
  /// Skips anything shorter than the live-Places length floor
  /// (`search_screen.dart`'s own `trimmed.length >= 3` gate) so single
  /// keystrokes mid-typing don't pollute the trend counts.
  Future<void> record(String query) async {
    final term = query.trim();
    final normalized = term.toLowerCase();
    if (normalized.length < 3) return;
    final ref = _collection.doc(normalized);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          tx.set(ref, {
            'term': term,
            'count': 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          final count = (snap.data()?['count'] as num?)?.toInt() ?? 0;
          tx.update(ref, {
            'count': count + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (_) {
      // Best-effort — see class doc.
    }
  }

  Future<List<String>> getTopTrending({int limit = 4}) async {
    try {
      final snapshot = await _collection
          .orderBy('count', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((d) => d.data()['term'] as String? ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
