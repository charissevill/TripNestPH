import 'dart:async';

import 'package:http/http.dart' as http;

/// Endpoints that answer a plain request with an empty `204 No Content`.
/// A captive portal (hotel / café Wi-Fi login page) answers with a redirect
/// or a 200 HTML page instead, so only a real 204 counts as "online".
/// Two independent providers so one being blocked or down isn't mistaken
/// for the device being offline.
final List<Uri> _probeEndpoints = [
  Uri.parse('https://clients3.google.com/generate_204'),
  Uri.parse('https://cp.cloudflare.com/generate_204'),
];

const Duration _probeTimeout = Duration(seconds: 4);

/// Returns whether the open internet is actually reachable — not just
/// whether a Wi-Fi / mobile radio is up, which is all `connectivity_plus`
/// can tell. Never throws.
Future<bool> probeInternetReachable({http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    for (final uri in _probeEndpoints) {
      try {
        final response = await c.head(uri).timeout(_probeTimeout);
        if (response.statusCode == 204) return true;
      } catch (_) {
        // Timeout, DNS failure, socket error — try the next endpoint.
      }
    }
    return false;
  } finally {
    if (client == null) c.close();
  }
}
