import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tripnest_ph/core/utils/listing_filters.dart';

Position _positionAt(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime(2026, 1, 1),
  accuracy: 0,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  group('priceTierFromPlacesLevel()', () {
    test('collapses the 0-4 Places scale onto three tiers', () {
      expect(priceTierFromPlacesLevel(0), PriceTier.budget);
      expect(priceTierFromPlacesLevel(1), PriceTier.budget);
      expect(priceTierFromPlacesLevel(2), PriceTier.midRange);
      expect(priceTierFromPlacesLevel(3), PriceTier.premium);
      expect(priceTierFromPlacesLevel(4), PriceTier.premium);
    });

    test('null when Places reports no price level at all', () {
      expect(priceTierFromPlacesLevel(null), isNull);
    });
  });

  group('priceTierFromPesoSigns()', () {
    test('counts peso signs regardless of surrounding whitespace', () {
      expect(priceTierFromPesoSigns('₱'), PriceTier.budget);
      expect(priceTierFromPesoSigns(' ₱₱ '), PriceTier.midRange);
      expect(priceTierFromPesoSigns('₱₱₱'), PriceTier.premium);
    });

    test('null for empty or unrecognized text', () {
      expect(priceTierFromPesoSigns(''), isNull);
      expect(priceTierFromPesoSigns('Free'), isNull);
    });
  });

  group('withinDistance()', () {
    // Manila and Cebu City are roughly 570km apart.
    const manila = (lat: 14.5995, lng: 120.9842);
    const cebu = (lat: 10.3157, lng: 123.8854);

    test('true when no distance filter is set, regardless of coordinates', () {
      expect(withinDistance(lat: cebu.lat, lng: cebu.lng, origin: _positionAt(manila.lat, manila.lng), maxKm: null), isTrue);
    });

    test('true when the origin or the listing has no coordinates on file', () {
      expect(withinDistance(lat: null, lng: null, origin: _positionAt(manila.lat, manila.lng), maxKm: 10), isTrue);
      expect(withinDistance(lat: cebu.lat, lng: cebu.lng, origin: null, maxKm: 10), isTrue);
    });

    test('true within the radius, false beyond it', () {
      final origin = _positionAt(manila.lat, manila.lng);
      expect(withinDistance(lat: manila.lat, lng: manila.lng, origin: origin, maxKm: 5), isTrue);
      expect(withinDistance(lat: cebu.lat, lng: cebu.lng, origin: origin, maxKm: 50), isFalse);
      expect(withinDistance(lat: cebu.lat, lng: cebu.lng, origin: origin, maxKm: 700), isTrue);
    });
  });
}
