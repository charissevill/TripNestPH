import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../states/empty_state_widget.dart';

/// A full-screen map of pre-built [markers] — used by Explore's List/Map
/// toggle to browse many destinations/restaurants/festivals at once,
/// unlike [MapPreview]'s single-pin, scroll-disabled embed on a details
/// page. Camera centers on and fits every marker automatically; no
/// clustering (see the Explore Map plan — catalog sizes here are small
/// enough that plain markers render fine).
class ExploreMapView extends StatelessWidget {
  const ExploreMapView({super.key, required this.markers, required this.emptyMessage});

  final Set<Marker> markers;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (markers.isEmpty) {
      return EmptyStateWidget(icon: Symbols.map_rounded, title: 'Nothing to show on the map', message: emptyMessage);
    }

    final positions = markers.map((m) => m.position).toList();
    final centroid = LatLng(
      positions.map((p) => p.latitude).reduce((a, b) => a + b) / positions.length,
      positions.map((p) => p.longitude).reduce((a, b) => a + b) / positions.length,
    );

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: centroid, zoom: 6),
      markers: markers,
      // Keeps Google's own bottom-right zoom controls clear of the app's
      // persistent AI chat FAB, which sits in that same corner on every tab.
      padding: const EdgeInsets.only(bottom: 90),
      onMapCreated: (controller) {
        if (positions.length < 2) {
          controller.animateCamera(CameraUpdate.newLatLngZoom(centroid, 13));
          return;
        }
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
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 48));
      },
    );
  }
}
