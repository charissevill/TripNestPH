import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/utils/polyline_decoder.dart';

void main() {
  test('decodePolyline() matches Google\'s own published example', () {
    // From https://developers.google.com/maps/documentation/utilities/polylinealgorithm
    final points = decodePolyline(r'_p~iF~ps|U_ulLnnqC_mqNvxq`@');

    expect(points, hasLength(3));
    expect(points[0].latitude, closeTo(38.5, 0.0001));
    expect(points[0].longitude, closeTo(-120.2, 0.0001));
    expect(points[1].latitude, closeTo(40.7, 0.0001));
    expect(points[1].longitude, closeTo(-120.95, 0.0001));
    expect(points[2].latitude, closeTo(43.252, 0.0001));
    expect(points[2].longitude, closeTo(-126.453, 0.0001));
  });

  test('decodePolyline() returns an empty list for an empty string', () {
    expect(decodePolyline(''), isEmpty);
  });
}
