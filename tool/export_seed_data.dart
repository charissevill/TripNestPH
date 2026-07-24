// Dumps the Phase 1 mock content as JSON so `tool/seed_firestore.js` can
// push it into Firestore. Deliberately imports only the plain-Dart model
// files (no `package:flutter`) so it can run under a bare `dart run`
// without the Flutter engine.
//
// Usage: dart run tool/export_seed_data.dart > tool/seed_data.json
import 'dart:convert';

import 'package:tripnest_ph/data/mock/mock_destinations.dart';
import 'package:tripnest_ph/data/mock/mock_festivals.dart';
import 'package:tripnest_ph/data/mock/mock_provinces.dart';
import 'package:tripnest_ph/data/mock/mock_regions.dart';
import 'package:tripnest_ph/data/mock/mock_restaurants.dart';

void main() {
  // 'status' gates every traveler-facing query (DestinationRepository/
  // RestaurantRepository/FestivalRepository's `_publishedOnly`) but isn't
  // part of the domain model's toMap() — it's an Admin Portal
  // draft/publish concern, not a destination/restaurant/festival property.
  // This seed script is exactly the "publish this content" step, so it's
  // added here, the same way 'nameLower' is a seed-time derived field.
  final destinations = {
    for (final d in mockDestinations) d.id: {...d.toMap(), 'nameLower': d.name.toLowerCase(), 'status': 'published'},
  };
  final restaurants = {
    for (final r in mockRestaurants) r.id: {...r.toMap(), 'nameLower': r.name.toLowerCase(), 'status': 'published'},
  };
  final festivals = {
    for (final f in mockFestivals) f.id: {...f.toMap(), 'nameLower': f.name.toLowerCase(), 'status': 'published'},
  };
  final regions = {
    for (final r in mockRegions) r.id: r.toMap(),
  };
  final provinces = {
    for (final p in mockProvinces) p.id: p.toMap(),
  };

  // ignore: avoid_print
  print(const JsonEncoder.withIndent('  ').convert({
    'tourist_spots': destinations,
    'restaurants': restaurants,
    'festivals': festivals,
    'regions': regions,
    'provinces': provinces,
  }));
}
