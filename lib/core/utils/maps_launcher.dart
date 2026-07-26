import 'package:url_launcher/url_launcher.dart';

import 'itinerary_route_matcher.dart';

/// Opens coordinates in the device's Google Maps app (or maps.google.com on
/// platforms without it installed).
class MapsLauncher {
  MapsLauncher._();

  static Future<void> openDirections({required double latitude, required double longitude, String? label}) async {
    final query = label != null ? '$latitude,$longitude($label)' : '$latitude,$longitude';
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens turn-by-turn directions through every [stops] entry in order —
  /// the first stop as the origin, the last as the destination, and
  /// anything in between as waypoints — using Google's documented
  /// multi-stop directions URL format. Requires at least 2 stops.
  static Future<void> openMultiStopDirections(List<RouteStop> stops) async {
    if (stops.length < 2) return;
    String point(RouteStop s) => '${s.latitude},${s.longitude}';
    final waypoints = stops.sublist(1, stops.length - 1).map(point).join('|');
    final params = {
      'api': '1',
      'origin': point(stops.first),
      'destination': point(stops.last),
      if (waypoints.isNotEmpty) 'waypoints': waypoints,
    };
    final uri = Uri.https('www.google.com', '/maps/dir/', params);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens a plain text place search in Google Maps — for places (like a
  /// province) that don't have stored coordinates on file. Google Maps
  /// resolves the name itself, same as typing it into the Maps search bar.
  static Future<void> openPlaceSearch(String query) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
