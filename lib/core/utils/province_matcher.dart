import '../../domain/models/province.dart';

/// Resolves a live Places result's free-text address to a known [Province]
/// by name-containment — the same style of match `search_screen.dart` uses
/// to relate an address to a province/region. A `Place` has no province
/// reference of its own, but the AI Planner requires one (restaurant
/// candidates, emergency hotlines). Longest matching name wins, so a short
/// province name doesn't false-match as a substring of a different one
/// (e.g. "Davao" inside "Davao del Sur").
Province? matchProvinceByAddress(String address, List<Province> provinces) {
  final addressLower = address.toLowerCase();
  final matches = provinces.where((p) => addressLower.contains(p.name.toLowerCase()));
  if (matches.isEmpty) return null;
  return matches.reduce((a, b) => a.name.length >= b.name.length ? a : b);
}
