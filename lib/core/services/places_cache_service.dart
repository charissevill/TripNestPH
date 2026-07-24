import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/place.dart';

/// Caches Places API results locally (keyed by a hash of the request that
/// produced them) so revisiting the same province/destination page within
/// the TTL doesn't re-hit a billed API — same shape as `AiCacheService`,
/// deliberately not Firestore (see the Phase 2 plan's rationale: this is
/// per-device, inherently-stale-eventually data, not app/user data).
class PlacesCacheService {
  static const String _prefixPrefKey = 'places_cache_';

  Future<String> _keyFor(String requestSignature) async {
    final hash = sha256.convert(utf8.encode(requestSignature)).toString();
    return '$_prefixPrefKey$hash';
  }

  Future<List<Place>?> get(String requestSignature, {Duration ttl = const Duration(hours: 24)}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _keyFor(requestSignature);
    final raw = prefs.getString(key);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = DateTime.tryParse(decoded['cachedAt'] as String? ?? '');
      if (cachedAt == null || DateTime.now().difference(cachedAt) > ttl) {
        await prefs.remove(key);
        return null;
      }
      final places = decoded['places'] as List? ?? const [];
      return places.map((p) => Place.fromCacheJson(Map<String, dynamic>.from(p as Map))).toList();
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  Future<void> set(String requestSignature, List<Place> places) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _keyFor(requestSignature);
    await prefs.setString(
      key,
      jsonEncode({
        'places': places.map((p) => p.toJson()).toList(),
        'cachedAt': DateTime.now().toIso8601String(),
      }),
    );
  }
}
