import 'package:url_launcher/url_launcher.dart';

/// Opens coordinates in the device's Google Maps app (or maps.google.com on
/// platforms without it installed).
class MapsLauncher {
  MapsLauncher._();

  static Future<void> openDirections({required double latitude, required double longitude, String? label}) async {
    final query = label != null ? '$latitude,$longitude($label)' : '$latitude,$longitude';
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
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
