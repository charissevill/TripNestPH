import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/utils/maps_launcher.dart';

void main() {
  test('nearbySearchUri() centers the search on the given GPS fix', () {
    final uri = MapsLauncher.nearbySearchUri('police station', latitude: 9.6496, longitude: 123.8551);

    expect(uri.toString(), 'https://www.google.com/maps/search/police%20station/@9.649600,123.855100,15z');
  });

  test('nearbySearchUri() falls back to a plain "near me" search with no fix', () {
    final uri = MapsLauncher.nearbySearchUri('hospital');

    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/search/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['query'], 'hospital near me');
  });

  test('nearbySearchUri() needs both coordinates to center the search', () {
    final uri = MapsLauncher.nearbySearchUri('hospital', latitude: 9.6496);

    expect(uri.queryParameters['query'], 'hospital near me');
  });
}
