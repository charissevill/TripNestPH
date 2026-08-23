import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../ai/planner_options.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../domain/models/itinerary.dart';

/// The non-AI alternative to [AiPlannerScreen] — a traveler who'd rather
/// build their own day-by-day plan starts here with just a destination name
/// and day count, then lands on the same [GeneratedItineraryScreen] an
/// AI-generated trip does, with empty days ready for "Add Activity". That
/// screen already owns every bit of day/activity/budget editing and the
/// actual save-to-Firestore write, so this screen's only job is producing a
/// valid, empty [Itinerary] to hand off to it — see [_startPlanning].
class ManualItineraryScreen extends StatefulWidget {
  const ManualItineraryScreen({super.key});

  @override
  State<ManualItineraryScreen> createState() => _ManualItineraryScreenState();
}

class _ManualItineraryScreenState extends State<ManualItineraryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController();
  int _days = 3;
  int _travelers = 1;

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  void _startPlanning() {
    if (!_formKey.currentState!.validate()) return;
    final days = List.generate(
      _days,
      (i) => ItineraryDay(
        dayNumber: i + 1,
        dateLabel: 'Day ${i + 1}',
        activities: const [],
      ),
    );
    final itinerary = Itinerary(
      destinationName: _destinationController.text.trim(),
      coverImageUrl: '',
      totalDays: _days,
      travelers: _travelers,
      totalBudget: 0,
      days: days,
      budgetBreakdown: const [],
      weather: const [],
      travelTips: const [],
      recommendedRestaurantIds: const [],
      nearbyAttractionIds: const [],
    );
    // No 'savedId' — same as a freshly AI-generated itinerary, this only
    // exists in memory until the traveler taps Save on that screen.
    context.push(RoutePaths.generatedItinerary, extra: {'itinerary': itinerary});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Create Your Own Itinerary'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Skip the AI and lay out your trip yourself — add each '
                'day\'s activities one at a time, in your own words.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextFormField(
                controller: _destinationController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Destination',
                  hintText: 'e.g. Boracay, Aklan',
                  prefixIcon: Icon(Symbols.location_on_rounded, size: 20),
                ),
                validator: (v) => Validators.required(v, label: 'Destination'),
              ),
              const SizedBox(height: AppSpacing.xl),
              _StepperRow(
                label: 'Number of Days',
                value: _days,
                min: minTripDays,
                max: maxTripDays,
                onChanged: (v) => setState(() => _days = v),
              ),
              const SizedBox(height: AppSpacing.lg),
              _StepperRow(
                label: 'Number of Travelers',
                value: _travelers,
                min: 1,
                max: 15,
                onChanged: (v) => setState(() => _travelers = v),
              ),
              const SizedBox(height: AppSpacing.xxl),
              AnimatedButton(
                label: 'Start Planning',
                icon: Symbols.edit_calendar_rounded,
                onPressed: _startPlanning,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labeled -/+ counter, shared by the day and traveler counts — same
/// min/max-clamped stepper shape as the AI Planner's own day/traveler
/// pickers, just inline instead of behind a "tap to edit" dialog since this
/// form only has two numbers to set.
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
        IconButton(
          icon: const Icon(Symbols.remove_circle_outline_rounded),
          color: value > min ? AppColors.primary : AppColors.textTertiary,
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Symbols.add_circle_outline_rounded),
          color: value < max ? AppColors.primary : AppColors.textTertiary,
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
