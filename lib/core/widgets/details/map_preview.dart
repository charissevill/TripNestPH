import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/maps_launcher.dart';

/// A small, pinch-zoomable map preview pinned at a destination/restaurant/
/// festival's coordinates, with a tap-to-open-in-Google-Maps affordance for
/// real directions. Renders a neutral placeholder instead of an empty map
/// when no coordinates are available for a listing.
class MapPreview extends StatelessWidget {
  const MapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.label,
    this.height = 160,
  });

  final double? latitude;
  final double? longitude;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final lat = latitude;
    final lng = longitude;

    if (lat == null || lng == null) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: const Icon(Symbols.location_off_rounded, color: AppColors.textTertiary, size: 28),
      );
    }

    final position = LatLng(lat, lng);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: position, zoom: 14),
              markers: {Marker(markerId: const MarkerId('location'), position: position)},
              // Scroll stays disabled: this map sits inside a scrolling detail page, and a
              // single-finger drag needs to keep scrolling the page rather than panning the
              // map. Pinch-zoom and two-finger rotate/tilt don't conflict with that, and the
              // zoom controls give a no-drag way to explore.
              zoomControlsEnabled: true,
              scrollGesturesEnabled: false,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              zoomGesturesEnabled: true,
              liteModeEnabled: false,
            ),
            Positioned(
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: _OpenInMapsButton(onTap: () => MapsLauncher.openDirections(latitude: lat, longitude: lng, label: label)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenInMapsButton extends StatelessWidget {
  const _OpenInMapsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.open_in_new_rounded, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text('Open in Maps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
            ],
          ),
        ),
      ),
    );
  }
}
