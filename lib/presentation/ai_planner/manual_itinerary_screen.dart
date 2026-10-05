import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../ai/planner_options.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/routes/back_navigation.dart';
import '../../core/routes/route_paths.dart';
import '../../core/services/weather_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/dialogs/discard_changes_scope.dart';
import '../../data/repositories/itinerary_repository.dart';
import '../../domain/models/itinerary.dart';
import 'widgets/map_destination_picker.dart';

/// The non-AI alternative to [AiPlannerScreen] — a traveler who'd rather
/// build their own day-by-day plan starts here by dropping a pin for their
/// destination and picking a start date (required — it's what real per-day
/// dates and the weather outlook are both anchored to) and a day count,
/// then lands on the same [GeneratedItineraryScreen]
/// an AI-generated trip does, with empty days ready for "Add Activity".
/// That screen already owns every bit of day/activity/budget editing and
/// the actual save-to-Firestore write, so this screen's only job is
/// producing a valid, empty [Itinerary] to hand off to it — see
/// [_startPlanning].
class ManualItineraryScreen extends StatefulWidget {
  const ManualItineraryScreen({super.key});

  @override
  State<ManualItineraryScreen> createState() => _ManualItineraryScreenState();
}

class _ManualItineraryScreenState extends State<ManualItineraryScreen> {
  MapPickedLocation? _location;
  DateTime? _startDate;
  int _days = 3;
  int _travelers = 1;
  bool _submitting = false;

  Future<void> _pickOnMap() async {
    final picked = await Navigator.of(context).push<MapPickedLocation>(
      MaterialPageRoute(builder: (context) => const MapDestinationPicker()),
    );
    if (picked != null) setState(() => _location = picked);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'When are you traveling?',
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  /// Best-effort, real forecast — Open-Meteo's free tier only looks ~16
  /// days ahead of *today* (not from [_startDate]), so this fetches enough
  /// days to cover from today through the trip's last day, then slices out
  /// just the trip's own date range. A start date outside that window just
  /// leaves the itinerary with no forecast, same "check back closer to your
  /// trip" fallback every AI-generated itinerary already shows.
  Future<List<WeatherForecast>> _fetchWeatherForTrip() async {
    final startDate = _startDate;
    final location = _location;
    if (startDate == null || location == null) return const [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tripStart = DateTime(startDate.year, startDate.month, startDate.day);
    final daysUntilStart = tripStart.difference(today).inDays;
    if (daysUntilStart < 0) return const [];

    final totalDaysNeeded = daysUntilStart + _days;
    if (totalDaysNeeded > 16) return const [];

    final forecast = await WeatherService().getForecast(
      latitude: location.latitude,
      longitude: location.longitude,
      days: totalDaysNeeded,
    );
    if (forecast.length < totalDaysNeeded) return const [];
    return forecast.sublist(daysUntilStart, daysUntilStart + _days);
  }

  Future<void> _startPlanning() async {
    final location = _location;
    final startDate = _startDate;
    if (location == null || startDate == null) return;

    final auth = context.read<AuthProvider>();
    final uid = auth.firebaseUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to create an itinerary.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final weather = await _fetchWeatherForTrip();
    if (!mounted) return;

    final days = List.generate(_days, (i) {
      final dateLabel = DateFormat('EEE, MMM d').format(startDate.add(Duration(days: i)));
      return ItineraryDay(dayNumber: i + 1, dateLabel: dateLabel, activities: const []);
    });

    final itinerary = Itinerary(
      destinationName: location.name,
      coverImageUrl: '',
      totalDays: _days,
      travelers: _travelers,
      totalBudget: 0,
      days: days,
      budgetBreakdown: const [],
      weather: weather,
      travelTips: const [],
      recommendedRestaurantIds: const [],
      nearbyAttractionIds: const [],
      destinationLatitude: location.latitude,
      destinationLongitude: location.longitude,
      isManuallyCreated: true,
    );

    try {
      // Saved immediately (unlike the AI flow, which leaves a fresh trip
      // unsaved until the traveler taps Save) — a manual itinerary starts
      // with every day empty, and "Add Activity"/"Add Category" only show
      // up once the trip has a saved id, so without this the traveler would
      // land on a screen with nothing at all clickable.
      final savedId = await ItineraryRepository().save(
        userId: uid,
        title: location.name,
        itinerary: itinerary,
        startDate: startDate,
        ownerName: auth.currentUser?.name ?? '',
      );
      if (!mounted) return;
      // Replaces this form rather than stacking on it: the trip is already
      // saved, so Back from it should land on the Planner — returning to a
      // still-filled form here just invited a second "Start Planning" tap
      // that saved a duplicate trip.
      context.pushReplacement(RoutePaths.generatedItinerary, extra: {'itinerary': itinerary, 'savedId': savedId});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = _location;
    // A dropped pin and a picked date are real effort to redo, so leaving
    // with either set asks first — same guard as the app's other forms.
    return DiscardChangesScope(
      isDirty: (location != null || _startDate != null) && !_submitting,
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.popOrGo(RoutePaths.planner),
        ),
        title: const Text('Create Your Own Itinerary'),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
          children: [
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
                          'Build It Yourself',
                          style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Skip the AI — add each day\'s activities '
                          'one at a time, in your own words.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Symbols.edit_calendar_rounded, color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _SectionLabel('TRIP DETAILS'),
            const SizedBox(height: AppSpacing.sm),
            _SectionCard(
              children: [
                _FieldRow(
                  icon: Symbols.map_rounded,
                  label: 'Destination',
                  value: location?.name,
                  placeholder: 'Tap to pin your destination on the map',
                  onTap: _pickOnMap,
                ),
                const _RowDivider(),
                _FieldRow(
                  icon: Symbols.calendar_today_rounded,
                  label: 'Start Date',
                  value: _startDate != null ? DateFormat('EEE, MMM d, yyyy').format(_startDate!) : null,
                  placeholder: 'Tap to choose when you\'re traveling',
                  onTap: _pickStartDate,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const _SectionLabel('GROUP & LENGTH'),
            const SizedBox(height: AppSpacing.sm),
            _SectionCard(
              children: [
                _StepperRow(
                  icon: Symbols.calendar_month_rounded,
                  label: 'Days',
                  value: _days,
                  min: minTripDays,
                  max: maxTripDays,
                  onChanged: (v) => setState(() => _days = v),
                ),
                const _RowDivider(),
                _StepperRow(
                  icon: Symbols.group_rounded,
                  label: 'Travelers',
                  value: _travelers,
                  min: 1,
                  max: 15,
                  onChanged: (v) => setState(() => _travelers = v),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: Text(
                '$_days ${_days == 1 ? 'day' : 'days'} · $_travelers ${_travelers == 1 ? 'traveler' : 'travelers'}'
                '${_startDate != null ? ' · ${DateFormat('MMM d').format(_startDate!)}' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
        child: Container(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (location == null || _startDate == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    location == null ? 'Pin a destination to continue' : 'Pick a start date to continue',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              AnimatedButton(
                label: 'Start Planning',
                icon: Symbols.edit_calendar_rounded,
                isLoading: _submitting,
                onPressed: (location == null || _startDate == null || _submitting) ? null : _startPlanning,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// A small uppercase caption above a [_SectionCard], naming the group of
/// fields below it ("TRIP DETAILS", "GROUP & LENGTH") the way a settings
/// screen labels its sections rather than leaving two cards unexplained.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The bordered white card wrapping a group of related [_FieldRow]/
/// [_StepperRow]s (e.g. Destination+Start Date, Days+Travelers) — separated
/// by [_RowDivider] rather than getting each its own floating box.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

/// A divider inset to clear the leading icon badge every row in this form
/// shares, so it visually separates the two rows' *labels* rather than
/// running edge-to-edge underneath the icons too.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 56),
      child: Divider(height: 1),
    );
  }
}

/// A tappable "icon badge + label + value/placeholder + chevron" row —
/// shared shape for the Destination and Start Date pickers.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            _IconBadge(icon: icon),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    hasValue ? value! : placeholder,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: hasValue ? AppColors.textPrimary : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Symbols.chevron_right_rounded, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// The 40x40 tinted-square icon badge every row in this form leads with —
/// same shape [role_choice_dialog.dart]'s option cards use, so a picked-vs-
/// unpicked field and a counter row still read as one consistent family.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, color: AppColors.primary, size: 22),
    );
  }
}

/// A labeled -/+ counter, shared by the day and traveler counts — same
/// min/max-clamped stepper shape as the AI Planner's own day/traveler
/// pickers, just inline instead of behind a "tap to edit" dialog since this
/// form only has two numbers to set.
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          _IconBadge(icon: icon),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          IconButton(
            icon: const Icon(Symbols.remove_circle_outline_rounded),
            color: value > min ? AppColors.primary : AppColors.textTertiary,
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 28,
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
      ),
    );
  }
}
