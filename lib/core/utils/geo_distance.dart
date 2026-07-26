import 'dart:math' as math;

/// Straight-line (haversine) distance between two coordinates, in
/// kilometers — same formula `Place`'s own internal distance calculation
/// uses, exposed here as a shared utility so callers outside that model
/// (e.g. `AiRepository`, sorting Firestore-sourced candidates) can use it
/// too.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degToRad(double deg) => deg * (math.pi / 180);
