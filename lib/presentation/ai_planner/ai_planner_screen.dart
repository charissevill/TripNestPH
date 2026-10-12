import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../ai/models/itinerary_request.dart';
import '../../ai/planner_options.dart';
import '../../ai/providers/ai_planner_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/services/places_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/buttons/selectable_chip.dart';
import '../../core/widgets/dialogs/number_prompt_dialog.dart';
import '../../core/widgets/inputs/search_bar_widget.dart';
import '../../core/widgets/layout/max_width_container.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/place.dart';
import '../../domain/models/province.dart';
import 'widgets/destination_picker_sheet.dart';
import 'widgets/planner_hero.dart';

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
  final Set<String> _transportation = {defaultTransportation};
  final Set<String> _interests = {...defaultInterests};
  String _tripPace = 'Balanced';

  /// Whether the transportation/interests/pace section is unfolded.
  bool _showMorePreferences = false;

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
    final value = await promptForNumber(
      context,
      title: 'How many days?',
      initial: _days,
      min: minTripDays,
      max: maxTripDays,
    );
    if (value != null) setState(() => _days = value);
  }

  Future<void> _editTravelers() async {
    final (min, max) = _travelerRangeFor(_travelerType);
    final value = await promptForNumber(
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
      builder: (context) => DestinationPickerSheet(
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
    final tier = budgetTiers[_budgetTierIndex];

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
      // The hero header paints its artwork up behind the status bar, so the
      // top inset is handled inside [PlannerHero] instead of by SafeArea.
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            sidePadding,
            0,
            sidePadding,
            AppSpacing.huge,
          ),
          children: [
            PlannerHero(
              bleed: sidePadding,
              badgeIcon: Symbols.auto_awesome_rounded,
              badgeLabel: 'AI Trip Planner',
              headline: 'Plan your next\nadventure',
              subtitle: 'Answer a few questions and get a personalized day-by-day itinerary.',
              actionIcon: Symbols.chat_rounded,
              onAction: () => context.push(RoutePaths.aiChat),
            ),
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
              children: List.generate(budgetTiers.length, (i) {
                final tier = budgetTiers[i];
                final selected = _budgetTierIndex == i;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == budgetTiers.length - 1 ? 0 : AppSpacing.sm,
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
            // Days and travelers share one row to keep the form short; they
            // stack again when the screen is too narrow for two counters.
            LayoutBuilder(
              builder: (context, constraints) {
                final (min, max) = _travelerRangeFor(_travelerType);
                final days = _CounterCard(
                  icon: Symbols.date_range_rounded,
                  label: _days == 1 ? 'Day' : 'Days',
                  value: _days,
                  onEdit: _editDays,
                  onDecrement: _days > minTripDays ? () => setState(() => _days--) : null,
                  onIncrement: _days < maxTripDays ? () => setState(() => _days++) : null,
                );
                final travelers = _CounterCard(
                  icon: Symbols.groups_2_rounded,
                  label: _travelers == 1 ? 'Traveler' : 'Travelers',
                  value: _travelers,
                  onEdit: min == max ? null : _editTravelers,
                  onDecrement: _travelers > min ? () => setState(() => _travelers--) : null,
                  onIncrement: _travelers < max ? () => setState(() => _travelers++) : null,
                );
                if (constraints.maxWidth < 300) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      days,
                      const SizedBox(height: AppSpacing.sm),
                      travelers,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: days),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: travelers),
                  ],
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
              children: travelerTypeOptions.map((option) {
                final (label, icon) = option;
                final selected = _travelerType == label;
                return SelectableChip(
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
            // Transportation, interests and pace all have sensible defaults,
            // so they stay folded behind one row (summarizing the current
            // picks) until the traveler wants to fine-tune them.
            InkWell(
              onTap: () => setState(() => _showMorePreferences = !_showMorePreferences),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Row(
                  children: [
                    Icon(Symbols.tune_rounded, size: 24, color: theme.colorScheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('More preferences', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            [
                              _transportation.isEmpty ? 'Any transport' : _transportation.join(', '),
                              '${_interests.length} ${_interests.length == 1 ? 'interest' : 'interests'}',
                              '$_tripPace pace',
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    AnimatedRotation(
                      turns: _showMorePreferences ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Symbols.expand_more_rounded,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: !_showMorePreferences
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.xl),
                        const _FieldLabel(
                          icon: Symbols.commute_rounded,
                          label: 'Preferred transportation',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: transportOptions.map((option) {
                            final (label, icon) = option;
                            final selected = _transportation.contains(label);
                            return SelectableChip(
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
                        const SizedBox(height: AppSpacing.xl),
                        const _FieldLabel(
                          icon: Symbols.interests_rounded,
                          label: 'What are you interested in?',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: interestOptions.map((option) {
                            final (label, icon) = option;
                            final selected = _interests.contains(label);
                            return SelectableChip(
                              label: label,
                              icon: icon,
                              selected: selected,
                              onTap: () => setState(() {
                                if (!_interests.remove(label)) _interests.add(label);
                              }),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const _FieldLabel(
                          icon: Symbols.speed_rounded,
                          label: 'Trip pace',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: tripPaceOptions.map((option) {
                            final (label, icon) = option;
                            final selected = _tripPace == label;
                            return SelectableChip(
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
                trailingIcon: planner.isGenerating
                    ? null
                    : Symbols.arrow_forward_rounded,
                borderRadius: AppRadius.pill,
                height: 60,
              ),
              if (!planner.isGenerating)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Divider(
                        endIndent: AppSpacing.xs,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    // Flexible so the label wraps instead of overflowing on
                    // very narrow screens or at large text scales.
                    Flexible(
                      flex: 8,
                      child: TextButton(
                        onPressed: () => context.push(RoutePaths.manualItinerary),
                        child: const Text(
                          'Or create your own itinerary',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        indent: AppSpacing.xs,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
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
        Icon(icon, size: 24, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
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
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: selected ? 0.18 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  title,
                  textAlign: TextAlign.center,
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
            if (selected)
              Positioned(
                top: -AppSpacing.xs,
                right: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Symbols.check_rounded, color: Colors.white, size: 14, weight: 700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A compact labelled counter (days, travelers): −/+ steppers around the
/// number, which opens the "type the exact number" dialog when tapped —
/// [onEdit] is null while the value is locked (e.g. Solo/Couple travelers).
class _CounterCard extends StatelessWidget {
  const _CounterCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
    required this.onDecrement,
    required this.onIncrement,
  });

  final IconData icon;
  final String label;
  final int value;
  final VoidCallback? onEdit;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              _StepperButton(icon: Symbols.remove_rounded, onTap: onDecrement),
              Expanded(
                child: InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('$value', style: theme.textTheme.headlineSmall),
                    ),
                  ),
                ),
              ),
              _StepperButton(icon: Symbols.add_rounded, onTap: onIncrement),
            ],
          ),
        ],
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.outline,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        ),
      ),
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
