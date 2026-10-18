import 'package:url_launcher/url_launcher.dart';

import 'itinerary_route_matcher.dart';
import 'safe_launch.dart';

/// Opens coordinates in the device's Google Maps app (or maps.google.com on
/// platforms without it installed).
class MapsLauncher {
  MapsLauncher._();

  static Future<void> openDirections({required double latitude, required double longitude, String? label}) async {
    final query = label != null ? '$latitude,$longitude($label)' : '$latitude,$longitude';
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    await _open(uri, _mapsFailure);
  }

  static const _mapsFailure = 'Couldn\'t open Maps. Please check that a maps or browser app is installed.';

  static Future<void> _open(Uri uri, String failureMessage) =>
      launchSafely(uri, mode: LaunchMode.externalApplication, failureMessage: failureMessage);

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
    await _open(uri, _mapsFailure);
  }

  /// Opens a plain text place search in Google Maps — for places (like a
  /// province) that don't have stored coordinates on file. Google Maps
  /// resolves the name itself, same as typing it into the Maps search bar.
  static Future<void> openPlaceSearch(String query) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    await _open(uri, _mapsFailure);
  }

  /// Google Maps search for [query] (e.g. 'hospital') centered on the
  /// traveler's own GPS fix. Uses the `/search/<query>/@lat,lng,zoom` form
  /// Google Maps itself produces, because the documented `api=1` search URL
  /// can't carry a center and leaves "near me" to whatever location Maps
  /// happens to have — none when Maps lacks location permission, or an IP
  /// guess in a browser. With no fix, falls back to exactly that
  /// `<query> near me` search.
  static Uri nearbySearchUri(String query, {double? latitude, double? longitude}) {
    if (latitude == null || longitude == null) {
      return Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$query near me')}');
    }
    final center = '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
    return Uri.parse('https://www.google.com/maps/search/${Uri.encodeComponent(query)}/@$center,15z');
  }

  static Future<void> openNearbySearch(String query, {double? latitude, double? longitude}) =>
      _open(nearbySearchUri(query, latitude: latitude, longitude: longitude), _mapsFailure);

  static Future<void> openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await _open(uri, 'Couldn\'t open that link. Please check that a browser app is installed.');
  }
}
