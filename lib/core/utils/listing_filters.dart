import 'package:geolocator/geolocator.dart';

/// Three coarse spending tiers offered by [SearchFilterSheet] — collapses
/// both Google Places' 0-4 `priceLevel` and the curated catalog's
/// `₱`/`₱₱`/`₱₱₱` `priceRange` strings onto the same scale, so one filter
/// works across live and curated results alike.
enum PriceTier {
  budget,
  midRange,
  premium;

  String get label => switch (this) {
    PriceTier.budget => '₱ Budget-friendly',
    PriceTier.midRange => '₱₱ Mid-range',
    PriceTier.premium => '₱₱₱ Premium',
  };
}

/// Places API (New) reports `priceLevel` 0 (free) through 4 (very
/// expensive) — collapsed onto the same three tiers a traveler picks from.
PriceTier? priceTierFromPlacesLevel(int? level) {
  if (level == null) return null;
  if (level <= 1) return PriceTier.budget;
  if (level == 2) return PriceTier.midRange;
  return PriceTier.premium;
}

/// Curated restaurants store price as a `₱`/`₱₱`/`₱₱₱` string — counts the
/// peso signs rather than assuming a fixed string length, since admin-
/// entered text occasionally carries stray whitespace around it.
PriceTier? priceTierFromPesoSigns(String priceRange) {
  final count = '₱'.allMatches(priceRange).length;
  if (count <= 0) return null;
  if (count == 1) return PriceTier.budget;
  if (count == 2) return PriceTier.midRange;
  return PriceTier.premium;
}

const List<double> kDistanceFilterOptionsKm = [5, 10, 25, 50];

/// Unlike [withinDistance] or the price-tier helpers above, an item with no
/// accessibility data at all does NOT pass a set filter — a traveler
/// filtering for a specific accessibility need is relying on this being
/// accurate, and silently showing an unverified listing (e.g. every live
/// Places result, which never carries this data) would be actively
/// misleading, not just imprecise.
bool matchesAccessibilityTag(List<String> tags, String? required) {
  if (required == null) return true;
  return tags.contains(required);
}

/// True when the point at [lat]/[lng] falls within [maxKm] of [origin] —
/// and also true whenever the comparison can't be made ([maxKm] unset, or
/// either point missing), so a listing with no coordinates on file is never
/// silently dropped by a filter it simply can't be evaluated against.
bool withinDistance({
  required double? lat,
  required double? lng,
  required Position? origin,
  required double? maxKm,
}) {
  if (maxKm == null || origin == null || lat == null || lng == null) return true;
  final km = Geolocator.distanceBetween(origin.latitude, origin.longitude, lat, lng) / 1000;
  return km <= maxKm;
}
