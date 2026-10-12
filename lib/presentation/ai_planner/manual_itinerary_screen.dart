import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../ai/planner_options.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../core/routes/back_navigation.dart';
import '../../core/routes/route_paths.dart';
import '../../core/services/places_service.dart';
import '../../core/services/weather_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/geo_distance.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/buttons/selectable_chip.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/dialogs/discard_changes_scope.dart';
import '../../core/widgets/layout/max_width_container.dart';
import '../../core/widgets/dialogs/number_prompt_dialog.dart';
import '../../data/repositories/itinerary_repository.dart';
import '../../domain/models/itinerary.dart';
import 'generated_itinerary_screen.dart' show maxActivitiesPerDay, showActivityDialog, sortActivitiesByTimeSlot;
import 'widgets/map_destination_picker.dart';
import 'widgets/planner_hero.dart';

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

  /// Activities added right here on the form, keyed by 1-based day number —
  /// optional, since anything skipped can still be added from the trip
  /// screen afterwards. Only days that have at least one appear.
  final Map<int, List<ItineraryActivity>> _activities = {};

  /// Which day the activities section is currently showing.
  int _selectedDay = 1;

  /// Shortening the trip drops whole days — asks first when any of them
  /// already has activities, rather than silently throwing those away.
  Future<void> _setDays(int value) async {
    final dropsActivities = _activities.entries.any((e) => e.key > value && e.value.isNotEmpty);
    if (dropsActivities) {
      final confirmed = await showConfirmationDialog(
        context,
        title: 'Remove extra days?',
        message: 'Days after Day $value already have activities — shortening the trip removes them.',
        confirmLabel: 'Remove',
        isDestructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _days = value;
      _activities.removeWhere((day, _) => day > value);
      if (_selectedDay > value) _selectedDay = value;
    });
  }

  Future<void> _addActivity() async {
    final location = _location;
    if (location == null) return;
    final dayActivities = _activities[_selectedDay] ?? const <ItineraryActivity>[];
    if (dayActivities.length >= maxActivitiesPerDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A day can hold up to $maxActivitiesPerDay activities — remove one to add another.')),
      );
      return;
    }
    final result = await showActivityDialog(
      context,
      anchorLatitude: location.latitude,
      anchorLongitude: location.longitude,
      anchorLabel: location.name,
      dayActivities: dayActivities,
    );
    if (result == null || !mounted) return;
    setState(() => (_activities[_selectedDay] ??= []).add(result));
  }

  Future<void> _editActivity(ItineraryActivity activity) async {
    final location = _location;
    final result = await showActivityDialog(
      context,
      anchorLatitude: location?.latitude,
      anchorLongitude: location?.longitude,
      anchorLabel: location?.name,
      existing: activity,
      dayActivities: _activities[_selectedDay] ?? const [],
    );
    if (result == null || !mounted) return;
    final list = _activities[_selectedDay];
    final index = list?.indexOf(activity) ?? -1;
    if (index < 0) return;
    setState(() => list![index] = result);
  }

  void _removeActivity(ItineraryActivity activity) {
    setState(() {
      _activities[_selectedDay]?.remove(activity);
      if (_activities[_selectedDay]?.isEmpty ?? false) _activities.remove(_selectedDay);
    });
  }
  int _travelers = 1;
  bool _submitting = false;

  /// Optional — what the trip is listed as in Saved Trips. Left blank, the
  /// pinned destination's name is used instead.
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Keeps the leave-without-saving guard in sync with a typed name.
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.of(context).push<MapPickedLocation>(
      MaterialPageRoute(builder: (context) => const MapDestinationPicker()),
    );
    if (picked == null || !mounted) return;

    // Every activity pin was only ever checked against the destination it
    // was added under — moving the destination can strand some of them far
    // outside the trip, so those are dropped (after asking) rather than
    // left behind as pins hundreds of kilometers from the new place.
    bool isStranded(ItineraryActivity a) =>
        a.latitude != null &&
        a.longitude != null &&
        haversineKm(picked.latitude, picked.longitude, a.latitude!, a.longitude!) > _activityRadiusKm;
    final stranded = _activities.values.expand((list) => list).where(isStranded).length;
    if (stranded > 0) {
      final confirmed = await showConfirmationDialog(
        context,
        title: 'Change destination?',
        message:
            '$stranded ${stranded == 1 ? 'activity is' : 'activities are'} pinned more than '
            '${_activityRadiusKm.round()} km from ${picked.name} and will be removed.',
        confirmLabel: 'Change',
        isDestructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _location = picked;
      for (final list in _activities.values) {
        list.removeWhere(isStranded);
      }
      _activities.removeWhere((_, list) => list.isEmpty);
    });
  }

  /// Same limit [MapDestinationPicker] enforces when an activity is pinned.
  static const double _activityRadiusKm = 100;

  /// Null when the optional trip name is fine (including left blank).
  String? get _nameError {
    final name = _nameController.text.trim();
    if (name.isEmpty) return null;
    if (!RegExp(r'[A-Za-z0-9]').hasMatch(name)) return 'Use letters or numbers';
    return null;
  }

  /// A pin Google couldn't name would otherwise title the whole trip
  /// "Pinned location" — so that one case makes the trip name required.
  bool get _needsTripName =>
      _location?.name == MapPickedLocation.fallbackName && _nameController.text.trim().isEmpty;

  /// What's still stopping "Start Planning", or null when it can go ahead.
  String? get _blockingHint {
    if (_location == null) return 'Pin a destination to continue';
    if (_startDate == null) return 'Pick a start date to continue';
    if (_needsTripName) return 'Name your trip to continue';
    if (_nameError != null) return 'Fix the trip name to continue';
    return null;
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
    if (daysUntilStart < 0 || daysUntilStart >= _forecastHorizonDays) return const [];

    // Just the leading trip days the forecast reaches — a trip that runs
    // past the window still gets those, not nothing.
    final coveredDays = _days.clamp(0, _forecastHorizonDays - daysUntilStart);
    final totalDaysNeeded = daysUntilStart + coveredDays;

    final forecast = await WeatherService().getForecast(
      latitude: location.latitude,
      longitude: location.longitude,
      days: totalDaysNeeded,
    );
    if (forecast.length < totalDaysNeeded) return const [];
    return forecast.sublist(daysUntilStart, totalDaysNeeded);
  }

  /// How far ahead of today a weather forecast exists at all (Open-Meteo's
  /// free tier) — same window the trip screen's Weather Outlook works to.
  static const int _forecastHorizonDays = 16;

  /// Tells the traveler, for the dates as currently picked, which of their
  /// trip days can have a forecast — before they find out on the trip
  /// screen that a trip next month has none yet.
  String get _weatherCoverageNote {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final format = DateFormat('MMM d');
    final startDate = _startDate;
    if (startDate == null) {
      return 'A later trip gets its forecast as the date gets closer.';
    }
    final tripStart = DateTime(startDate.year, startDate.month, startDate.day);
    final daysUntilStart = tripStart.difference(today).inDays;
    if (daysUntilStart >= _forecastHorizonDays) {
      final availableFrom = tripStart.subtract(const Duration(days: _forecastHorizonDays - 1));
      return 'No forecast yet for ${format.format(tripStart)}. Yours will start showing on ${format.format(availableFrom)}.';
    }
    final coveredDays = _days.clamp(0, _forecastHorizonDays - (daysUntilStart < 0 ? 0 : daysUntilStart));
    if (coveredDays >= _days) {
      return _days == 1 ? 'A weather forecast is available for your trip day.' : 'A weather forecast is available for all $_days days.';
    }
    return 'A weather forecast is available for ${coveredDays == 1 ? 'Day 1' : 'Days 1–$coveredDays'} only — '
        'the rest will show up as the trip gets closer.';
  }

  /// Best-effort cover photo for the pinned spot — a manual pin isn't tied
  /// to any curated destination record with a hero image of its own, so
  /// this asks Places for the nearest match by name and uses its first
  /// photo. Any failure (or no photo) just leaves the trip on the same
  /// placeholder cover it always had.
  Future<String> _fetchCoverImageUrl(MapPickedLocation location) async {
    try {
      final places = PlacesService();
      final results = await places
          .searchText(
            textQuery: '${location.name}, Philippines',
            maxResultCount: 5,
            biasLatitude: location.latitude,
            biasLongitude: location.longitude,
          )
          .timeout(const Duration(seconds: 8));
      for (final place in results) {
        if (place.photoNames.isNotEmpty) return places.photoUrl(place.photoNames.first);
      }
    } catch (_) {
      // Fall through to no cover.
    }
    return '';
  }

  Future<void> _startPlanning() async {
    final location = _location;
    final startDate = _startDate;
    if (location == null || startDate == null || _blockingHint != null) return;

    // The date picker only blocks past dates at the moment it's open — a
    // form left sitting past midnight can still hold yesterday's date.
    final now = DateTime.now();
    if (DateTime(startDate.year, startDate.month, startDate.day).isBefore(DateTime(now.year, now.month, now.day))) {
      setState(() => _startDate = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That start date has already passed — pick a new one.')),
      );
      return;
    }

    // Creating the trip is a server write: offline it would just sit on a
    // spinner with no way to tell when (or whether) it went through.
    var isOnline = true;
    try {
      isOnline = context.read<ConnectivityProvider>().isOnline;
    } catch (_) {
      // No connectivity provider above this screen — assume online.
    }
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You\'re offline — connect to the internet to create your trip.')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final uid = auth.firebaseUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to create an itinerary.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final (weather, coverImageUrl) = await (_fetchWeatherForTrip(), _fetchCoverImageUrl(location)).wait;
    if (!mounted) return;
    final tripName = _nameController.text.trim();

    final days = List.generate(_days, (i) {
      final dateLabel = DateFormat('EEE, MMM d').format(startDate.add(Duration(days: i)));
      return ItineraryDay(dayNumber: i + 1, dateLabel: dateLabel, activities: List.of(_activities[i + 1] ?? const []));
    });

    final itinerary = Itinerary(
      destinationName: location.name,
      coverImageUrl: coverImageUrl,
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
      final savedId = await ItineraryRepository()
          .save(
            userId: uid,
            title: tripName.isNotEmpty ? tripName : location.name,
            itinerary: itinerary,
            startDate: startDate,
            ownerName: auth.currentUser?.name ?? '',
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      // Replaces this form rather than stacking on it: the trip is already
      // saved, so Back from it should land on the Planner — returning to a
      // still-filled form here just invited a second "Start Planning" tap
      // that saved a duplicate trip.
      context.pushReplacement(RoutePaths.generatedItinerary, extra: {'itinerary': itinerary, 'savedId': savedId, 'isNewManualTrip': true});
    } on TimeoutException {
      // The write is already queued and can't be recalled — it lands on
      // its own once the connection recovers. Leaving the form (rather
      // than re-enabling the button) is what stops a second tap from
      // saving the same trip twice.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Slow connection — your trip is still saving and will show up in Saved Trips shortly.'),
        ),
      );
      // A plain pop/go — not `popOrGo`, whose `maybePop` would run into
      // this screen's own leave guards.
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        context.go(RoutePaths.planner);
      }
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
    final sidePadding = MaxWidthContainer.sidePadding(context, maxWidth: 800);
    // A dropped pin and a picked date are real effort to redo, so leaving
    // with either set asks first — same guard as the app's other forms.
    //
    // The outer PopScope covers the one moment that guard steps aside:
    // while the trip is being saved, Back is ignored outright, since
    // leaving mid-save would create the trip with nobody there to open it.
    return PopScope(
      canPop: !_submitting,
      child: DiscardChangesScope(
      isDirty: (location != null || _startDate != null || _nameController.text.trim().isNotEmpty || _activities.isNotEmpty) && !_submitting,
      child: Scaffold(
      // No AppBar — the same picture header as the AI Planner carries the
      // Back button and title, and handles the top inset itself.
      // Frozen while saving, so nothing can be changed out from under the
      // trip that's already on its way to being created.
      body: AbsorbPointer(
        absorbing: _submitting,
        child: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, AppSpacing.xxl),
          children: [
            PlannerHero(
              bleed: sidePadding,
              badgeIcon: Symbols.edit_calendar_rounded,
              badgeLabel: 'Build It Yourself',
              headline: 'Create your own\nitinerary',
              subtitle: 'Skip the AI — add each day\'s activities one at a time, in your own words.',
              onBack: () => context.popOrGo(RoutePaths.planner),
            ),
            // Says up front — first thing on the form, before any field —
            // how much of the trip can have a forecast at all, so a far-off
            // date isn't a surprise on the trip screen.
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Symbols.partly_cloudy_day_rounded, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Always the same standing rule (with its real end
                        // date), then what it means for the dates picked.
                        Text(
                          'Weather forecasts are available only for the next $_forecastHorizonDays days '
                          '(until ${DateFormat('MMM d').format(DateTime.now().add(const Duration(days: _forecastHorizonDays - 1)))}).',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _weatherCoverageNote,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
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
                const _RowDivider(),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const _IconBadge(icon: Symbols.label_rounded),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          maxLength: 60,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: _needsTripName ? 'Trip Name' : 'Trip Name (optional)',
                            hintText: location == null || location.name == MapPickedLocation.fallbackName
                                ? 'e.g. Barkada Beach Getaway'
                                : location.name,
                            counterText: '',
                            errorText: _nameError,
                            helperText: _needsTripName ? 'This pin has no place name, so give your trip one.' : null,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                  editTitle: 'How many days?',
                  value: _days,
                  min: minTripDays,
                  max: maxTripDays,
                  onChanged: _setDays,
                ),
                const _RowDivider(),
                _StepperRow(
                  icon: Symbols.group_rounded,
                  label: 'Travelers',
                  editTitle: 'How many travelers?',
                  value: _travelers,
                  min: 1,
                  max: 15,
                  onChanged: (v) => setState(() => _travelers = v),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const _SectionLabel('ACTIVITIES (OPTIONAL)'),
            const SizedBox(height: AppSpacing.sm),
            // One day at a time, picked from a chip row — a 14-day trip
            // would otherwise stack 14 cards onto this form.
            if (_days > 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var day = 1; day <= _days; day++)
                      Padding(
                        padding: EdgeInsets.only(right: day == _days ? 0 : AppSpacing.xs),
                        child: SelectableChip(
                          label: (_activities[day]?.isNotEmpty ?? false) ? 'Day $day (${_activities[day]!.length})' : 'Day $day',
                          icon: Symbols.today_rounded,
                          selected: _selectedDay == day,
                          onTap: () => setState(() => _selectedDay = day),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Builder(
              builder: (context) {
                final dayActivities = sortActivitiesByTimeSlot(_activities[_selectedDay] ?? const []);
                final dayDate = _startDate?.add(Duration(days: _selectedDay - 1));
                return _SectionCard(
                  children: [
                    if (dayActivities.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
                        child: Text(
                          location == null
                              ? 'Pin a destination first, then add what you\'ll do each day.'
                              : 'Nothing planned for Day $_selectedDay'
                                    '${dayDate != null ? ' (${DateFormat('EEE, MMM d').format(dayDate)})' : ''} yet. '
                                    'Add activities now, or later from the trip screen.',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    for (final activity in dayActivities) ...[
                      InkWell(
                        onTap: () => _editActivity(activity),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
                          child: Row(
                            children: [
                              _IconBadge(icon: activity.icon),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activity.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [activity.time, if (activity.location.isNotEmpty) activity.location].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove',
                                icon: const Icon(Symbols.close_rounded),
                                color: theme.colorScheme.onSurfaceVariant,
                                onPressed: () => _removeActivity(activity),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const _RowDivider(),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 4),
                        child: TextButton.icon(
                          onPressed: location == null ? null : _addActivity,
                          icon: const Icon(Symbols.add_rounded, size: 18),
                          label: Text(_days > 1 ? 'Add Activity to Day $_selectedDay' : 'Add Activity'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: Text(
                '$_days ${_days == 1 ? 'day' : 'days'} · $_travelers ${_travelers == 1 ? 'traveler' : 'travelers'}'
                '${_startDate != null ? ' · ${DateFormat('MMM d').format(_startDate!)}' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(sidePadding, AppSpacing.sm, sidePadding, AppSpacing.md),
        child: Container(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.colorScheme.outline)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_blockingHint != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    _blockingHint!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              AnimatedButton(
                label: 'Start Planning',
                icon: Symbols.edit_calendar_rounded,
                trailingIcon: _submitting ? null : Symbols.arrow_forward_rounded,
                borderRadius: AppRadius.pill,
                height: 60,
                isLoading: _submitting,
                onPressed: (_blockingHint != null || _submitting) ? null : _startPlanning,
              ),
            ],
          ),
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
          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outline),
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
                  Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    hasValue ? value! : placeholder,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: hasValue ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Symbols.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
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
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, color: primary, size: 22),
    );
  }
}

/// A labeled -/+ counter, shared by the day and traveler counts — same
/// min/max-clamped stepper shape as the AI Planner's own day/traveler
/// pickers, laid out as a row since this form only has two numbers to set.
/// Tapping the number opens the same "type the exact number" dialog.
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.icon,
    required this.label,
    required this.editTitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String editTitle;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  Future<void> _edit(BuildContext context) async {
    final typed = await promptForNumber(
      context,
      title: editTitle,
      initial: value,
      min: min,
      max: max,
    );
    if (typed != null) onChanged(typed);
  }

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
            color: value > min ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          InkWell(
            onTap: () => _edit(context),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              alignment: Alignment.center,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dotted,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.add_circle_outline_rounded),
            color: value < max ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
