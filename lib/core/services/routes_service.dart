import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/function_caller.dart';
import '../utils/itinerary_route_matcher.dart';
import '../utils/polyline_decoder.dart';

/// Real driving time/distance between two consecutive stops in a
/// [TripRoute] — index i is the leg from stop i to stop i+1.
class RouteLeg {
  const RouteLeg({required this.durationMinutes, required this.distanceKm});

  final int durationMinutes;
  final double distanceKm;
}

/// A real, road-following route through a trip's matched stops.
/// [polylinePoints] is empty when no real route could be computed — callers
/// should keep whatever straight-line fallback they already have.
class TripRoute {
  const TripRoute({required this.polylinePoints, required this.legs});

  final List<LatLng> polylinePoints;
  final List<RouteLeg> legs;

  bool get hasRoute => polylinePoints.isNotEmpty;
}

/// Thin wrapper around the `computeTripRoute` Cloud Function, which proxies
/// Routes API — same key-exposure/best-effort reasoning as `PlacesService`:
/// a real route is a progressive enhancement over the straight-line
/// fallback `TripRouteMap` already draws, never worth failing over.
class RoutesService {
  RoutesService({FunctionCaller? caller}) : _call = caller ?? firebaseFunctionCaller();

  final FunctionCaller _call;

  /// Computes a real driving route through [stops], in order. Returns an
  /// empty [TripRoute] (never throws) if there are fewer than 2 stops or
  /// the Cloud Function/Routes API call fails for any reason.
  Future<TripRoute> computeRoute(List<RouteStop> stops) async {
    if (stops.length < 2) return const TripRoute(polylinePoints: [], legs: []);
    try {
      final result = await _call('computeTripRoute', {
        'waypoints': stops.map((s) => {'latitude': s.latitude, 'longitude': s.longitude}).toList(),
      });
      final encodedPolyline = result['encodedPolyline'] as String?;
      if (encodedPolyline == null || encodedPolyline.isEmpty) {
        return const TripRoute(polylinePoints: [], legs: []);
      }
      final legs = (result['legs'] as List? ?? const [])
          .map(
            (l) => RouteLeg(
              durationMinutes: ((l['durationSeconds'] as num? ?? 0) / 60).round(),
              distanceKm: (l['distanceMeters'] as num? ?? 0) / 1000,
            ),
          )
          .toList();
      return TripRoute(polylinePoints: decodePolyline(encodedPolyline), legs: legs);
    } catch (_) {
      return const TripRoute(polylinePoints: [], legs: []);
    }
  }
}
