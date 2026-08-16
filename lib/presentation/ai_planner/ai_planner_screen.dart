import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../ai/models/itinerary_request.dart';
import '../../ai/providers/ai_planner_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/services/places_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/inputs/search_bar_widget.dart';
import '../../core/widgets/layout/max_width_container.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/place.dart';
import '../../domain/models/province.dart';

class _BudgetTier {
  const _BudgetTier(this.label, this.range, this.icon);

  final String label;
  final String range;
  final IconData icon;
}

const List<_BudgetTier> _budgetTiers = [
  _BudgetTier('Budget', '₱5k – ₱15k', Symbols.savings_rounded),
  _BudgetTier(
    'Mid-range',
    '₱15k – ₱40k',
    Symbols.account_balance_wallet_rounded,
  ),
  _BudgetTier('Luxury', '₱40k+', Symbols.diamond_rounded),
];

const List<(String, IconData)> _transportOptions = [
  ('Flight', Symbols.flight_rounded),
  ('Van / Car Rental', Symbols.directions_car_rounded),
  ('Bus', Symbols.directions_bus_rounded),
  ('Ferry / Boat', Symbols.directions_boat_rounded),
  ('Motorbike', Symbols.two_wheeler_rounded),
];

const List<(String, IconData)> _interestOptions = [
  ('Beaches', Symbols.beach_access_rounded),
  ('Mountains', Symbols.landscape_rounded),
  ('Food', Symbols.restaurant_rounded),
  ('Culture & Heritage', Symbols.account_balance_rounded),
  ('Adventure', Symbols.hiking_rounded),
  ('Festivals', Symbols.celebration_rounded),
  ('Nature', Symbols.forest_rounded),
  ('Nightlife', Symbols.nightlife_rounded),
];

const List<(String, IconData)> _travelerTypeOptions = [
  ('Solo', Symbols.person_rounded),
  ('Couple', Symbols.favorite_rounded),
  ('Family', Symbols.family_restroom_rounded),
  ('Friends', Symbols.groups_rounded),
];

/// Single-select, unlike [_interestOptions] (which activities to lean
/// toward) — this is about overall pacing/density, woven into the same one
/// generation call as every other form field rather than generating
/// multiple full itineraries to choose between (2-3x the Groq/Places cost
/// for every single trip, whether or not the traveler even wanted a
/// choice).
const List<(String, IconData)> _tripPaceOptions = [
  ('Relaxed', Symbols.self_improvement_rounded),
  ('Balanced', Symbols.balance_rounded),
  ('Adventure-Packed', Symbols.hiking_rounded),
  ('Foodie Focus', Symbols.restaurant_rounded),
  ('Culture Deep-dive', Symbols.museum_rounded),
];

/// The AI itinerary request form: destination, budget tier, trip length,
/// traveler count/type, transportation and interests, ending in a large
/// "Generate Itinerary" call to action that hands off to [AiPlannerProvider].
class AiPlannerScreen extends StatefulWidget {
  const AiPlannerScreen({super.key});

  @override
  State<AiPlannerScreen> createState() => _AiPlannerScreenState();
}

class _AiPlannerScreenState extends State<AiPlannerScreen> {
  Destination? _destination;

  /// Set instead of [_destination] when the traveler wants an itinerary
  /// built around an entire province rather than one specific spot — the
  /// two are mutually exclusive, cleared whenever the other is picked.
  Province? _province;

  /// Set via "Plan a Trip Here" on a live Places result (see
  /// `PlaceDetailsSheet`) — always paired with [_province] (the resolved
  /// province backing it, never set alone), so every existing
  /// `_destination == null && _province == null` gate below still works
  /// unmodified. Cleared whenever the traveler manually re-picks a
  /// destination via [_pickDestination].
  Place? _placeDestination;

  @override
  void initState() {
    super.initState();
    final pending = context.read<AiPlannerProvider>().takePendingDestination();
    if (pending != null) {
      _placeDestination = pending.place;
      _province = pending.province;
    }
  }

  /// Where the traveler said they're staying — optional, searched via
  /// [PlacesService]. When set, [AiRepository] sorts candidate restaurants/
  /// attractions by distance from here. Cleared whenever the destination
  /// changes, since a hotel picked for one destination rarely makes sense
  /// once a different one is chosen.
  Place? _accommodation;
  int _budgetTierIndex = 1;
  int _days = 3;
  int _travelers = 2;
  String _travelerType = 'Couple';
  final Set<String> _transportation = {'Van / Car Rental'};
  final Set<String> _interests = {'Beaches', 'Food'};
  String _tripPace = 'Balanced';

  /// Solo/Couple are exactly what they say; Family/Friends are open-ended
  /// group sizes. Keeps "How many travelers?" and "Who's traveling?" from
  /// ever contradicting each other instead of validating after the fact.
  (int, int) _travelerRangeFor(String type) {
    switch (type) {
      case 'Solo':
        return (1, 1);
      case 'Couple':
        return (2, 2);
      default:
        return (2, 15);
    }
  }

  String _travelerRangeHint(String type) {
    switch (type) {
      case 'Solo':
        return 'Solo trips are set to 1 traveler.';
      case 'Couple':
        return 'Couple trips are set to 2 travelers.';
      default:
        return '$type trips need at least 2 travelers.';
    }
  }

  Future<void> _editDays() async {
    final value = await _promptForNumber(
      context,
      title: 'How many days?',
      initial: _days,
      min: 1,
      max: 14,
    );
    if (value != null) setState(() => _days = value);
  }

  Future<void> _editTravelers() async {
    final (min, max) = _travelerRangeFor(_travelerType);
    final value = await _promptForNumber(
      context,
      title: 'How many travelers?',
      initial: _travelers,
      min: min,
      max: max,
    );
    if (value != null) setState(() => _travelers = value);
  }

  Future<void> _pickDestination() async {
    final selected = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _DestinationPickerSheet(
        currentDestination: _destination,
        currentProvince: _province,
      ),
    );
    if (selected is Destination) {
      setState(() {
        _destination = selected;
        _province = null;
        _placeDestination = null;
        _accommodation = null;
      });
    } else if (selected is Province) {
      setState(() {
        _province = selected;
        _destination = null;
        _placeDestination = null;
        _accommodation = null;
      });
    }
  }

  Future<void> _pickAccommodation() async {
    final selected = await showModalBottomSheet<Place>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AccommodationPickerSheet(
        destination: _destination,
        province: _province,
      ),
    );
    if (selected != null) setState(() => _accommodation = selected);
  }

  Future<void> _generate() async {
    final destination = _destination;
    final place = _placeDestination;
    final province = _province;
    if (destination == null && place == null && province == null) return;
    final tier = _budgetTiers[_budgetTierIndex];

    final planner = context.read<AiPlannerProvider>();
    final itinerary = await planner.generate(
      AiItineraryRequest(
        destinationId: destination?.id ?? place?.id ?? '',
        destinationName: destination?.name ?? place?.name ?? province!.name,
        // A place-based pick always carries its resolved province alongside
        // it (see `_placeDestination`'s doc comment), so this stays exactly
        // the destination/whole-province fallback it already was.
        provinceId: destination?.provinceId ?? province!.id,
        provinceName: destination?.provinceName ?? province!.name,
        budgetTierLabel: tier.label,
        budgetRange: tier.range,
        days: _days,
        travelers: _travelers,
        travelerType: _travelerType,
        transportation: _transportation,
        interests: _interests,
        tripPace: _tripPace,
        // Provinces have no single coordinate (see the Places API plan's
        // reasoning for not fabricating one), so a whole-province request
        // just skips the itinerary's weather section — same graceful
        // degradation as a destination with no coordinates on file.
        latitude: destination?.latitude ?? place?.latitude,
        longitude: destination?.longitude ?? place?.longitude,
        accommodationName: _accommodation?.name,
        accommodationLatitude: _accommodation?.latitude,
        accommodationLongitude: _accommodation?.longitude,
      ),
      coverImageUrl: destination?.heroImageUrl ??
          (place != null && place.photoNames.isNotEmpty
              ? PlacesService().photoUrl(place.photoNames.first)
              : province!.heroImageUrl),
    );

    if (!mounted) return;
    if (itinerary != null) {
      context.push(
        RoutePaths.generatedItinerary,
        extra: {'itinerary': itinerary},
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            planner.errorMessage ??
                'Couldn\'t generate your itinerary. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planner = context.watch<AiPlannerProvider>();
    final sidePadding = MaxWidthContainer.sidePadding(context, maxWidth: 800);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            sidePadding,
            AppSpacing.sm,
            sidePadding,
            AppSpacing.huge,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Planner', style: theme.textTheme.displayMedium),
                ),
                InkWell(
                  onTap: () => context.push(RoutePaths.aiChat),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(Symbols.chat_rounded, color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: AppColors.gradient([theme.colorScheme.primary, theme.colorScheme.primaryFixedDim]),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Trip Planner',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Answer a few questions and get a personalized day-by-day itinerary.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(
                    Symbols.auto_awesome_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 380.ms).moveY(begin: 12, end: 0),
            const SizedBox(height: AppSpacing.xxl),
            const _FieldLabel(
              icon: Symbols.location_on_rounded,
              label: 'Where do you want to go?',
            ),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: _pickDestination,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _destination != null
                            ? '${_destination!.name}, ${_destination!.provinceName}'
                            : _placeDestination != null
                            ? '${_placeDestination!.name}, ${_province?.name ?? _placeDestination!.address}'
                            : _province != null
                            ? '${_province!.name} (whole province)'
                            : 'Select a destination',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: _destination == null && _province == null
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      Symbols.expand_more_rounded,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ],
                ),
              ),
            ),
            if (_destination != null || _province != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              const _FieldLabel(
                icon: Symbols.hotel_rounded,
                label: 'Where are you staying? (optional)',
              ),
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: _pickAccommodation,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _accommodation?.name ?? 'Search for your hotel/accommodation',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: _accommodation == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (_accommodation != null)
                        IconButton(
                          icon: const Icon(Symbols.close_rounded),
                          onPressed: () => setState(() => _accommodation = null),
                        )
                      else
                        Icon(Symbols.expand_more_rounded, color: theme.textTheme.bodyMedium?.color),
                    ],
                  ),
                ),
              ),
              if (_accommodation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: AppSpacing.xs),
                  child: Text(
                    'Activities will be prioritized near this location.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            const _FieldLabel(
              icon: Symbols.account_balance_wallet_rounded,
              label: 'What\'s your budget?',
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: List.generate(_budgetTiers.length, (i) {
                final tier = _budgetTiers[i];
                final selected = _budgetTierIndex == i;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == _budgetTiers.length - 1 ? 0 : AppSpacing.sm,
                    ),
                    child: _SelectableCard(
                      icon: tier.icon,
                      title: tier.label,
                      subtitle: tier.range,
                      selected: selected,
                      onTap: () => setState(() => _budgetTierIndex = i),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const _FieldLabel(
              icon: Symbols.date_range_rounded,
              label: 'How many days?',
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: _editDays,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_days ${_days == 1 ? 'day' : 'days'}',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Symbols.edit_rounded,
                            size: 15,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _StepperButton(
                        icon: Symbols.remove_rounded,
                        onTap: _days > 1 ? () => setState(() => _days--) : null,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _StepperButton(
                        icon: Symbols.add_rounded,
                        onTap: _days < 14
                            ? () => setState(() => _days++)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const _FieldLabel(
              icon: Symbols.groups_2_rounded,
              label: 'How many travelers?',
            ),
            const SizedBox(height: AppSpacing.sm),
            Builder(
              builder: (context) {
                final (min, max) = _travelerRangeFor(_travelerType);
                final locked = min == max;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: locked ? null : _editTravelers,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$_travelers ${_travelers == 1 ? 'traveler' : 'travelers'}',
                                style: theme.textTheme.titleLarge,
                              ),
                              if (!locked) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Symbols.edit_rounded,
                                  size: 15,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _StepperButton(
                            icon: Symbols.remove_rounded,
                            onTap: _travelers > min
                                ? () => setState(() => _travelers--)
                                : null,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _StepperButton(
                            icon: Symbols.add_rounded,
                            onTap: _travelers < max
                                ? () => setState(() => _travelers++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _travelerRangeHint(_travelerType),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const _FieldLabel(
              icon: Symbols.diversity_3_rounded,
              label: 'Who\'s traveling?',
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _travelerTypeOptions.map((option) {
                final (label, icon) = option;
                final selected = _travelerType == label;
                return _SelectableChip(
                  label: label,
                  icon: icon,
                  selected: selected,
                  onTap: () => setState(() {
                    _travelerType = label;
                    final (min, max) = _travelerRangeFor(label);
                    _travelers = _travelers.clamp(min, max);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const _FieldLabel(
              icon: Symbols.commute_rounded,
              label: 'Preferred transportation',
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _transportOptions.map((option) {
                final (label, icon) = option;
                final selected = _transportation.contains(label);
                return _SelectableChip(
                  label: label,
                  icon: icon,
                  selected: selected,
                  onTap: () => setState(() {
                    if (!_transportation.remove(label))
                      _transportation.add(label);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const _FieldLabel(
              icon: Symbols.interests_rounded,
              label: 'What are you interested in?',
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _interestOptions.map((option) {
                final (label, icon) = option;
                final selected = _interests.contains(label);
                return _SelectableChip(
                  label: label,
                  icon: icon,
                  selected: selected,
                  onTap: () => setState(() {
                    if (!_interests.remove(label)) _interests.add(label);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const _FieldLabel(
              icon: Symbols.tune_rounded,
              label: 'Trip pace',
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _tripPaceOptions.map((option) {
                final (label, icon) = option;
                final selected = _tripPace == label;
                return _SelectableChip(
                  label: label,
                  icon: icon,
                  selected: selected,
                  onTap: () => setState(() => _tripPace = label),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      // Pinned so the call to action is always visible without scrolling —
      // a long form like this one otherwise buries "Generate Itinerary" at
      // the bottom where it's easy to miss entirely.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            sidePadding,
            AppSpacing.sm,
            sidePadding,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_destination == null && _province == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    'Select a destination to continue',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              AnimatedButton(
                label: planner.isGenerating
                    ? 'Crafting your itinerary...'
                    : 'Generate Itinerary',
                icon: planner.isGenerating
                    ? null
                    : Symbols.auto_awesome_rounded,
                isLoading: planner.isGenerating,
                onPressed:
                    (_destination == null && _province == null) ||
                        planner.isGenerating
                    ? null
                    : _generate,
                height: 60,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small "type the exact number" dialog for the days/travelers counters —
/// the +/- steppers are fine for nudging by one, but slow for jumping from
/// 1 to 12. Validates against [min]/[max] the same way every other form in
/// the app validates input, rather than silently clamping a bad value.
Future<int?> _promptForNumber(
  BuildContext context, {
  required String title,
  required int initial,
  required int min,
  required int max,
}) {
  final controller = TextEditingController(text: '$initial');
  final formKey = GlobalKey<FormState>();
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Between $min and $max',
            prefixIcon: const Icon(Symbols.numbers_rounded, size: 20),
          ),
          validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            if (n == null) return 'Enter a whole number';
            if (n < min || n > max)
              return 'Enter a number between $min and $max';
            return null;
          },
          onFieldSubmitted: (_) {
            if (formKey.currentState!.validate())
              Navigator.of(context).pop(int.parse(controller.text.trim()));
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate())
              Navigator.of(context).pop(int.parse(controller.text.trim()));
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primaryFixed : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? theme.colorScheme.primary : theme.textTheme.bodyMedium?.color,
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : theme.textTheme.bodyMedium?.color,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.outline,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

enum _PickerMode { destination, province }

class _DestinationPickerSheet extends StatefulWidget {
  const _DestinationPickerSheet({
    required this.currentDestination,
    required this.currentProvince,
  });

  final Destination? currentDestination;
  final Province? currentProvince;

  @override
  State<_DestinationPickerSheet> createState() =>
      _DestinationPickerSheetState();
}

class _DestinationPickerSheetState extends State<_DestinationPickerSheet> {
  final DestinationRepository _destinationRepository = DestinationRepository();
  final ProvinceRepository _provinceRepository = ProvinceRepository();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  late _PickerMode _mode = widget.currentProvince != null
      ? _PickerMode.province
      : _PickerMode.destination;

  List<Destination>? _destinations;
  Object? _destinationsError;

  List<Province>? _allProvinces;
  Object? _provincesError;
  String _provinceQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDestinations();
    _loadProvinces();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDestinations({String query = ''}) async {
    setState(() => _destinationsError = null);
    try {
      final results = query.trim().isEmpty
          ? await _destinationRepository.getPopular(limit: 50)
          : await _destinationRepository.searchByName(query.trim());
      if (mounted) setState(() => _destinations = results);
    } catch (e) {
      if (mounted) setState(() => _destinationsError = e);
    }
  }

  Future<void> _loadProvinces() async {
    setState(() => _provincesError = null);
    try {
      final results = (await _provinceRepository.getAll())
        ..sort((a, b) => a.name.compareTo(b.name));
      if (mounted) setState(() => _allProvinces = results);
    } catch (e) {
      if (mounted) setState(() => _provincesError = e);
    }
  }

  void _onSearchChanged(String value) {
    if (_mode == _PickerMode.province) {
      setState(() => _provinceQuery = value);
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadDestinations(query: value),
    );
  }

  void _switchMode(_PickerMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _searchController.clear();
      _provinceQuery = '';
    });
    if (mode == _PickerMode.destination) _loadDestinations();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provinces = _allProvinces
        ?.where(
          (p) => p.name.toLowerCase().contains(_provinceQuery.toLowerCase()),
        )
        .toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _mode == _PickerMode.destination
                            ? 'Choose a destination'
                            : 'Choose a province',
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        _SelectableChip(
                          label: 'Specific Spot',
                          icon: Symbols.place_rounded,
                          selected: _mode == _PickerMode.destination,
                          onTap: () => _switchMode(_PickerMode.destination),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _SelectableChip(
                          label: 'Whole Province',
                          icon: Symbols.public_rounded,
                          selected: _mode == _PickerMode.province,
                          onTap: () => _switchMode(_PickerMode.province),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SearchBarWidget(
                      controller: _searchController,
                      hintText: _mode == _PickerMode.destination
                          ? 'Search destinations...'
                          : 'Search provinces...',
                      onChanged: _onSearchChanged,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _mode == _PickerMode.destination
                    ? _destinationsError != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Text(
                                  AppException.from(
                                    _destinationsError!,
                                  ).message,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : _destinations == null
                          ? ListView(
                              children: List.generate(
                                6,
                                (_) =>
                                    LoadingWidget.textTile(leadingCircle: true),
                              ),
                            )
                          : _destinations!.isEmpty
                          ? const Center(child: Text('No destinations found'))
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                              ),
                              itemCount: _destinations!.length,
                              itemBuilder: (context, i) {
                                final destination = _destinations![i];
                                final selected =
                                    widget.currentDestination?.id ==
                                    destination.id;
                                return ListTile(
                                  onTap: () =>
                                      Navigator.of(context).pop(destination),
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                                    child: Icon(
                                      Symbols.place_rounded,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  title: Text(destination.name),
                                  subtitle: Text(destination.provinceName),
                                  trailing: selected
                                      ? Icon(
                                          Symbols.check_circle_rounded,
                                          color: theme.colorScheme.primary,
                                        )
                                      : null,
                                );
                              },
                            )
                    : _provincesError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                            AppException.from(_provincesError!).message,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : provinces == null
                    ? ListView(
                        children: List.generate(
                          6,
                          (_) => LoadingWidget.textTile(leadingCircle: true),
                        ),
                      )
                    : provinces.isEmpty
                    ? const Center(child: Text('No provinces found'))
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        itemCount: provinces.length,
                        itemBuilder: (context, i) {
                          final province = provinces[i];
                          final selected =
                              widget.currentProvince?.id == province.id;
                          return ListTile(
                            onTap: () => Navigator.of(context).pop(province),
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                              child: Icon(
                                Symbols.public_rounded,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            title: Text(province.name),
                            subtitle: Text(province.regionName),
                            trailing: selected
                                ? Icon(
                                    Symbols.check_circle_rounded,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Lets the traveler search for their real hotel/accommodation by name via
/// [PlacesService] (same live Google Places search `NearbyPlacesScreen`
/// uses) rather than a map pin-drop — an empty query browses nearby
/// lodging around the picked destination, and typing searches by name,
/// biased toward that same area when a single coordinate is available.
class _AccommodationPickerSheet extends StatefulWidget {
  const _AccommodationPickerSheet({this.destination, this.province});

  final Destination? destination;
  final Province? province;

  @override
  State<_AccommodationPickerSheet> createState() => _AccommodationPickerSheetState();
}

class _AccommodationPickerSheetState extends State<_AccommodationPickerSheet> {
  final PlacesService _places = PlacesService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<Place>? _results;
  Object? _error;

  bool get _hasCoordinates => widget.destination?.latitude != null && widget.destination?.longitude != null;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _error = null);
    try {
      List<Place> results;
      if (query.trim().isEmpty) {
        if (_hasCoordinates) {
          results = await _places.searchNearby(
            latitude: widget.destination!.latitude!,
            longitude: widget.destination!.longitude!,
            includedTypes: PlaceCategory.lodging,
          );
        } else {
          final areaName = widget.destination?.name ?? widget.province?.name ?? '';
          results = await _places.searchText(textQuery: 'hotels in $areaName, Philippines');
        }
      } else {
        results = await _places.searchText(
          textQuery: query,
          biasLatitude: _hasCoordinates ? widget.destination!.latitude : null,
          biasLongitude: _hasCoordinates ? widget.destination!.longitude : null,
        );
      }
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Search your accommodation', style: theme.textTheme.headlineSmall),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SearchBarWidget(
                      controller: _searchController,
                      hintText: 'Hotel or resort name...',
                      onChanged: _onSearchChanged,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(AppException.from(_error!).message, textAlign: TextAlign.center),
                        ),
                      )
                    : _results == null
                    ? ListView(children: List.generate(6, (_) => LoadingWidget.textTile(leadingCircle: true)))
                    : _results!.isEmpty
                    ? const Center(child: Text('No accommodations found'))
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        itemCount: _results!.length,
                        itemBuilder: (context, i) {
                          final place = _results![i];
                          return ListTile(
                            onTap: () => Navigator.of(context).pop(place),
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                              child: Icon(Symbols.hotel_rounded, color: theme.colorScheme.primary),
                            ),
                            title: Text(place.name),
                            subtitle: place.address.isNotEmpty ? Text(place.address) : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
