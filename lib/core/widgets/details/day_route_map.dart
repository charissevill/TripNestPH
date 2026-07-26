import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../routes/route_paths.dart';
import '../../theme/app_spacing.dart';
import '../../utils/itinerary_route_matcher.dart';
import '../../utils/maps_launcher.dart';

/// A small, embedded map showing one day's real, coordinate-resolved stops
/// (see [matchDayToRoute]) connected by a route line, plus a link to open
/// the same route for real turn-by-turn directions. Scroll gestures stay
/// disabled since this sits inside a scrolling itinerary day card — same
/// "embedded, not full-screen" reasoning as `MapPreview`, unlike
/// `ExploreMapView`'s full-screen browsing map.
class DayRouteMap extends StatelessWidget {
  const DayRouteMap({super.key, required this.stops});

  final List<RouteStop> stops;

  @override
  Widget build(BuildContext context) {
    if (stops.length < 2) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final positions = stops.map((s) => LatLng(s.latitude, s.longitude)).toList();
    final centroid = LatLng(
      positions.map((p) => p.latitude).reduce((a, b) => a + b) / positions.length,
      positions.map((p) => p.longitude).reduce((a, b) => a + b) / positions.length,
    );
    final bounds = LatLngBounds(
      southwest: LatLng(
        positions.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
        positions.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        positions.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
        positions.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: SizedBox(
            height: 180,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: centroid, zoom: 13),
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
                        }
                      },
                    ),
                  ),
              },
              polylines: {
                Polyline(polylineId: const PolylineId('route'), points: positions, color: theme.colorScheme.primary, width: 4),
              },
              scrollGesturesEnabled: false,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              onMapCreated: (controller) => controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 32)),
            ),
          ),
        ),
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
    );
  }
}
