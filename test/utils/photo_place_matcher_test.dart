import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/utils/photo_place_matcher.dart';
import 'package:tripnest_ph/domain/models/destination.dart';
import 'package:tripnest_ph/domain/models/place.dart';
import 'package:tripnest_ph/domain/models/restaurant.dart';

// A base coordinate plus two offsets: ~100m away (within the matcher's
// default ~150m radius) and ~550m away (outside it) — 1 degree of latitude
// is ~111km, so these offsets are picked to land cleanly on either side of
// the default radius regardless of exact haversine rounding.
const double _baseLat = 10.0;
const double _baseLng = 120.0;
const double _nearLat = 10.0009; // ~100m north
const double _farLat = 10.005; // ~555m north

Restaurant _restaurant(String id, String name, {double? latitude, double? longitude}) {
  return Restaurant(
    id: id,
    name: name,
    cuisine: 'Filipino',
    provinceId: 'bohol',
    provinceName: 'Bohol',
    regionId: 'region-7',
    heroImageUrl: '',
    galleryImageUrls: const [],
    rating: 4.5,
    reviewCount: 10,
    priceRange: '₱₱',
    description: '',
    openingHours: '',
    menuHighlights: const [],
    latitude: latitude,
    longitude: longitude,
  );
}

Destination _destination(String id, String name, {double? latitude, double? longitude}) {
  return Destination(
    id: id,
    name: name,
    provinceId: 'bohol',
    provinceName: 'Bohol',
    regionId: 'region-7',
    categoryId: 'nature',
    heroImageUrl: '',
    galleryImageUrls: const [],
    rating: 4.5,
    reviewCount: 10,
    shortDescription: '',
    longDescription: '',
    entranceFee: '',
    bestTimeToVisit: '',
    travelTips: const [],
    highlights: const [],
    latitude: latitude,
    longitude: longitude,
  );
}

Place _place(String id, String name, {double? latitude, double? longitude}) {
  return Place(id: id, name: name, types: const ['tourist_attraction'], latitude: latitude, longitude: longitude);
}

void main() {
  test('matches the nearest restaurant within radius, before checking destinations', () {
    final restaurant = _restaurant('r1', 'Bohol Bee Farm', latitude: _baseLat, longitude: _baseLng);
    final destination = _destination('d1', 'Chocolate Hills', latitude: _baseLat, longitude: _baseLng);

    final match = matchPhotoToPlace(
      _baseLat,
      _baseLng,
      destinations: [destination],
      restaurants: [restaurant],
    );

    expect(match, isNotNull);
    expect(match!.tier, 'curated');
    expect(match.restaurantId, 'r1');
    expect(match.destinationId, isNull);
  });

  test('falls back to the nearest destination when no restaurant is within radius', () {
    final destination = _destination('d1', 'Chocolate Hills', latitude: _nearLat, longitude: _baseLng);

    final match = matchPhotoToPlace(
      _baseLat,
      _baseLng,
      destinations: [destination],
      restaurants: const [],
    );

    expect(match, isNotNull);
    expect(match!.tier, 'curated');
    expect(match.destinationId, 'd1');
  });

  test('falls back to a live Places result when no curated match is within radius', () {
    final place = _place('places/abc', 'Alona Beach', latitude: _nearLat, longitude: _baseLng);

    final match = matchPhotoToPlace(
      _baseLat,
      _baseLng,
      destinations: const [],
      restaurants: const [],
      nearbyPlaces: [place],
    );

    expect(match, isNotNull);
    expect(match!.tier, 'live');
    expect(match.placeId, 'places/abc');
    expect(match.name, 'Alona Beach');
  });

  test('returns null when every candidate is outside the match radius', () {
    final restaurant = _restaurant('r1', 'Bohol Bee Farm', latitude: _farLat, longitude: _baseLng);
    final destination = _destination('d1', 'Chocolate Hills', latitude: _farLat, longitude: _baseLng);
    final place = _place('places/abc', 'Alona Beach', latitude: _farLat, longitude: _baseLng);

    final match = matchPhotoToPlace(
      _baseLat,
      _baseLng,
      destinations: [destination],
      restaurants: [restaurant],
      nearbyPlaces: [place],
    );

    expect(match, isNull);
  });

  test('picks the closest of several restaurants within radius', () {
    final farther = _restaurant('r1', 'Farther Grill', latitude: _nearLat, longitude: _baseLng);
    final closer = _restaurant('r2', 'Closer Cafe', latitude: _baseLat, longitude: _baseLng);

    final match = matchPhotoToPlace(
      _baseLat,
      _baseLng,
      destinations: const [],
      restaurants: [farther, closer],
    );

    expect(match!.restaurantId, 'r2');
  });

  test('ignores a candidate with no coordinates on file', () {
    final noCoords = _restaurant('r1', 'No Coordinates Diner');

    final match = matchPhotoToPlace(
      _baseLat,
      _baseLng,
      destinations: const [],
      restaurants: [noCoords],
    );

    expect(match, isNull);
  });

  test('returns null when nothing is passed at all', () {
    final match = matchPhotoToPlace(_baseLat, _baseLng, destinations: const [], restaurants: const []);

    expect(match, isNull);
  });
}
