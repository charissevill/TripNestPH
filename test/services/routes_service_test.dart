import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/services/routes_service.dart';
import 'package:tripnest_ph/core/utils/itinerary_route_matcher.dart';

const _stopA = RouteStop(time: 'Morning', name: 'Stop A', latitude: 9.82, longitude: 123.38);
const _stopB = RouteStop(time: 'Afternoon', name: 'Stop B', latitude: 9.83, longitude: 123.40);

void main() {
  test('computeRoute() decodes a successful response into a TripRoute', () async {
    final service = RoutesService(
      caller: (name, data) async {
        expect(name, 'computeTripRoute');
        expect(data['waypoints'], [
          {'latitude': 9.82, 'longitude': 123.38},
          {'latitude': 9.83, 'longitude': 123.40},
        ]);
        return {
          'encodedPolyline': r'_p~iF~ps|U_ulLnnqC_mqNvxq`@',
          'legs': [
            {'durationSeconds': 900, 'distanceMeters': 5300},
          ],
        };
      },
    );

    final route = await service.computeRoute([_stopA, _stopB]);

    expect(route.hasRoute, isTrue);
    expect(route.polylinePoints, hasLength(3));
    expect(route.legs, hasLength(1));
    expect(route.legs[0].durationMinutes, 15);
    expect(route.legs[0].distanceKm, closeTo(5.3, 0.001));
  });

  test('computeRoute() returns an empty route when the call throws', () async {
    final service = RoutesService(caller: (name, data) async => throw Exception('network error'));

    final route = await service.computeRoute([_stopA, _stopB]);

    expect(route.hasRoute, isFalse);
    expect(route.legs, isEmpty);
  });

  test('computeRoute() returns an empty route when no polyline is returned', () async {
    final service = RoutesService(caller: (name, data) async => {'encodedPolyline': null, 'legs': <dynamic>[]});

    final route = await service.computeRoute([_stopA, _stopB]);

    expect(route.hasRoute, isFalse);
  });

  test('computeRoute() skips the call entirely with fewer than 2 stops', () async {
    var called = false;
    final service = RoutesService(
      caller: (name, data) async {
        called = true;
        return {};
      },
    );

    final route = await service.computeRoute([_stopA]);

    expect(called, isFalse);
    expect(route.hasRoute, isFalse);
  });
}
