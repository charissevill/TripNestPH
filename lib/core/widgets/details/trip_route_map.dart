import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../routes/route_paths.dart';
import '../../services/routes_service.dart';
import '../../theme/app_spacing.dart';
import '../../utils/itinerary_route_matcher.dart';
import '../../utils/maps_launcher.dart';

/// A small, embedded map showing one day's real, coordinate-resolved stops
/// (see [matchDayToRoute]) connected by a route line, plus a link to open
/// the same route for real turn-by-turn directions. A single-stop day (see
/// `matchDayToRoute`'s destination-anchor fallback) just shows one centered
/// pin with no line/"Open Route" link, since there's nothing to route
/// between. Pan and zoom (pinch and the on-screen buttons) all stay enabled
/// — Google Maps handles gesture priority within its own bounds on its own,
/// so dragging on the map pans it rather than fighting the itinerary page's
/// outer scroll.
///
/// Draws a straight line between stops immediately (so the map is never
/// blank), then swaps to a real, road-following route with per-leg travel
/// times once [RoutesService] resolves — a pure progressive enhancement,
/// silently keeping the straight line if that call fails for any reason.
/// The camera re-fits to bounds again once the real route arrives, since a
/// road can bow outside the straight-line bounding box of the stops
/// themselves.
class TripRouteMap extends StatefulWidget {
  const TripRouteMap({super.key, required this.stops});

  final List<RouteStop> stops;

  @override
  State<TripRouteMap> createState() => _TripRouteMapState();
}

class _TripRouteMapState extends State<TripRouteMap> {
  final RoutesService _routesService = RoutesService();
  TripRoute? _realRoute;
  GoogleMapController? _controller;

  @override
  void initState() {
    super.initState();
    _loadRealRoute();
  }

  Future<void> _loadRealRoute() async {
    final route = await _routesService.computeRoute(widget.stops);
    if (!mounted || !route.hasRoute) return;
    setState(() => _realRoute = route);
    await _fitCamera(route.polylinePoints);
  }

  Future<void> _fitCamera(List<LatLng> points) async {
    final controller = _controller;
    if (controller == null) return;
    if (points.length < 2) {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 14));
    } else {
      await controller.animateCamera(CameraUpdate.newLatLngBounds(_boundsFor(points), 32));
    }
  }

  List<LatLng> get _currentPolylinePoints {
    final realRoute = _realRoute;
    if (realRoute != null && realRoute.hasRoute) return realRoute.polylinePoints;
    return widget.stops.map((s) => LatLng(s.latitude, s.longitude)).toList();
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    return LatLngBounds(
      southwest: LatLng(
        points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
        points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
        points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.stops;
    if (stops.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final polylinePoints = _currentPolylinePoints;
    final centroid = LatLng(
      polylinePoints.map((p) => p.latitude).reduce((a, b) => a + b) / polylinePoints.length,
      polylinePoints.map((p) => p.longitude).reduce((a, b) => a + b) / polylinePoints.length,
    );
    final realRoute = _realRoute;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: SizedBox(
            height: 220,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: centroid, zoom: 12),
              markers: {
                for (final stop in stops)
                  Marker(
                    markerId: MarkerId('${stop.time}-${stop.name}'),
                    position: LatLng(stop.latitude, stop.longitude),
                    infoWindow: InfoWindow(
                      title: '${stop.time}: ${stop.name}',
                      onTap: () {
                        if (stop.destinationId != null) {
                          context.push(RoutePaths.destinationDetails(stop.destinationId!));
                        } else if (stop.restaurantId != null) {
                          context.push(RoutePaths.restaurantDetails(stop.restaurantId!));
                        } else if (stop.placeMapsUri != null) {
                          MapsLauncher.openUrl(stop.placeMapsUri!);
                        }
                      },
                    ),
                  ),
              },
              polylines: polylinePoints.length < 2
                  ? const {}
                  : {
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: polylinePoints,
                        color: theme.colorScheme.primary,
                        width: 4,
                      ),
                    },
              scrollGesturesEnabled: true,
              zoomControlsEnabled: true,
              zoomGesturesEnabled: true,
              myLocationButtonEnabled: false,
              onMapCreated: (controller) {
                _controller = controller;
                _fitCamera(polylinePoints);
              },
            ),
          ),
        ),
        if (stops.length >= 2) ...[
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: () => MapsLauncher.openMultiStopDirections(stops),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Symbols.directions_rounded, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text('Open Route in Maps', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
              ],
            ),
          ),
        ],
        if (realRoute != null && realRoute.legs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Travel Times', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          ...List.generate(realRoute.legs.length, (i) {
            final leg = realRoute.legs[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${stops[i].name} → ${stops[i + 1].name}: ~${leg.durationMinutes} mins (${leg.distanceKm.toStringAsFixed(1)} km)',
                style: theme.textTheme.bodySmall,
              ),
            );
          }),
        ],
      ],
    );
  }
}
