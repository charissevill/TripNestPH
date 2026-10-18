import 'package:geolocator/geolocator.dart';

/// Why [LocationService.resolveCurrentPosition] doesn't have a position,
/// so the UI can offer the right recovery action instead of just hiding
/// the "Nearby You" section with no explanation.
enum LocationAccessStatus {
  granted,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class LocationResult {
  const LocationResult({required this.status, this.position});

  final LocationAccessStatus status;
  final Position? position;

  bool get isGranted => status == LocationAccessStatus.granted && position != null;

  /// True when asking again could work (a fresh OS permission prompt) —
  /// as opposed to [LocationAccessStatus.permissionDeniedForever] or
  /// [LocationAccessStatus.serviceDisabled], which need a trip to Settings.
  bool get canRetryInApp => status == LocationAccessStatus.permissionDenied;
}

/// Thin wrapper around Geolocator: permission handling plus a
/// distance-in-kilometers helper used to sort destinations/restaurants by
/// proximity to the traveler.
class LocationService {
  Future<LocationResult> resolveCurrentPosition() => _resolve();

  /// Same as [resolveCurrentPosition], but gives up on the GPS fix after
  /// [timeLimit] (reported as [LocationAccessStatus.unavailable]) — for a
  /// caller that must act promptly either way, like the Emergency sheet's
  /// Find Nearby buttons. The permission prompt itself isn't timed, so a
  /// traveler still reading it never gets cut off.
  Future<LocationResult> resolveCurrentPositionWithin(Duration timeLimit) => _resolve(timeLimit: timeLimit);

  Future<LocationResult> _resolve({Duration? timeLimit}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult(status: LocationAccessStatus.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const LocationResult(status: LocationAccessStatus.permissionDenied);
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(status: LocationAccessStatus.permissionDeniedForever);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: timeLimit),
      );
      return LocationResult(status: LocationAccessStatus.granted, position: position);
    } catch (_) {
      return const LocationResult(status: LocationAccessStatus.unavailable);
    }
  }

  /// Re-shows the OS permission dialog — only meaningful when the previous
  /// result was [LocationAccessStatus.permissionDenied] (a plain "not yet
  /// granted"), since a permanent denial or disabled service won't
  /// re-prompt and needs [openAppSettings]/[openLocationSettings] instead.
  Future<LocationResult> retry() => resolveCurrentPosition();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Distance between two coordinates, in kilometers.
  double distanceKm({required double lat1, required double lng1, required double lat2, required double lng2}) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }
}
