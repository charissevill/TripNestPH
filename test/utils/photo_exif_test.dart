import 'package:exif/exif.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/utils/photo_exif.dart';

void main() {
  group('decimalDegreesFromDms()', () {
    test('converts a north/east DMS triple to a positive decimal', () {
      // 9° 32' 13.92" ≈ 9.5372° — Bohol Bee Farm's real latitude, used
      // elsewhere in this app's own test fixtures.
      final dms = [Ratio(9, 1), Ratio(32, 1), Ratio(1392, 100)];

      final decimal = decimalDegreesFromDms(dms, 'N');

      expect(decimal, closeTo(9.5372, 0.0001));
    });

    test('negates the result for a south/west reference', () {
      final dms = [Ratio(9, 1), Ratio(32, 1), Ratio(1392, 100)];

      final decimal = decimalDegreesFromDms(dms, 'S');

      expect(decimal, closeTo(-9.5372, 0.0001));
    });

    test('treats a west reference as negative for longitude', () {
      final dms = [Ratio(123, 1), Ratio(45, 1), Ratio(6, 1)];

      final decimal = decimalDegreesFromDms(dms, 'W');

      expect(decimal, lessThan(0));
    });

    test('returns null when fewer than 3 DMS components are given', () {
      final decimal = decimalDegreesFromDms([Ratio(9, 1), Ratio(32, 1)], 'N');

      expect(decimal, isNull);
    });
  });
}
