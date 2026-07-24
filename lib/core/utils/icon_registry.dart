import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Maps a stable string key to a [IconData] so travel tips, itinerary
/// activities, budget items and weather forecasts can be persisted to
/// Firestore as plain JSON (icons can't be serialized directly) while the
/// UI still renders real Material Symbols.
class IconRegistry {
  IconRegistry._();

  static final Map<String, IconData> _icons = {
    'wb_sunny': Symbols.wb_sunny_rounded,
    'wb_cloudy': Symbols.wb_cloudy_rounded,
    'cloud': Symbols.cloud_rounded,
    'rainy': Symbols.rainy_rounded,
    'thunderstorm': Symbols.thunderstorm_rounded,
    'foggy': Symbols.foggy_rounded,
    'payments': Symbols.payments_rounded,
    'directions_boat': Symbols.directions_boat_rounded,
    'diversity_3': Symbols.diversity_3_rounded,
    'sim_card': Symbols.sim_card_rounded,
    'hotel': Symbols.hotel_rounded,
    'restaurant': Symbols.restaurant_rounded,
    'hiking': Symbols.hiking_rounded,
    'flight_land': Symbols.flight_land_rounded,
    'flight_takeoff': Symbols.flight_takeoff_rounded,
    'beach_access': Symbols.beach_access_rounded,
    'lunch_dining': Symbols.lunch_dining_rounded,
    'local_pizza': Symbols.local_pizza_rounded,
    'shopping_bag': Symbols.shopping_bag_rounded,
    'eco': Symbols.eco_rounded,
    'celebration': Symbols.celebration_rounded,
    'landscape': Symbols.landscape_rounded,
    'forest': Symbols.forest_rounded,
    'account_balance': Symbols.account_balance_rounded,
  };

  static IconData resolve(String key) => _icons[key] ?? Symbols.travel_explore_rounded;

  /// Reverse lookup used only when authoring/seeding content in code.
  static String keyFor(IconData icon) =>
      _icons.entries.firstWhere((e) => e.value == icon, orElse: () => _icons.entries.first).key;
}
