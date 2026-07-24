import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Caches AI responses locally (keyed by a hash of the request that
/// produced them) so identical requests — e.g. regenerating the same
/// itinerary form, or re-asking a just-asked question — don't re-hit the
/// API. Entries expire after [ttl] so content doesn't go stale forever.
class AiCacheService {
  static const String _prefixPrefKey = 'ai_cache_';

  Future<String> _keyFor(String namespace, String requestSignature) async {
    final hash = sha256.convert(utf8.encode(requestSignature)).toString();
    return '$_prefixPrefKey${namespace}_$hash';
  }

  Future<String?> get(String namespace, String requestSignature, {Duration ttl = const Duration(hours: 6)}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _keyFor(namespace, requestSignature);
    final raw = prefs.getString(key);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = DateTime.tryParse(decoded['cachedAt'] as String? ?? '');
      if (cachedAt == null || DateTime.now().difference(cachedAt) > ttl) {
        await prefs.remove(key);
        return null;
      }
      return decoded['value'] as String?;
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  Future<void> set(String namespace, String requestSignature, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _keyFor(namespace, requestSignature);
    await prefs.setString(key, jsonEncode({'value': value, 'cachedAt': DateTime.now().toIso8601String()}));
  }
}
