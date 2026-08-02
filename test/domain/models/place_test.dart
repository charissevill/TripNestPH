import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/domain/models/place.dart';

/// Recursively rebuilds [value] using `Map<Object?, Object?>` for every
/// nested map, matching what the `cloud_functions` platform channel
/// actually hands back on a real device — plain Dart map literals in a test
/// (`{'text': 'Alona Beach'}`) are NOT representative, since Dart infers a
/// narrower static type for those that happens to satisfy a direct
/// `as Map<String, dynamic>` cast. Only a genuinely `Map<Object?, Object?>`
/// nested value reproduces the real-device crash this test guards against.
Object? _asPlatformChannelShape(Object? value) {
  if (value is Map) {
    final result = <Object?, Object?>{};
    value.forEach((k, v) => result[k] = _asPlatformChannelShape(v));
    return result;
  }
  if (value is List) {
    return value.map(_asPlatformChannelShape).toList();
  }
  return value;
}

void main() {
  test(
    'Place.fromJson parses a real place without throwing on platform-channel-shaped nested maps',
    () {
      // Shaped after the real Places API (New) response for a bare
      // "bacolod, Philippines" text search — this exact payload used to
      // throw `type '_Map<Object?, Object?>' is not a subtype of type
      // 'Map<String, dynamic>?' in type cast` inside `Place.fromJson`,
      // which `PlacesService.searchText`'s catch-all then silently turned
      // into an empty result list (see the "no results for bacolod" fix).
      final raw =
          _asPlatformChannelShape({
                'id': 'ChIJW3hh3q7RrjMRa_eJG1Ryeeo',
                'types': ['locality', 'political'],
                'displayName': {'text': 'Bacolod', 'languageCode': 'en'},
                'formattedAddress': 'Bacolod, Negros Occidental, Philippines',
                'location': {'latitude': 10.6676405, 'longitude': 122.9455627},
                'photos': [
                  {
                    'name': 'places/ChIJW3hh3q7RrjMRa_eJG1Ryeeo/photos/AWCwyd',
                    'widthPx': 4000,
                    'heightPx': 3000,
                  },
                ],
                'currentOpeningHours': {'openNow': true},
                'regularOpeningHours': {
                  'weekdayDescriptions': ['Monday: Open 24 hours'],
                },
                'editorialSummary': {'text': 'A city in Negros Occidental'},
              })
              as Map<Object?, Object?>;

      final place = Place.fromJson(Map<String, dynamic>.from(raw));

      expect(place.id, 'ChIJW3hh3q7RrjMRa_eJG1Ryeeo');
      expect(place.name, 'Bacolod');
      expect(place.types, ['locality', 'political']);
      expect(place.latitude, 10.6676405);
      expect(place.longitude, 122.9455627);
      expect(place.hasCoordinates, isTrue);
      expect(place.photoNames, ['places/ChIJW3hh3q7RrjMRa_eJG1Ryeeo/photos/AWCwyd']);
      expect(place.isOpenNow, isTrue);
      expect(place.weekdayDescriptions, ['Monday: Open 24 hours']);
      expect(place.editorialSummary, 'A city in Negros Occidental');
    },
  );

  test('Place.fromJson tolerates missing optional nested fields', () {
    final raw =
        _asPlatformChannelShape({'id': 'p1', 'types': <String>[]})
            as Map<Object?, Object?>;

    final place = Place.fromJson(Map<String, dynamic>.from(raw));

    expect(place.id, 'p1');
    expect(place.name, '');
    expect(place.hasCoordinates, isFalse);
    expect(place.photoNames, isEmpty);
    expect(place.isOpenNow, isNull);
  });
}
