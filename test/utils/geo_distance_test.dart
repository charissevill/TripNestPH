import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/utils/geo_distance.dart';

void main() {
  test('haversineKm() returns 0 for the same point', () {
    expect(haversineKm(14.5995, 120.9842, 14.5995, 120.9842), 0);
  });

  test('haversineKm() matches the known ~111km per degree of latitude at the equator', () {
    final km = haversineKm(0, 0, 1, 0);
    expect(km, closeTo(111.2, 1));
  });

  test('haversineKm() is symmetric and roughly matches the real Manila-Cebu distance', () {
    const manilaLat = 14.5995, manilaLng = 120.9842;
    const cebuLat = 10.3157, cebuLng = 123.8854;

    final forward = haversineKm(manilaLat, manilaLng, cebuLat, cebuLng);
    final backward = haversineKm(cebuLat, cebuLng, manilaLat, manilaLng);

    expect(forward, backward);
    expect(forward, closeTo(570, 50));
  });
}
