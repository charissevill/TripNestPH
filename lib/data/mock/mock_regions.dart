import '../../domain/models/region.dart';

/// All 17 official Philippine regions — a fixed, well-established taxonomy
/// seeded once via `tool/seed_firestore.js`, never expected to change.
final List<Region> mockRegions = [
  const Region(id: 'ncr', name: 'National Capital Region', islandGroup: 'Luzon'),
  const Region(id: 'car', name: 'Cordillera Administrative Region', islandGroup: 'Luzon'),
  const Region(id: 'region-1', name: 'Ilocos Region', islandGroup: 'Luzon'),
  const Region(id: 'region-2', name: 'Cagayan Valley', islandGroup: 'Luzon'),
  const Region(id: 'region-3', name: 'Central Luzon', islandGroup: 'Luzon'),
  const Region(id: 'region-4a', name: 'CALABARZON', islandGroup: 'Luzon'),
  const Region(id: 'region-4b', name: 'MIMAROPA', islandGroup: 'Luzon'),
  const Region(id: 'region-5', name: 'Bicol Region', islandGroup: 'Luzon'),
  const Region(id: 'region-6', name: 'Western Visayas', islandGroup: 'Visayas'),
  const Region(id: 'region-7', name: 'Central Visayas', islandGroup: 'Visayas'),
  const Region(id: 'region-8', name: 'Eastern Visayas', islandGroup: 'Visayas'),
  const Region(id: 'region-9', name: 'Zamboanga Peninsula', islandGroup: 'Mindanao'),
  const Region(id: 'region-10', name: 'Northern Mindanao', islandGroup: 'Mindanao'),
  const Region(id: 'region-11', name: 'Davao Region', islandGroup: 'Mindanao'),
  const Region(id: 'region-12', name: 'SOCCSKSARGEN', islandGroup: 'Mindanao'),
  const Region(id: 'region-13', name: 'Caraga', islandGroup: 'Mindanao'),
  const Region(id: 'barmm', name: 'Bangsamoro Autonomous Region in Muslim Mindanao', islandGroup: 'Mindanao'),
];
