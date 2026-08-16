import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Single source of truth for every fixed option/default the AI Planner
/// form (and anywhere else that builds an `AiItineraryRequest` — AI Chat's
/// "Generate Full Itinerary", the itinerary screen's Regenerate/Refine)
/// needs to agree on. Previously each of those screens reimplemented its
/// own copy of these same literals (budget tier ranges, the "Van / Car
/// Rental" fallback, the 1-14 day cap), which could silently drift out of
/// sync — e.g. a range changed in the Planner form but not in the other two
/// places that separately hardcoded it.
class BudgetTier {
  const BudgetTier(this.label, this.range, this.minTotal, this.icon);

  final String label;
  final String range;

  /// The lower peso bound this tier's range starts at — used by
  /// [inferBudgetTier] to reverse-infer a tier from an already-generated
  /// `totalBudget`, since neither `Itinerary` nor `SavedItinerary` persist
  /// the original request's tier.
  final double minTotal;
  final IconData icon;
}

const List<BudgetTier> budgetTiers = [
  BudgetTier('Budget', '₱5k – ₱15k', 5000, Symbols.savings_rounded),
  BudgetTier('Mid-range', '₱15k – ₱40k', 15000, Symbols.account_balance_wallet_rounded),
  BudgetTier('Luxury', '₱40k+', 40000, Symbols.diamond_rounded),
];

/// Highest tier whose [BudgetTier.minTotal] `totalBudget` clears, falling
/// back to the lowest tier if it doesn't clear even that one.
(String label, String range) inferBudgetTier(double totalBudget) {
  for (final tier in budgetTiers.reversed) {
    if (totalBudget >= tier.minTotal) return (tier.label, tier.range);
  }
  final lowest = budgetTiers.first;
  return (lowest.label, lowest.range);
}

const List<(String, IconData)> transportOptions = [
  ('Flight', Symbols.flight_rounded),
  ('Van / Car Rental', Symbols.directions_car_rounded),
  ('Bus', Symbols.directions_bus_rounded),
  ('Ferry / Boat', Symbols.directions_boat_rounded),
  ('Motorbike', Symbols.two_wheeler_rounded),
];

const List<(String, IconData)> interestOptions = [
  ('Beaches', Symbols.beach_access_rounded),
  ('Mountains', Symbols.landscape_rounded),
  ('Food', Symbols.restaurant_rounded),
  ('Culture & Heritage', Symbols.account_balance_rounded),
  ('Adventure', Symbols.hiking_rounded),
  ('Festivals', Symbols.celebration_rounded),
  ('Nature', Symbols.forest_rounded),
  ('Nightlife', Symbols.nightlife_rounded),
];

const List<(String, IconData)> travelerTypeOptions = [
  ('Solo', Symbols.person_rounded),
  ('Couple', Symbols.favorite_rounded),
  ('Family', Symbols.family_restroom_rounded),
  ('Friends', Symbols.groups_rounded),
];

/// Single-select, unlike [interestOptions] (which activities to lean
/// toward) — this is about overall pacing/density, woven into the same one
/// generation call as every other form field rather than generating
/// multiple full itineraries to choose between (2-3x the Groq/Places cost
/// for every single trip, whether or not the traveler even wanted a
/// choice).
const List<(String, IconData)> tripPaceOptions = [
  ('Relaxed', Symbols.self_improvement_rounded),
  ('Balanced', Symbols.balance_rounded),
  ('Adventure-Packed', Symbols.hiking_rounded),
  ('Foodie Focus', Symbols.restaurant_rounded),
  ('Culture Deep-dive', Symbols.museum_rounded),
];

/// Used wherever an `AiItineraryRequest` is built without asking the
/// traveler for transportation/interests directly (Regenerate, Refine, AI
/// Chat's "Generate Full Itinerary") — a reasonable generic default rather
/// than leaving the fields empty.
const String defaultTransportation = 'Van / Car Rental';
const Set<String> defaultInterests = {'Beaches', 'Food'};

const int minTripDays = 1;
const int maxTripDays = 14;
