import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../ai/models/itinerary_request.dart';
import '../../ai/planner_options.dart';
import '../../ai/providers/ai_planner_provider.dart';
import '../../ai/repositories/ai_repository.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/services/itinerary_offline_service.dart';
import '../../core/services/local_preferences_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/places_service.dart';
import '../../core/services/weather_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/expense_split.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/itinerary_export.dart';
import '../../core/utils/itinerary_route_matcher.dart';
import '../../core/utils/maps_launcher.dart';
import '../../core/utils/province_matcher.dart';
import '../../core/utils/reminder_picker.dart';
import '../../core/widgets/banners/offline_banner.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/dialogs/emergency_access_sheet.dart';
import '../../core/widgets/cards/restaurant_card.dart';
import '../../core/widgets/cards/travel_image_frame.dart';
import '../../core/widgets/details/trip_route_map.dart';
import '../../core/widgets/indicators/rating_widget.dart';
import '../../core/widgets/layout/section_header.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/itinerary_repository.dart';
import '../../data/repositories/poll_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/itinerary.dart';
import '../../domain/models/packing_item.dart';
import '../../domain/models/poll.dart';
import '../../domain/models/province.dart';
import '../../domain/models/restaurant.dart';
import '../../domain/models/saved_itinerary.dart';
import 'widgets/map_destination_picker.dart';
import '../../core/widgets/media/image_error_placeholder.dart';

/// Canonical position of a time-slot label in the fixed Morning → Afternoon
/// → Evening sequence — anything else (a legacy free-text time from before
/// activities were restricted to these three, or old saved data) sorts
/// after all three rather than breaking the sequence. Used only for
/// *display and reordering* — never persisted — so this can't silently
/// rewrite an existing trip's data, only how it's shown.
int _timeSlotRank(String time) {
  switch (time.trim().toLowerCase()) {
    case 'morning':
      return 0;
    case 'afternoon':
      return 1;
    case 'evening':
      return 2;
    default:
      return 3;
  }
}

/// [activities] grouped and ordered by [_timeSlotRank] — Morning first,
/// then Afternoon, then Evening, then anything else — with everything
/// *within* the same slot kept in its original relative order (a stable
/// sort, not [List.sort]'s unstable one, since two "Evening" activities
/// swapped via [_GeneratedItineraryScreenState._reorderWithinSlot] must
/// actually show up swapped). This is the one place both
/// [_TimelineActivity]'s display order and [_GeneratedItineraryScreenState
/// ._reorderWithinSlot]'s neighbor lookup are computed from, so the two
/// can never disagree about what's "next to" what.
List<ItineraryActivity> sortActivitiesByTimeSlot(
  List<ItineraryActivity> activities,
) {
  final indexed = activities.indexed.toList()
    ..sort((a, b) {
      final rankCompare = _timeSlotRank(
        a.$2.time,
      ).compareTo(_timeSlotRank(b.$2.time));
      return rankCompare != 0 ? rankCompare : a.$1.compareTo(b.$1);
    });
  return indexed.map((e) => e.$2).toList();
}

/// The trip-planner result: a day-by-day timeline, budget breakdown, weather
/// outlook, recommendations and travel tips. Can either show a freshly
/// AI-generated [Itinerary] or a previously [SavedItinerary] opened from
/// "Saved Trips".
class GeneratedItineraryScreen extends StatefulWidget {
  const GeneratedItineraryScreen({
    super.key,
    required this.itinerary,
    this.savedItineraryId,
  });

  final Itinerary itinerary;

  /// Non-null when opened from the Saved Trips list — swaps the "Save"
  /// action for "Remove from Saved".
  final String? savedItineraryId;

  @override
  State<GeneratedItineraryScreen> createState() =>
      _GeneratedItineraryScreenState();
}

class _GeneratedItineraryScreenState extends State<GeneratedItineraryScreen>
    with SingleTickerProviderStateMixin {
  final ItineraryRepository _repository = ItineraryRepository();
  final RestaurantRepository _restaurantRepository = RestaurantRepository();
  final ExpenseRepository _expenseRepository = ExpenseRepository();
  final PollRepository _pollRepository = PollRepository();
  final ItineraryOfflineService _offlineService = ItineraryOfflineService();
  final LocalPreferencesService _preferencesService = LocalPreferencesService();
  final PlacesService _places = PlacesService();
  bool _busy = false;
  bool _exportingPdf = false;
  bool _offlineBusy = false;
  bool _regenerating = false;

  /// Guards [_toggleCompleted] against a rapid double-tap starting a
  /// second write before the first one's finished — without this, tapping
  /// twice fast enough could let an earlier "mark complete" write land
  /// *after* a later "unmark" write, leaving the trip marked complete
  /// despite the traveler's last tap saying otherwise.
  bool _togglingCompleted = false;

  /// Non-null only while [_regenerateActivity] is in flight for this exact
  /// activity — reference equality against the in-memory instance, same
  /// pattern [_editActivity]/[_removeActivity] already use to find one
  /// activity inside its day. Drives that one [_TimelineActivity]'s own
  /// spinner without disabling every other activity's controls on the day.
  ItineraryActivity? _regeneratingActivity;
  bool _isAvailableOffline = false;
  List<Restaurant> _recommendedRestaurants = [];
  SavedItinerary? _savedItinerary;

  /// Resolved lazily the first time the Emergency button is tapped, then
  /// cached — [Itinerary] has no stored province reference (see
  /// [_regenerate]'s doc comment), so this name-matches
  /// [Itinerary.destinationName] against the same province list, with no
  /// live Places call needed for what's meant to be a one-tap action.
  Province? _emergencyProvince;
  bool _resolvedEmergencyProvince = false;

  /// Non-null once the traveler edits the trip's start date — re-fetched for
  /// that specific date range rather than trusting [Itinerary.weather],
  /// which was only ever fetched once for "starting today" at generation
  /// time. An empty list (as opposed to null) means a refresh was attempted
  /// but no real forecast is available for that date (see
  /// [_refreshWeatherForDate]), so the UI should show a fallback message
  /// instead of silently falling back to the stale original forecast.
  List<WeatherForecast>? _weatherOverride;

  /// When [_weatherOverride] was last actually fetched — null until the
  /// first live fetch resolves (i.e. while still showing
  /// [Itinerary.weather], the stale generation-time forecast). Shown next to
  /// "Weather Outlook" so a traveler reopening a trip days later can tell
  /// this isn't the same forecast they saw last time, without needing to
  /// know that's how it works internally.
  DateTime? _weatherFetchedAt;

  List<WeatherForecast> get _weather =>
      _weatherOverride ?? widget.itinerary.weather;

  /// Set right before a deliberate pop (after the traveler chooses Save or
  /// Discard in [_handleUnsavedPopAttempt]) so that second, self-triggered
  /// pop attempt isn't intercepted all over again.
  bool _readyToPop = false;

  /// Which of the four saved-trip tabs (Itinerary/Budget/Packing/Group) is
  /// showing — a real [TabController] rather than scrolling to an in-page
  /// anchor, so a deep link from Saved Trips ("Expenses"/"Packing List"/
  /// "Group Polls") opens directly on that tab with nothing to scroll past,
  /// instead of landing at the top of one long page and hoping an
  /// auto-scroll finds its target in time. Only meaningful once
  /// [widget.savedItineraryId] is set — see [_buildTabbedBody].
  late final TabController _tabController;

  bool get _isSaved => widget.savedItineraryId != null;

  String? get _uid => context.read<AuthProvider>().firebaseUser?.uid;

  bool get _isOwner =>
      _savedItinerary == null || _savedItinerary!.userId == _uid;

  /// Manual day-by-day activity edits (add/remove/reorder) are owner-only,
  /// same rule collaborators already have on the itinerary's other content
  /// (see `firestore.rules`' `saved_itineraries` update block — a
  /// collaborator's write is scoped to collaboratorIds/memberNames/
  /// packingItems/expenses, never `itinerary` itself), and only meaningful
  /// once the trip is actually saved — an unsaved trip's initial "Save" tap
  /// still writes `widget.itinerary` as-is (see `_toggleSave`), so an edit
  /// made before that point would silently be lost.
  bool get _canEditActivities => _isOwner && widget.savedItineraryId != null;

  /// Same gating as [_canEditActivities], for correcting an AI-estimated
  /// [BudgetLineItem] price — the AI's number is only ever an estimate (see
  /// `ItineraryPrompts`'s rules), never a live quote, so it can be wrong.
  bool get _canEditBudget => _isOwner && widget.savedItineraryId != null;

  /// Off by default — a saved trip's Day-by-Day and Budget Summary sections
  /// render as a clean read-only view (no pencil/regenerate/remove/add
  /// icons cluttering every row) until the traveler deliberately taps the
  /// "Edit" toggle. [_canEditActivities]/[_canEditBudget] alone answer
  /// "is this person even allowed to edit" — this answers "are they
  /// actively editing right now"; the actual per-icon gates below always
  /// check both together.
  bool _editMode = false;

  bool get _showActivityEditControls => _canEditActivities && _editMode;
  bool get _showBudgetEditControls => _canEditBudget && _editMode;

  /// The Edit/Done toggle itself — one per tab's own section header (Day-
  /// by-Day Plan, Budget Tracker, Packing Checklist, Group Polls) rather
  /// than a single one in the shared action row above the tabs, so a
  /// traveler can tell at a glance which tab's edit controls they're about
  /// to turn on. All four still flip the same [_editMode] — turning
  /// editing on in one tab turns it on everywhere, just toggled from
  /// wherever's convenient. Empty when the viewer can't edit at all.
  Widget _editToggleButton() {
    if (!_canEditActivities) return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: () => setState(() => _editMode = !_editMode),
      icon: Icon(
        _editMode ? Symbols.check_rounded : Symbols.edit_rounded,
        size: 18,
      ),
      label: Text(_editMode ? 'Done' : 'Edit'),
    );
  }

  /// Whether the viewer is actually a member of this trip (owner or
  /// collaborator) — gates the "New Poll"/"Add Expense"/"Add Item"
  /// affordances, which were otherwise offered to *any* signed-in viewer
  /// who reaches this screen (e.g. via a guessed/shared savedId they were
  /// never actually added to), not just this trip's real members;
  /// `firestore.rules` would reject each of those writes either way, but
  /// showing a button that's guaranteed to fail is a worse experience than
  /// not showing it. Same "assume yes until the load finishes" default as
  /// [_isOwner], for the same reason: loading [_savedItinerary] is
  /// asynchronous, and treating it as "not a member yet" would flash-hide
  /// these for this trip's own owner while that load is still in flight.
  bool get _isTripMember =>
      _savedItinerary == null || _savedItinerary!.memberIds.contains(_uid);

  /// A local, editable copy of the budget breakdown/total — same reasoning
  /// as [_days] below, mutated on an item price edit and persisted via
  /// [_persistBudget].
  late List<BudgetItem> _budgetBreakdown = widget.itinerary.budgetBreakdown;
  late double _totalBudget = widget.itinerary.totalBudget;

  /// A local, editable copy of the itinerary's days — [widget.itinerary] is
  /// immutable (it's the value passed in via navigation), so manual activity
  /// edits mutate this instead and persist via [_persistDays].
  late List<ItineraryDay> _days = widget.itinerary.days;

  /// Which day the Day-by-Day Plan shows — one at a time with Prev/Next
  /// arrows, instead of every day stacked in one long scroll. A multi-day
  /// trip's activity list (3 cards a day, each with its own description
  /// and edit controls) gets long fast; paging keeps each view to one
  /// day's worth of content.
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRecommendations();
    unawaited(_resolveProvince());
    if (widget.savedItineraryId != null) {
      _loadSavedItinerary();
      _loadOfflineStatus();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOfflineStatus() async {
    final ids = await _preferencesService.getOfflineItineraryIds();
    final isAvailable = ids.contains(widget.savedItineraryId);
    if (mounted) setState(() => _isAvailableOffline = isAvailable);
    // The downloaded snapshot was otherwise a one-time capture with no way
    // to know it had gone stale (a collaborator's edit, a changed start
    // date) — opening the trip screen at all means there's connectivity
    // right now, so quietly re-warming it here keeps an already-downloaded
    // trip's offline copy no more than "one online visit" out of date,
    // without needing a separate staleness check. Silent and best-effort:
    // no loading state, no error surfaced — the traveler already has a
    // working (if slightly stale) offline copy either way.
    if (isAvailable && mounted) {
      unawaited(
        _offlineService
            .makeAvailableOffline(
              context: context,
              itineraryId: widget.savedItineraryId!,
              itinerary: widget.itinerary,
            )
            .catchError((_) {}),
      );
    }
  }

  Future<void> _saveOffline() async {
    setState(() => _offlineBusy = true);
    try {
      await _offlineService.makeAvailableOffline(
        context: context,
        itineraryId: widget.savedItineraryId!,
        itinerary: widget.itinerary,
      );
      if (mounted) {
        setState(() => _isAvailableOffline = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This trip is now available offline.')),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    } finally {
      if (mounted) setState(() => _offlineBusy = false);
    }
  }

  Future<void> _loadSavedItinerary() async {
    try {
      final trip = await _repository.getById(widget.savedItineraryId!);
      if (mounted) setState(() => _savedItinerary = trip);
      // Otherwise the Weather Outlook silently kept showing the forecast
      // fetched back on the day this trip was first generated, forever —
      // _refreshWeatherForDate was only ever wired to the date *picker*
      // (_editStartDate), never to loading a trip that already has a date.
      if (trip?.startDate != null) {
        await _refreshWeatherForDate(trip!.startDate!);
      }
    } catch (_) {
      // Best-effort: falls back to owner-only view (packing/collaborators
      // sections simply won't render) rather than blocking the itinerary.
    }
  }

  // The itinerary only stores restaurant ids — resolved here against the
  // live Firestore catalog so "Recommended Restaurants" always shows real,
  // current listings rather than a frozen snapshot. Nearby attractions are
  // Google Places-only (see `recommendedPlaceAttractions`) and already come
  // fully resolved off the itinerary itself — no separate fetch needed.
  Future<void> _loadRecommendations() async {
    try {
      final restaurants = await _restaurantRepository.getByIds(
        widget.itinerary.recommendedRestaurantIds,
      );
      if (!mounted) return;
      setState(() => _recommendedRestaurants = restaurants);
    } catch (_) {
      // Best-effort: this is a supplementary section, never worth
      // blocking or erroring the whole itinerary view over.
    }
  }

  Future<void> _toggleSave() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.firebaseUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save this itinerary.')),
      );
      return;
    }
    if (widget.savedItineraryId != null) {
      final confirmed = await showConfirmationDialog(
        context,
        title: 'Remove this trip?',
        message:
            '"${widget.itinerary.destinationName}" will be permanently removed from your saved trips.',
        confirmLabel: 'Remove',
        isDestructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    DateTime? startDate;
    if (widget.savedItineraryId == null) {
      // Optional — the traveler can pick a travel date now or set/edit it
      // later from the itinerary screen. Cancelling the picker just skips it.
      startDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 730)),
        helpText: 'When are you traveling? (optional)',
      );
      if (!mounted) return;
    }
    setState(() => _busy = true);
    try {
      if (widget.savedItineraryId != null) {
        await _repository.delete(widget.savedItineraryId!);
        if (mounted) context.pop();
        return;
      }
      final savedId = await _repository.save(
        userId: uid,
        title: widget.itinerary.destinationName,
        itinerary: widget.itinerary,
        startDate: startDate,
        ownerName: context.read<AuthProvider>().currentUser?.name ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Itinerary saved to your trips.')),
        );
        // Reopen as the saved trip (savedItineraryId is otherwise final/unset
        // on this route) so Budget Tracker, Packing Checklist and Trip
        // Companions — all gated on having a saved id — show up right away
        // instead of only after leaving and reopening from Saved Trips.
        context.pushReplacement(
          RoutePaths.generatedItinerary,
          extra: {'itinerary': widget.itinerary, 'savedId': savedId},
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Backs the [PopScope] guard in [build] — a freshly generated itinerary
  /// (never saved) is only ever held in this route's memory, so leaving
  /// without a choice here would silently discard it, which is exactly the
  /// "I can't find my itinerary again" complaint this guards against.
  Future<void> _handleUnsavedPopAttempt() async {
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save this trip?'),
        content: const Text(
          'This itinerary hasn\'t been saved yet — leaving now will discard it for good.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save & Leave'),
          ),
        ],
      ),
    );
    if (!mounted || shouldSave == null)
      return; // dismissed (tapped outside/back) — stay put
    if (shouldSave) {
      await _saveThenLeave();
    } else {
      setState(() => _readyToPop = true);
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// A quicker version of the bookmark button's save flow for the
  /// leave-without-saving prompt — skips the optional travel-date picker
  /// (friction on top of a confirm dialog) since the date can always be set
  /// later from the saved trip screen.
  Future<void> _saveThenLeave() async {
    final uid = _uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save this itinerary.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _repository.save(
        userId: uid,
        title: widget.itinerary.destinationName,
        itinerary: widget.itinerary,
        ownerName: context.read<AuthProvider>().currentUser?.name ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Itinerary saved to your trips.')),
      );
      setState(() => _readyToPop = true);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
      }
    }
  }

  Future<void> _editStartDate() async {
    final trip = _savedItinerary;
    if (trip == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: trip.startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'When are you traveling?',
    );
    if (picked == null || !mounted) return;
    // Moving an already-"completed" trip's date back into the future would
    // otherwise leave it in a contradictory state — marked as been-on
    // while its own date says it hasn't started yet. Clearing it here
    // keeps that from silently happening; the traveler can always
    // re-mark it complete once the (new) date actually arrives.
    final shouldClearCompleted =
        trip.isCompleted && DateTime.now().isBefore(picked);
    setState(() {
      _savedItinerary = shouldClearCompleted
          ? trip.copyWith(startDate: picked, clearCompletedAt: true)
          : trip.copyWith(startDate: picked);
    });
    try {
      await _repository.updateStartDate(trip.id, picked);
      if (shouldClearCompleted) {
        await _repository.updateCompletedAt(trip.id, null);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unmarked as completed — the new date is still upcoming.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
    // Any reminder set earlier was relative to the OLD date and has no
    // reliable way to be re-derived for the new one (it's a freely-picked
    // date/time, not always "N days before the trip") — cancelling rather
    // than leaving it to silently fire on a date that's no longer this
    // trip's start is the safer failure mode. NotificationService.
    // cancelReminder is a no-op if nothing was ever scheduled for that id.
    await NotificationService.instance.cancelReminder(
      _reminderId(isTravelDay: true),
    );
    await NotificationService.instance.cancelReminder(
      _reminderId(isTravelDay: false),
    );
    await _refreshWeatherForDate(picked);
  }

  /// Flips "marked as completed" on/off — self-reported by the owner, no
  /// verification (see [SavedItinerary.completedAt]'s doc comment). Same
  /// optimistic-then-revert pattern as [_persistBudget]/[_persistDays]: a
  /// write failure is rare enough (owner-only, no concurrent editor) that
  /// reverting on the actual error is simpler than a pre-flight check.
  ///
  /// Only confirmed (and validated) on the way *to* completed —
  /// un-marking is a plain, reversible toggle with nothing destructive
  /// about it. Two things block it outright, not just warn about it:
  /// - No [SavedItinerary.startDate] set at all — a trip with no date
  ///   can't meaningfully have "started" yet either.
  /// - A [startDate] still in the future — a trip that hasn't started
  ///   can't have been "been on" already.
  ///
  /// [_togglingCompleted] guards against a rapid double-tap starting a
  /// second write before the first one's finished — see its own doc
  /// comment for why that matters.
  Future<void> _toggleCompleted() async {
    if (_togglingCompleted) return;
    final trip = _savedItinerary;
    if (trip == null) return;
    final wasCompleted = trip.isCompleted;
    if (!wasCompleted) {
      final startDate = trip.startDate;
      if (startDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Set a travel date for this trip before marking it completed.',
            ),
          ),
        );
        return;
      }
      if (DateTime.now().isBefore(startDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This trip starts ${DateFormat('MMM d, y').format(startDate)} — '
              'you can mark it completed once it\'s underway.',
            ),
          ),
        );
        return;
      }
      final confirmed = await showConfirmationDialog(
        context,
        title: 'Mark this trip as completed?',
        message:
            'This just tracks that you\'ve been on the trip — you can still edit '
            'or unmark it anytime after.',
        confirmLabel: 'Mark Completed',
      );
      if (!confirmed || !mounted) return;
    }
    final newCompletedAt = wasCompleted ? null : DateTime.now();
    setState(() {
      _togglingCompleted = true;
      _savedItinerary = wasCompleted
          ? trip.copyWith(clearCompletedAt: true)
          : trip.copyWith(completedAt: newCompletedAt);
    });
    try {
      await _repository.updateCompletedAt(trip.id, newCompletedAt);
    } catch (e) {
      if (!mounted) return;
      setState(() => _savedItinerary = trip);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    } finally {
      if (mounted) setState(() => _togglingCompleted = false);
    }
  }

  /// Re-fetches the Weather Outlook for [startDate] instead of leaving it
  /// showing [Itinerary.weather] — a forecast for "starting today" fetched
  /// once at generation time, which has nothing to do with a trip date
  /// picked afterward. Open-Meteo's free forecast only reaches 16 days
  /// ahead of today; when the trip's date range falls outside that window
  /// there's no real forecast to show, so [_weatherOverride] is set to an
  /// empty list (a fallback message) rather than guessing.
  Future<void> _refreshWeatherForDate(DateTime startDate) async {
    final latitude = widget.itinerary.destinationLatitude;
    final longitude = widget.itinerary.destinationLongitude;
    if (latitude == null || longitude == null) return;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final tripDate = DateTime(startDate.year, startDate.month, startDate.day);
    final daysUntilTrip = tripDate.isBefore(todayDate)
        ? 0
        : tripDate.difference(todayDate).inDays;
    final forecastWindow = daysUntilTrip + widget.itinerary.totalDays;

    if (forecastWindow > 16) {
      if (mounted) setState(() => _weatherOverride = const []);
      return;
    }

    // A fresh client per request, never a field held for the widget's whole
    // lifetime — the same fix CurrentWeatherCard already needed: reusing
    // one long-lived http.Client across requests can get stuck after a
    // network blip, silently returning empty/stale forecasts on every
    // subsequent date change until the screen is closed and reopened.
    final weatherService = WeatherService();
    List<WeatherForecast> forecast;
    try {
      forecast = await weatherService.getForecast(
        latitude: latitude,
        longitude: longitude,
        days: forecastWindow,
      );
    } finally {
      weatherService.dispose();
    }
    final forTrip = forecast.length > daysUntilTrip
        ? forecast.sublist(daysUntilTrip)
        : const <WeatherForecast>[];
    if (mounted) {
      setState(() {
        _weatherOverride = forTrip;
        _weatherFetchedAt = DateTime.now();
      });
    }
  }

  /// Re-runs generation for the same destination — resolved fresh via
  /// Places (the same "search by name, then match its province" building
  /// block the AI Chat generate flow already uses), since neither
  /// [Itinerary] nor [SavedItinerary] persist the original request's
  /// province, budget tier, transportation or interests. Days, traveler
  /// count and accommodation carry over from this itinerary; budget tier is
  /// approximated from [Itinerary.totalBudget] against the Planner form's
  /// own tiers, and traveler type from the traveler count, since neither's
  /// original label survives past generation. Lands on a fresh (unsaved)
  /// itinerary via `pushReplacement` — same place, new content, without
  /// silently overwriting an already-saved trip or piling up a back-stack
  /// entry per regenerate.
  /// Best-effort — an unresolved province just means [showEmergencyAccessSheet]
  /// falls back to its nationwide-only view, never blocks opening it at all,
  /// and the "Getting Around" section (see [build]) simply doesn't show.
  Future<void> _resolveProvince() async {
    if (_resolvedEmergencyProvince) return;
    try {
      final provinces = await ProvinceRepository().getAll();
      _emergencyProvince = matchProvinceByAddress(
        widget.itinerary.destinationName,
        provinces,
      );
    } catch (_) {
      _emergencyProvince = null;
    }
    _resolvedEmergencyProvince = true;
    if (mounted) setState(() {});
  }

  Future<void> _showEmergency() async {
    await _resolveProvince();
    if (!mounted) return;
    showEmergencyAccessSheet(
      context,
      provinceId: _emergencyProvince?.id,
      provinceName: _emergencyProvince?.name,
    );
  }

  /// Opens wherever a budget line item said to get it (a Food dish's
  /// restaurant, an Entrance Fee's attraction, an Accommodation item's
  /// hotel, ...). Tries, in order: a real in-app restaurant page when
  /// [line.place] matches one of this trip's already-loaded recommended
  /// restaurants by name; the same "open in Maps" behavior
  /// [_PlaceRecommendationCard] uses when it matches one of
  /// [Itinerary.recommendedPlaceAttractions] or
  /// [Itinerary.recommendedAccommodations] instead; otherwise a plain
  /// Google Maps search for that place near the destination. No extra
  /// geocoding call for any of these — all three candidate lists are
  /// already loaded for their own carousels, so a match is free and a miss
  /// just falls back gracefully instead of failing. A no-op for a
  /// Transportation item, which intentionally has no [BudgetLineItem.place]
  /// to resolve (see `ItineraryPrompts`'s rule) — [_BudgetSummaryCard] never
  /// wires a tap for an empty `place` in the first place.
  void _openBudgetItemPlace(BudgetLineItem line, List<Restaurant> restaurants) {
    final restaurantMatch = restaurants
        .where((r) => r.name.toLowerCase() == line.place.toLowerCase())
        .firstOrNull;
    if (restaurantMatch != null) {
      context.push(RoutePaths.restaurantDetails(restaurantMatch.id));
      return;
    }
    final placeMatch =
        [
              ...widget.itinerary.recommendedPlaceAttractions,
              ...widget.itinerary.recommendedAccommodations,
            ]
            .where((p) => p.name.toLowerCase() == line.place.toLowerCase())
            .firstOrNull;
    if (placeMatch != null) {
      _openPlaceRecommendation(placeMatch);
      return;
    }
    MapsLauncher.openPlaceSearch(
      '${line.place}, ${widget.itinerary.destinationName}, Philippines',
    );
  }

  /// Same "open in Maps" priority [_PlaceRecommendationCard] uses for its
  /// own tap target — factored out so [_openBudgetItemPlace] can reuse it
  /// instead of duplicating the mapsUri/coordinates/fallback chain.
  void _openPlaceRecommendation(PlaceRecommendation place) {
    if (place.mapsUri.isNotEmpty) {
      MapsLauncher.openUrl(place.mapsUri);
    } else if (place.hasCoordinates) {
      MapsLauncher.openDirections(
        latitude: place.latitude!,
        longitude: place.longitude!,
        label: place.name,
      );
    } else {
      MapsLauncher.openPlaceSearch('${place.name}, Philippines');
    }
  }

  Future<void> _regenerate() => _regenerateInternal();

  Future<void> _regenerateInternal({String? refinementInstruction}) async {
    setState(() => _regenerating = true);
    try {
      final places = await _places.searchText(
        textQuery: '${widget.itinerary.destinationName}, Philippines',
      );
      final place = places.isNotEmpty ? places.first : null;
      if (place == null) {
        _showRegenerateError(
          'Couldn\'t find that destination again — try Regenerate once more, or start a new trip from the Planner.',
        );
        return;
      }

      final provinces = await ProvinceRepository().getAll();
      final province = matchProvinceByAddress(place.address, provinces);
      if (province == null) {
        _showRegenerateError(
          'Couldn\'t match "${place.name}" to a province — try again shortly.',
        );
        return;
      }

      if (!mounted) return;
      final travelers = widget.itinerary.travelers;
      final travelerType = travelers <= 1
          ? 'Solo'
          : (travelers == 2 ? 'Couple' : 'Friends');
      final (budgetTierLabel, budgetRange) = inferBudgetTier(
        widget.itinerary.totalBudget,
      );

      final planner = context.read<AiPlannerProvider>();
      final itinerary = await planner.generate(
        AiItineraryRequest(
          destinationId: place.id,
          destinationName: place.name,
          provinceId: province.id,
          provinceName: province.name,
          budgetTierLabel: budgetTierLabel,
          budgetRange: budgetRange,
          days: widget.itinerary.totalDays,
          travelers: travelers,
          travelerType: travelerType,
          transportation: const {defaultTransportation},
          interests: defaultInterests,
          latitude: place.latitude,
          longitude: place.longitude,
          accommodationName: widget.itinerary.accommodationName.isNotEmpty
              ? widget.itinerary.accommodationName
              : null,
          refinementInstruction: refinementInstruction,
        ),
        coverImageUrl: widget.itinerary.coverImageUrl.isNotEmpty
            ? widget.itinerary.coverImageUrl
            : (place.photoNames.isNotEmpty
                  ? _places.photoUrl(place.photoNames.first)
                  : province.heroImageUrl),
        // Skips the cached-response short-circuit — otherwise an identical
        // reconstructed request would just hand back this same itinerary,
        // defeating the point of "Regenerate".
        forceRefresh: true,
      );

      if (!mounted) return;
      if (itinerary != null) {
        final savedId = widget.savedItineraryId;
        if (savedId != null) {
          // Already saved — this is about to overwrite it in place, with no
          // undo. Let the traveler see it's about to happen and back out;
          // declining just discards the freshly generated result and leaves
          // the saved trip exactly as it was.
          final confirmed = await showConfirmationDialog(
            context,
            title: 'Replace your saved itinerary?',
            message:
                'This swaps in the new plan and can\'t be undone. Your current saved itinerary will be gone.',
            confirmLabel: 'Replace',
            isDestructive: true,
          );
          if (!confirmed || !mounted) return;
          // Already saved — overwrite the same trip in place instead of
          // leaving it stale/orphaned while this pushes a second, separate
          // unsaved copy (see updateItinerary's doc comment).
          try {
            await _repository.updateItinerary(
              savedId,
              title: itinerary.destinationName,
              itinerary: itinerary,
            );
          } catch (e) {
            if (!mounted) return;
            _showRegenerateError(AppException.from(e).message);
            return;
          }
        }
        if (!mounted) return;
        context.pushReplacement(
          RoutePaths.generatedItinerary,
          extra: {
            'itinerary': itinerary,
            if (savedId != null) 'savedId': savedId,
          },
        );
      } else {
        _showRegenerateError(
          planner.errorMessage ??
              'Couldn\'t regenerate your itinerary. Please try again.',
        );
      }
    } catch (_) {
      _showRegenerateError(
        'Something went wrong regenerating that itinerary. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  void _showRegenerateError(String reason) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
  }

  Rect? _sharePositionOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _share() async {
    try {
      await Share.share(
        ItineraryExport.buildShareText(widget.itinerary),
        subject: '${widget.itinerary.destinationName} itinerary — TripNest PH',
        sharePositionOrigin: _sharePositionOrigin(),
      );
    } catch (e) {
      if (!mounted) return;
      logTechnicalError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t open the share menu. Please try again.')),
      );
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _exportingPdf = true);
    try {
      final bytes = await ItineraryExport.buildPdfBytes(widget.itinerary);
      final dir = await getTemporaryDirectory();
      final fileName =
          '${widget.itinerary.destinationName.replaceAll(RegExp(r'[^\w\s-]'), '')}_itinerary.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${widget.itinerary.destinationName} itinerary — TripNest PH',
        sharePositionOrigin: _sharePositionOrigin(),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  /// Keyed by the trip's own saved id, not just its destination name — two
  /// separate saved trips to the same place (different dates) used to
  /// collide on the same notification id, so scheduling a reminder on the
  /// second trip silently cancelled the first trip's reminder (see
  /// `NotificationService.scheduleReminder`'s "same id replaces it"
  /// contract). Packing vs. travel-day still get different id offsets so
  /// scheduling one never overwrites the other for the *same* trip.
  int _reminderId({required bool isTravelDay}) {
    return widget.savedItineraryId.hashCode + (isTravelDay ? 0 : 1);
  }

  Future<void> _setReminder() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.flight_takeoff_rounded),
              title: const Text('Travel Day Reminder'),
              subtitle: const Text('Get notified as your trip approaches'),
              onTap: () => Navigator.of(context).pop('travel'),
            ),
            ListTile(
              leading: const Icon(Symbols.luggage_rounded),
              title: const Text('Packing Reminder'),
              subtitle: const Text('A heads-up to pack ahead of time'),
              onTap: () => Navigator.of(context).pop('packing'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    final dateTime = await pickReminderDateTime(context);
    if (dateTime == null || !mounted) return;

    final isTravelDay = choice == 'travel';
    final id = _reminderId(isTravelDay: isTravelDay);
    await NotificationService.instance.scheduleReminder(
      id: id,
      title: isTravelDay ? 'Travel Day Reminder' : 'Packing Reminder',
      body: isTravelDay
          ? 'Your trip to ${widget.itinerary.destinationName} is coming up!'
          : 'Start packing for your trip to ${widget.itinerary.destinationName}.',
      dateTime: dateTime,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${isTravelDay ? 'Travel day' : 'Packing'} reminder set.',
          ),
        ),
      );
    }
  }

  Future<void> _addExpense() async {
    final categories = [
      ...widget.itinerary.budgetBreakdown.map((b) => b.label),
      'Other',
    ];
    var selectedCategory = categories.first;
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String? errorText;

    final uid = _uid;
    final memberIds =
        _savedItinerary?.memberIds ?? (uid != null ? [uid] : const <String>[]);
    final memberNames =
        _savedItinerary?.memberNames ?? const <String, String>{};
    String nameFor(String id) =>
        id == uid ? 'You' : (memberNames[id] ?? 'Traveler');
    // Solo trips skip the split picker entirely — nothing to divide. Group
    // trips default to splitting between everyone, since that matches how
    // expenses worked before per-companion splitting existed.
    final splitWith = memberIds.toSet();
    String? splitErrorText;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(
                    () => selectedCategory = v ?? selectedCategory,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount (₱)',
                    errorText: errorText,
                    prefixIcon: const Icon(Symbols.payments_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    prefixIcon: Icon(Symbols.edit_note_rounded, size: 20),
                  ),
                ),
                if (memberIds.length > 1) ...[
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Split between',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  ...memberIds.map(
                    (id) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(nameFor(id)),
                      value: splitWith.contains(id),
                      onChanged: (checked) => setDialogState(() {
                        if (checked ?? false) {
                          splitWith.add(id);
                          splitErrorText = null;
                        } else {
                          splitWith.remove(id);
                        }
                      }),
                    ),
                  ),
                  if (splitErrorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          splitErrorText!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amountError = Validators.amount(
                  amountController.text,
                  required: true,
                  maxAmount: 500000,
                );
                if (amountError != null) {
                  setDialogState(() => errorText = amountError);
                  return;
                }
                if (splitWith.isEmpty) {
                  setDialogState(
                    () => splitErrorText =
                        'Select at least one person to split with',
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    if (uid == null) return;
    try {
      await _expenseRepository.add(
        itineraryId: widget.savedItineraryId!,
        category: selectedCategory,
        amount: double.parse(amountController.text.trim()),
        splitBetween: splitWith.length == memberIds.length
            ? const []
            : splitWith.toList(),
        note: noteController.text.trim(),
        loggedBy: uid,
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  /// Up to 6 options (mirrors `isValidPoll()` in firestore.rules) — starts
  /// at 2 empty fields, "+ Add option" grows the list, an empty trailing
  /// field just gets dropped on submit rather than blocking it.
  Future<void> _createPoll() async {
    final uid = _uid;
    if (uid == null) return;
    final questionController = TextEditingController();
    var optionControllers = [TextEditingController(), TextEditingController()];
    String? errorText;
    String? optionsErrorText;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Poll'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionController,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: 'Question',
                    hintText: 'e.g. Which restaurant for Day 2?',
                    errorText: errorText,
                    prefixIcon: const Icon(
                      Symbols.how_to_vote_rounded,
                      size: 20,
                    ),
                  ),
                ),
                for (var i = 0; i < optionControllers.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: TextField(
                      controller: optionControllers[i],
                      maxLength: 100,
                      decoration: InputDecoration(
                        labelText: 'Option ${i + 1}',
                        counterText: '',
                        suffixIcon: optionControllers.length > 2
                            ? IconButton(
                                icon: const Icon(
                                  Symbols.close_rounded,
                                  size: 18,
                                ),
                                onPressed: () => setDialogState(() {
                                  optionControllers = [...optionControllers]
                                    ..removeAt(i);
                                }),
                              )
                            : null,
                      ),
                    ),
                  ),
                if (optionControllers.length < 6)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setDialogState(
                        () => optionControllers = [
                          ...optionControllers,
                          TextEditingController(),
                        ],
                      ),
                      icon: const Icon(Symbols.add_rounded, size: 18),
                      label: const Text('Add option'),
                    ),
                  ),
                if (optionsErrorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        optionsErrorText!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (questionController.text.trim().isEmpty) {
                  setDialogState(() {
                    errorText = 'Enter a question';
                    optionsErrorText = null;
                  });
                  return;
                }
                final filled = optionControllers
                    .map((c) => c.text.trim())
                    .where((t) => t.isNotEmpty)
                    .toList();
                if (filled.length < 2) {
                  setDialogState(() {
                    errorText = null;
                    optionsErrorText = 'Add at least 2 options.';
                  });
                  return;
                }
                // Distinct case-insensitively — "Restaurant A" typed twice
                // would otherwise sit at two different indices, silently
                // splitting votes between what looks like one option.
                final distinct = filled.map((t) => t.toLowerCase()).toSet();
                if (distinct.length != filled.length) {
                  setDialogState(() {
                    errorText = null;
                    optionsErrorText =
                        'Options must be different from each other.';
                  });
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await _pollRepository.create(
        itineraryId: widget.savedItineraryId!,
        question: questionController.text.trim(),
        options: optionControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        createdBy: uid,
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Future<void> _votePoll(Poll poll, int optionIndex) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _pollRepository.vote(
        itineraryId: widget.savedItineraryId!,
        pollId: poll.id,
        uid: uid,
        optionIndex: optionIndex,
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  /// Editing clears the poll's existing votes — matches firestore.rules'
  /// `polls` update rule, which requires the same reset, since a shifted or
  /// removed option would leave existing votes pointing at the wrong index.
  /// Only reachable when `canDelete` is true (creator or trip owner) in
  /// `_PollCard` — the same people the update rule permits.
  Future<void> _editPoll(Poll poll) async {
    final questionController = TextEditingController(text: poll.question);
    var optionControllers = poll.options
        .map((o) => TextEditingController(text: o))
        .toList();
    String? errorText;
    String? optionsErrorText;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Poll'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (poll.totalVotes > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'Saving will clear the ${poll.totalVotes} existing vote${poll.totalVotes == 1 ? '' : 's'} on this poll.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                TextField(
                  controller: questionController,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: 'Question',
                    hintText: 'e.g. Which restaurant for Day 2?',
                    errorText: errorText,
                    prefixIcon: const Icon(
                      Symbols.how_to_vote_rounded,
                      size: 20,
                    ),
                  ),
                ),
                for (var i = 0; i < optionControllers.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: TextField(
                      controller: optionControllers[i],
                      maxLength: 100,
                      decoration: InputDecoration(
                        labelText: 'Option ${i + 1}',
                        counterText: '',
                        suffixIcon: optionControllers.length > 2
                            ? IconButton(
                                icon: const Icon(
                                  Symbols.close_rounded,
                                  size: 18,
                                ),
                                onPressed: () => setDialogState(() {
                                  optionControllers = [...optionControllers]
                                    ..removeAt(i);
                                }),
                              )
                            : null,
                      ),
                    ),
                  ),
                if (optionControllers.length < 6)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setDialogState(
                        () => optionControllers = [
                          ...optionControllers,
                          TextEditingController(),
                        ],
                      ),
                      icon: const Icon(Symbols.add_rounded, size: 18),
                      label: const Text('Add option'),
                    ),
                  ),
                if (optionsErrorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        optionsErrorText!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (questionController.text.trim().isEmpty) {
                  setDialogState(() {
                    errorText = 'Enter a question';
                    optionsErrorText = null;
                  });
                  return;
                }
                final filled = optionControllers
                    .map((c) => c.text.trim())
                    .where((t) => t.isNotEmpty)
                    .toList();
                if (filled.length < 2) {
                  setDialogState(() {
                    errorText = null;
                    optionsErrorText = 'Add at least 2 options.';
                  });
                  return;
                }
                final distinct = filled.map((t) => t.toLowerCase()).toSet();
                if (distinct.length != filled.length) {
                  setDialogState(() {
                    errorText = null;
                    optionsErrorText =
                        'Options must be different from each other.';
                  });
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await _pollRepository.update(
        itineraryId: widget.savedItineraryId!,
        pollId: poll.id,
        question: questionController.text.trim(),
        options: optionControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Future<void> _deletePoll(Poll poll) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete this poll?',
      message: '"${poll.question}" and its votes will be removed.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    try {
      await _pollRepository.delete(
        itineraryId: widget.savedItineraryId!,
        pollId: poll.id,
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  /// Only reachable for an expense the current user logged themselves —
  /// firestore.rules' `expenses` update rule only lets an edit through when
  /// the resulting doc's `loggedBy` still equals the caller's own uid, so an
  /// owner editing someone else's entry would fail server-side even though
  /// they're allowed to delete it. See `_BudgetTrackerCard`'s edit gating.
  Future<void> _editExpense(Expense expense) async {
    final categories = [
      ...widget.itinerary.budgetBreakdown.map((b) => b.label),
      'Other',
    ];
    var selectedCategory = categories.contains(expense.category)
        ? expense.category
        : categories.last;
    final amountController = TextEditingController(
      text: expense.amount.toStringAsFixed(2),
    );
    final noteController = TextEditingController(text: expense.note);
    String? errorText;

    final uid = _uid;
    final memberIds =
        _savedItinerary?.memberIds ?? (uid != null ? [uid] : const <String>[]);
    final memberNames =
        _savedItinerary?.memberNames ?? const <String, String>{};
    String nameFor(String id) =>
        id == uid ? 'You' : (memberNames[id] ?? 'Traveler');
    final splitWith = expense.splitBetween.isEmpty
        ? memberIds.toSet()
        : expense.splitBetween.toSet();
    String? splitErrorText;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(
                    () => selectedCategory = v ?? selectedCategory,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount (₱)',
                    errorText: errorText,
                    prefixIcon: const Icon(Symbols.payments_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    prefixIcon: Icon(Symbols.edit_note_rounded, size: 20),
                  ),
                ),
                if (memberIds.length > 1) ...[
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Split between',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  ...memberIds.map(
                    (id) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(nameFor(id)),
                      value: splitWith.contains(id),
                      onChanged: (checked) => setDialogState(() {
                        if (checked ?? false) {
                          splitWith.add(id);
                          splitErrorText = null;
                        } else {
                          splitWith.remove(id);
                        }
                      }),
                    ),
                  ),
                  if (splitErrorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          splitErrorText!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amountError = Validators.amount(
                  amountController.text,
                  required: true,
                  maxAmount: 500000,
                );
                if (amountError != null) {
                  setDialogState(() => errorText = amountError);
                  return;
                }
                if (splitWith.isEmpty) {
                  setDialogState(
                    () => splitErrorText =
                        'Select at least one person to split with',
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await _expenseRepository.update(
        itineraryId: widget.savedItineraryId!,
        expenseId: expense.id,
        category: selectedCategory,
        amount: double.parse(amountController.text.trim()),
        splitBetween: splitWith.length == memberIds.length
            ? const []
            : splitWith.toList(),
        note: noteController.text.trim(),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete this expense?',
      message:
          '"${expense.category} — ₱${expense.amount.toStringAsFixed(0)}" will be removed.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    try {
      await _expenseRepository.delete(
        itineraryId: widget.savedItineraryId!,
        expenseId: expense.id,
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Future<void> _togglePackingItem(PackingItem item) async {
    final trip = _savedItinerary;
    if (trip == null) return;
    final newChecked = !item.checked;
    final updated = trip.packingItems
        .map((p) => p.id == item.id ? p.copyWith(checked: newChecked) : p)
        .toList();
    setState(() => _savedItinerary = trip.copyWith(packingItems: updated));
    try {
      await _repository.togglePackingItem(trip.id, item.id, newChecked);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Future<void> _addPackingItem() async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Packing Item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Item',
            prefixIcon: Icon(Symbols.checklist_rounded, size: 20),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (label == null || label.isEmpty || !mounted) return;

    final trip = _savedItinerary;
    if (trip == null) return;
    final newItem = PackingItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      checked: false,
    );
    final updated = [...trip.packingItems, newItem];
    setState(() => _savedItinerary = trip.copyWith(packingItems: updated));
    try {
      await _repository.addPackingItem(trip.id, newItem);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Future<void> _removePackingItem(PackingItem item) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Remove this item?',
      message: '"${item.label}" will be removed from your packing list.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final trip = _savedItinerary;
    if (trip == null) return;
    final updated = trip.packingItems.where((p) => p.id != item.id).toList();
    setState(() => _savedItinerary = trip.copyWith(packingItems: updated));
    try {
      await _repository.removePackingItem(trip.id, item.id);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  /// Whole-document overwrite — the same [_repository.updateItinerary] call
  /// Regenerate already uses, since activities live nested inside
  /// `days[].activities[]`, not a flat id-keyed map the way packingItems
  /// was redesigned to support atomic per-item writes. Never a race-
  /// condition concern in practice: this is gated to the owner alone (see
  /// [_canEditActivities]), so there's no second concurrent editor to
  /// clobber.
  Future<void> _persistDays(List<ItineraryDay> updated) async {
    final savedId = widget.savedItineraryId;
    if (savedId == null) return;
    setState(() => _days = updated);
    try {
      await _repository.updateItinerary(
        savedId,
        title: widget.itinerary.destinationName,
        itinerary: widget.itinerary.copyWith(days: updated),
      );
    } catch (e) {
      if (!mounted) return;
      // The local list already moved on — revert it so the screen matches
      // what's actually saved, rather than showing an edit that silently
      // failed to persist.
      setState(() => _days = widget.itinerary.days);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  /// Same whole-document overwrite + optimistic-then-revert pattern as
  /// [_persistDays] — see that method's doc comment for why a race isn't a
  /// concern here either (owner-only, see [_canEditBudget]).
  Future<void> _persistBudget(
    List<BudgetItem> updatedBreakdown,
    double updatedTotal,
  ) async {
    final savedId = widget.savedItineraryId;
    if (savedId == null) return;
    final previousBreakdown = _budgetBreakdown;
    final previousTotal = _totalBudget;
    setState(() {
      _budgetBreakdown = updatedBreakdown;
      _totalBudget = updatedTotal;
    });
    try {
      await _repository.updateItinerary(
        savedId,
        title: widget.itinerary.destinationName,
        itinerary: widget.itinerary.copyWith(
          budgetBreakdown: updatedBreakdown,
          totalBudget: updatedTotal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _budgetBreakdown = previousBreakdown;
        _totalBudget = previousTotal;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  /// Corrects one AI-estimated [BudgetLineItem]'s price — the category's own
  /// `amount` and the itinerary's `totalBudget` shift by the same delta, so
  /// a correction stays reflected everywhere instead of the line item and
  /// the totals silently disagreeing. Reference equality to find [line]
  /// inside its category is safe here the same way it already is for
  /// [_removeActivity]: the exact in-memory instance rendered is always the
  /// one passed back in.
  Future<void> _editItemPrice(BudgetItem category, BudgetLineItem line) async {
    final priceController = TextEditingController(
      text: line.price.toStringAsFixed(0),
    );
    String? errorText;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit "${line.name}" price'),
          content: TextField(
            controller: priceController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Price (₱)',
              errorText: errorText,
              prefixIcon: const Icon(Symbols.payments_rounded, size: 20),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final error = Validators.amount(
                  priceController.text,
                  required: true,
                  maxAmount: 500000,
                );
                if (error != null) {
                  setDialogState(() => errorText = error);
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final newPrice = double.parse(priceController.text.trim());
    final delta = newPrice - line.price;

    final updatedBreakdown = _budgetBreakdown.map((cat) {
      if (cat.label != category.label) return cat;
      return BudgetItem(
        label: cat.label,
        amount: (cat.amount + delta).clamp(0.0, double.infinity),
        iconKey: cat.iconKey,
        colorKey: cat.colorKey,
        items: cat.items
            .map(
              (i) => i == line
                  ? BudgetLineItem(
                      name: line.name,
                      price: newPrice,
                      place: line.place,
                    )
                  : i,
            )
            .toList(),
      );
    }).toList();
    final updatedTotal = (_totalBudget + delta).clamp(0.0, double.infinity);

    await _persistBudget(updatedBreakdown, updatedTotal);
  }

  /// Removes one AI-estimated [BudgetLineItem] outright (not just its
  /// price) — for a recommendation that never actually applies to this
  /// traveler (e.g. a food item they're skipping). The category's `amount`
  /// and the itinerary's `totalBudget` both drop by the removed line's
  /// price, same delta-adjustment reasoning as [_editItemPrice].
  Future<void> _removeBudgetItem(
    BudgetItem category,
    BudgetLineItem line,
  ) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Remove this item?',
      message:
          '"${line.name}" (~₱${line.price.toStringAsFixed(0)}) will be removed from your budget.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final updatedBreakdown = _budgetBreakdown.map((cat) {
      if (cat.label != category.label) return cat;
      return BudgetItem(
        label: cat.label,
        amount: (cat.amount - line.price).clamp(0.0, double.infinity),
        iconKey: cat.iconKey,
        colorKey: cat.colorKey,
        items: cat.items.where((i) => i != line).toList(),
      );
    }).toList();
    final updatedTotal = (_totalBudget - line.price).clamp(
      0.0,
      double.infinity,
    );

    await _persistBudget(updatedBreakdown, updatedTotal);
  }

  /// A traveler's own line item, for something the AI never estimated at
  /// all — a souvenir they know they'll buy, an extra meal, etc. [place] is
  /// optional and left blank rather than guessed, same "never fabricate a
  /// coordinate" rule the rest of the app already follows — a blank place
  /// just means no "Go here" button shows on this line (see
  /// [_BudgetSummaryCard]'s build method).
  Future<void> _addBudgetItem(BudgetItem category) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final placeController = TextEditingController();
    String? nameError;
    String? priceError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add to "${category.label}"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: 'What is it?',
                  errorText: nameError,
                  prefixIcon: const Icon(
                    Symbols.receipt_long_rounded,
                    size: 20,
                  ),
                ),
              ),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Price (₱)',
                  errorText: priceError,
                  prefixIcon: const Icon(Symbols.payments_rounded, size: 20),
                ),
              ),
              TextField(
                controller: placeController,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Place (optional)',
                  prefixIcon: Icon(Symbols.location_on_rounded, size: 20),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final nameErr = nameController.text.trim().isEmpty
                    ? 'Enter what this is for.'
                    : null;
                final priceErr = Validators.amount(
                  priceController.text,
                  required: true,
                  maxAmount: 500000,
                );
                if (nameErr != null || priceErr != null) {
                  setDialogState(() {
                    nameError = nameErr;
                    priceError = priceErr;
                  });
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final newLine = BudgetLineItem(
      name: nameController.text.trim(),
      price: double.parse(priceController.text.trim()),
      place: placeController.text.trim(),
    );

    final updatedBreakdown = _budgetBreakdown.map((cat) {
      if (cat.label != category.label) return cat;
      return BudgetItem(
        label: cat.label,
        amount: cat.amount + newLine.price,
        iconKey: cat.iconKey,
        colorKey: cat.colorKey,
        items: [...cat.items, newLine],
      );
    }).toList();
    final updatedTotal = _totalBudget + newLine.price;

    await _persistBudget(updatedBreakdown, updatedTotal);
  }

  Future<void> _addActivity(int dayNumber) async {
    final result = await showDialog<ItineraryActivity>(
      context: context,
      builder: (context) => _AddActivityDialog(
        anchorLatitude: widget.itinerary.destinationLatitude,
        anchorLongitude: widget.itinerary.destinationLongitude,
        anchorLabel: widget.itinerary.destinationName,
      ),
    );
    if (result == null || !mounted) return;
    final updated = _days
        .map(
          (d) => d.dayNumber == dayNumber
              ? ItineraryDay(
                  dayNumber: d.dayNumber,
                  dateLabel: d.dateLabel,
                  activities: [...d.activities, result],
                )
              : d,
        )
        .toList();
    await _persistDays(updated);
  }

  /// Edits an existing activity in place — same dialog [_addActivity] uses,
  /// pre-filled via [_AddActivityDialog.existing]. Reference equality to
  /// find [activity] inside its day is safe the same way it already is for
  /// [_removeActivity]: the exact in-memory instance rendered is always the
  /// one passed back in.
  Future<void> _editActivity(int dayNumber, ItineraryActivity activity) async {
    final result = await showDialog<ItineraryActivity>(
      context: context,
      builder: (context) => _AddActivityDialog(
        anchorLatitude: widget.itinerary.destinationLatitude,
        anchorLongitude: widget.itinerary.destinationLongitude,
        anchorLabel: widget.itinerary.destinationName,
        existing: activity,
      ),
    );
    if (result == null || !mounted) return;
    final updated = _days
        .map(
          (d) => d.dayNumber == dayNumber
              ? ItineraryDay(
                  dayNumber: d.dayNumber,
                  dateLabel: d.dateLabel,
                  activities: d.activities
                      .map((a) => a == activity ? result : a)
                      .toList(),
                )
              : d,
        )
        .toList();
    await _persistDays(updated);
  }

  /// AI-picks one fresh replacement for [activity]'s own time slot only —
  /// see [AiRepository.regenerateActivity]. Scoped to just this activity
  /// (unlike [_regenerate], which redoes the whole trip) so a traveler who
  /// only dislikes their Morning pick doesn't have to lose everything else
  /// they've already got. [_regeneratingActivity] drives just this one
  /// [_TimelineActivity]'s spinner, not a screen-wide busy state.
  Future<void> _regenerateActivity(
    int dayNumber,
    ItineraryActivity activity,
  ) async {
    final day = _days.firstWhere((d) => d.dayNumber == dayNumber);
    setState(() => _regeneratingActivity = activity);
    try {
      final result = await AiRepository().regenerateActivity(
        destinationName: widget.itinerary.destinationName,
        time: activity.time,
        otherActivityTitles: day.activities
            .where((a) => a != activity)
            .map((a) => a.title)
            .toList(),
        fallbackLatitude: widget.itinerary.destinationLatitude,
        fallbackLongitude: widget.itinerary.destinationLongitude,
      );
      if (!mounted) return;
      final updated = _days
          .map(
            (d) => d.dayNumber == dayNumber
                ? ItineraryDay(
                    dayNumber: d.dayNumber,
                    dateLabel: d.dateLabel,
                    activities: d.activities
                        .map((a) => a == activity ? result : a)
                        .toList(),
                  )
                : d,
          )
          .toList();
      await _persistDays(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
      }
    } finally {
      if (mounted) setState(() => _regeneratingActivity = null);
    }
  }

  Future<void> _removeActivity(
    int dayNumber,
    ItineraryActivity activity,
  ) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Remove this activity?',
      message: '"${activity.title}" will be removed from Day $dayNumber.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final updated = _days
        .map(
          (d) => d.dayNumber == dayNumber
              ? ItineraryDay(
                  dayNumber: d.dayNumber,
                  dateLabel: d.dateLabel,
                  activities: d.activities.where((a) => a != activity).toList(),
                )
              : d,
        )
        .toList();
    await _persistDays(updated);
  }

  /// Reorders [activity] against its neighbor [delta] positions away *within
  /// the same time slot* — the Morning → Afternoon → Evening sequence itself
  /// is fixed and never changes (see [sortActivitiesByTimeSlot]); this only
  /// ever matters when two or more activities share one slot (e.g. two
  /// "Evening" stops) and the traveler wants to swap which one comes first.
  /// A no-op if there's no same-slot neighbor in that direction — including
  /// the ordinary case of exactly one activity per slot, where there's
  /// nothing to reorder.
  Future<void> _reorderWithinSlot(
    int dayNumber,
    ItineraryActivity activity,
    int delta,
  ) async {
    final updated = _days.map((d) {
      if (d.dayNumber != dayNumber) return d;
      final sorted = sortActivitiesByTimeSlot(d.activities);
      final displayIndex = sorted.indexOf(activity);
      final otherDisplayIndex = displayIndex + delta;
      if (otherDisplayIndex < 0 || otherDisplayIndex >= sorted.length) {
        return d;
      }
      final other = sorted[otherDisplayIndex];
      if (other.time != activity.time) return d;

      final activities = [...d.activities];
      final i = activities.indexOf(activity);
      final j = activities.indexOf(other);
      activities[i] = other;
      activities[j] = activity;
      return ItineraryDay(
        dayNumber: d.dayNumber,
        dateLabel: d.dateLabel,
        activities: activities,
      );
    }).toList();
    await _persistDays(updated);
  }

  Future<void> _inviteCompanions() async {
    await Share.share(
      'Join my "${widget.itinerary.destinationName}" trip on TripNest PH! Open the app, go to Saved Trips → Join a Trip, and enter this code:\n\n${widget.savedItineraryId}',
      subject: 'Join my trip on TripNest PH',
      sharePositionOrigin: _sharePositionOrigin(),
    );
  }

  Future<void> _leaveTrip() async {
    final uid = _uid;
    final trip = _savedItinerary;
    if (uid == null || trip == null) return;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Leave this trip?',
      message:
          'You\'ll lose access to "${trip.title}" unless someone invites you again.',
      confirmLabel: 'Leave',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await _repository.leaveTrip(itineraryId: trip.id, userId: uid);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itinerary = widget.itinerary;
    final restaurants = _recommendedRestaurants;

    return PopScope(
      canPop: _isSaved || _readyToPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleUnsavedPopAttempt();
      },
      child: Scaffold(
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 220,
                    backgroundColor: theme.colorScheme.surface,
                    surfaceTintColor: Colors.transparent,
                    leading: Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.md),
                      child: _CircleButton(
                        icon: Symbols.arrow_back_rounded,
                        onTap: () => context.pop(),
                      ),
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.md),
                        child: _CircleButton(
                          icon: Symbols.emergency_rounded,
                          onTap: _showEmergency,
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          // A whole-province manual/AI itinerary has no
                          // cover photo when that province's own
                          // heroImageUrl hasn't been set yet — falls back
                          // to a plain tint instead of CachedNetworkImage
                          // throwing "No host specified in URI" on an
                          // empty URL.
                          if (itinerary.coverImageUrl.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: itinerary.coverImageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  const ImageErrorPlaceholder(),
                            )
                          else
                            Container(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              child: const Center(
                                child: Icon(
                                  Symbols.map_rounded,
                                  size: 48,
                                  color: AppColors.textOnDark,
                                ),
                              ),
                            ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: AppColors.imageScrim,
                              ),
                            ),
                          ),
                          Positioned(
                            left: AppSpacing.lg,
                            right: AppSpacing.lg,
                            bottom: AppSpacing.lg,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Itinerary',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                                Text(
                                  itinerary.destinationName,
                                  style: theme.textTheme.headlineLarge
                                      ?.copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${itinerary.totalDays} days · ${itinerary.travelers} travelers',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                if (itinerary.accommodationName.isNotEmpty)
                                  Text(
                                    'Optimized for your stay near ${itinerary.accommodationName}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ActionButtonGrid(
                            buttons: [
                              _ActionButton(
                                icon: _isSaved
                                    ? Symbols.bookmark_rounded
                                    : Symbols.bookmark_add_rounded,
                                label: widget.savedItineraryId != null
                                    ? 'Remove'
                                    : 'Save',
                                busy: _busy,
                                onTap: _toggleSave,
                              ),
                              _ActionButton(
                                icon: Symbols.ios_share_rounded,
                                label: 'Share',
                                onTap: _share,
                              ),
                              _ActionButton(
                                icon: Symbols.download_rounded,
                                label: 'Download',
                                busy: _exportingPdf,
                                onTap: _downloadPdf,
                              ),
                              if (_isSaved) ...[
                                _ActionButton(
                                  icon: Symbols.notifications_active_rounded,
                                  label: 'Remind',
                                  onTap: _setReminder,
                                ),
                                _ActionButton(
                                  icon: _isAvailableOffline
                                      ? Symbols.offline_pin_rounded
                                      : Symbols.download_for_offline_rounded,
                                  label: _isAvailableOffline
                                      ? 'Downloaded'
                                      : 'Offline',
                                  busy: _offlineBusy,
                                  onTap: _saveOffline,
                                ),
                              ],
                              // Doesn't make sense without an underlying AI
                              // generation to redo.
                              if (!itinerary.isManuallyCreated)
                                _ActionButton(
                                  icon: Symbols.refresh_rounded,
                                  label: 'Regenerate',
                                  busy: _regenerating,
                                  onTap: _regenerate,
                                ),
                            ],
                          ),
                          if (widget.savedItineraryId != null) ...[
                            const SizedBox(height: AppSpacing.lg),
                            _TripDatesCard(
                              trip: _savedItinerary,
                              isOwner: _isOwner,
                              onTap: _isOwner ? _editStartDate : null,
                              onToggleCompleted: _isOwner
                                  ? _toggleCompleted
                                  : null,
                              totalDays: itinerary.totalDays,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                // Tabs only make sense once the trip is saved — Budget
                // Tracker/Packing/Group all need widget.savedItineraryId,
                // and an unsaved preview's remaining content (Weather +
                // Day-by-Day + recommendations + AI Budget Summary) is
                // short enough on its own that paging it behind tabs would
                // just be an extra tap for no real benefit.
                body: widget.savedItineraryId == null
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.huge,
                        ),
                        children: _buildItineraryTabContent(
                          theme,
                          itinerary,
                          restaurants,
                        ),
                      )
                    : Column(
                        children: [
                          TabBar(
                            controller: _tabController,
                            tabs: const [
                              Tab(
                                icon: Icon(Symbols.map_rounded),
                                text: 'Itinerary',
                              ),
                              Tab(
                                icon: Icon(Symbols.payments_rounded),
                                text: 'Budget',
                              ),
                              Tab(
                                icon: Icon(Symbols.checklist_rounded),
                                text: 'Packing',
                              ),
                              Tab(
                                icon: Icon(Symbols.groups_rounded),
                                text: 'Group',
                              ),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg,
                                    AppSpacing.md,
                                    AppSpacing.lg,
                                    AppSpacing.huge,
                                  ),
                                  children: _buildItineraryTabContent(
                                    theme,
                                    itinerary,
                                    restaurants,
                                  ),
                                ),
                                ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg,
                                    AppSpacing.md,
                                    AppSpacing.lg,
                                    AppSpacing.huge,
                                  ),
                                  children: _buildBudgetTabContent(
                                    theme,
                                    itinerary,
                                    restaurants,
                                  ),
                                ),
                                ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg,
                                    AppSpacing.md,
                                    AppSpacing.lg,
                                    AppSpacing.huge,
                                  ),
                                  children: _buildPackingTabContent(theme),
                                ),
                                ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg,
                                    AppSpacing.md,
                                    AppSpacing.lg,
                                    AppSpacing.huge,
                                  ),
                                  children: _buildGroupTabContent(theme),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Weather, Day-by-Day, restaurant/attraction recommendations, the AI
  /// Budget Summary estimate, Travel Tips, Getting Around — every section
  /// that doesn't need [widget.savedItineraryId]. Shared by the unsaved
  /// preview's single scroll and the saved trip's "Itinerary" tab, since
  /// it's the exact same content either way.
  List<Widget> _buildItineraryTabContent(
    ThemeData theme,
    Itinerary itinerary,
    List<Restaurant> restaurants,
  ) {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text('Weather Outlook', style: theme.textTheme.titleLarge),
          ),
          if (_weatherFetchedAt != null)
            Text(
              'Updated ${DateFormat.jm().format(_weatherFetchedAt!)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      _weather.isEmpty
          ? Text(
              'No forecast available for these dates yet — check back closer to your trip.',
              style: theme.textTheme.bodySmall,
            )
          : Row(
              children: _weather
                  .map(
                    (w) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: _WeatherTile(forecast: w),
                      ),
                    ),
                  )
                  .toList(),
            ),
      const SizedBox(height: AppSpacing.xxl),
      Row(
        children: [
          Expanded(
            child: Text('Day-by-Day Plan', style: theme.textTheme.titleLarge),
          ),
          _editToggleButton(),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      if (_days.isNotEmpty) ...[
        // Clamped rather than trusted as-is — a regenerate/refine can
        // shrink _days out from under whatever day was last selected.
        () {
          final index = _selectedDayIndex.clamp(0, _days.length - 1);
          final day = _days[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_days.length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: index > 0
                          ? () => setState(() => _selectedDayIndex = index - 1)
                          : null,
                      icon: const Icon(Symbols.arrow_back_ios_new_rounded),
                    ),
                    Text(
                      'Day ${index + 1} of ${_days.length}',
                      style: theme.textTheme.labelLarge,
                    ),
                    IconButton(
                      onPressed: index < _days.length - 1
                          ? () => setState(() => _selectedDayIndex = index + 1)
                          : null,
                      icon: const Icon(Symbols.arrow_forward_ios_rounded),
                    ),
                  ],
                ),
              _DayCard(
                day: day,
                date: _savedItinerary?.dateForDay(day.dayNumber),
                restaurants: restaurants,
                placeRecommendations: [
                  ...itinerary.recommendedAccommodations,
                  ...itinerary.recommendedPlaceAttractions,
                ],
                mainDestinationId: itinerary.destinationId,
                mainDestinationName: itinerary.destinationName,
                mainDestinationLatitude: itinerary.destinationLatitude,
                mainDestinationLongitude: itinerary.destinationLongitude,
                onAddActivity: _showActivityEditControls
                    ? () => _addActivity(day.dayNumber)
                    : null,
                onRemoveActivity: _showActivityEditControls
                    ? (activity) => _removeActivity(day.dayNumber, activity)
                    : null,
                onMoveActivity: _showActivityEditControls
                    ? (activity, delta) =>
                          _reorderWithinSlot(day.dayNumber, activity, delta)
                    : null,
                onEditActivity: _showActivityEditControls
                    ? (activity) => _editActivity(day.dayNumber, activity)
                    : null,
                onRegenerateActivity: _showActivityEditControls
                    ? (activity) => _regenerateActivity(day.dayNumber, activity)
                    : null,
                regeneratingActivity: _regeneratingActivity,
              ),
            ],
          );
        }(),
      ],
      if (restaurants.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(
          title: 'Recommended Restaurants',
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: restaurants.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) => RestaurantCard(
              restaurant: restaurants[i],
              onTap: () =>
                  context.push(RoutePaths.restaurantDetails(restaurants[i].id)),
            ),
          ),
        ),
      ],
      if (itinerary.recommendedAccommodations.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(
          title: 'Recommended Accommodations',
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: itinerary.recommendedAccommodations.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) => _PlaceRecommendationCard(
              place: itinerary.recommendedAccommodations[i],
            ),
          ),
        ),
      ],
      if (itinerary.recommendedPlaceAttractions.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(
          title: 'Nearby Attractions',
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: itinerary.recommendedPlaceAttractions.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) => _PlaceRecommendationCard(
              place: itinerary.recommendedPlaceAttractions[i],
              fallbackIcon: Symbols.landscape_rounded,
            ),
          ),
        ),
      ],
      // A manual trip is entirely the traveler's own numbers with nothing
      // for an AI estimate to correct — Budget tab's real Budget Tracker
      // still applies regardless. Shown here only for an unsaved preview,
      // which has no Budget tab of its own to hold it instead — once
      // saved, this same card lives at the top of _buildBudgetTabContent.
      if (!itinerary.isManuallyCreated && widget.savedItineraryId == null) ...[
        const SizedBox(height: AppSpacing.xxl),
        Text('Budget Summary', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        _BudgetSummaryCard(
          itinerary: itinerary.copyWith(
            budgetBreakdown: _budgetBreakdown,
            totalBudget: _totalBudget,
          ),
          onTapItem: (item) => _openBudgetItemPlace(item, restaurants),
          onEditItem: _showBudgetEditControls
              ? (category, item) => _editItemPrice(category, item)
              : null,
          onDeleteItem: _showBudgetEditControls
              ? (category, item) => _removeBudgetItem(category, item)
              : null,
          onAddItem: _showBudgetEditControls
              ? (category) => _addBudgetItem(category)
              : null,
        ),
      ],
      // Never populated for a manually-built trip — no AI generation to
      // have sourced tips from.
      if (!itinerary.isManuallyCreated) ...[
        const SizedBox(height: AppSpacing.xl),
        Text('Travel Tips', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            children: itinerary.travelTips
                .map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Symbols.eco_rounded,
                          size: 18,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(tip, style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
      if (_emergencyProvince != null &&
          _emergencyProvince!.localTransport.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.xl),
        Text('Getting Around', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Column(
          children: [
            for (final note in _emergencyProvince!.localTransport) ...[
              _TransportNoteTile(note: note),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ],
    ];
  }

  /// Budget Tracker — real logged expenses, chart, split summary, which
  /// requires [widget.savedItineraryId] outright (this tab only ever
  /// renders once that's set) — followed by the AI's own
  /// [_BudgetSummaryCard] estimate (once saved — an unsaved preview shows
  /// it inline on the Itinerary tab instead, see
  /// [_buildItineraryTabContent], since it has no Budget tab to hold it).
  /// Tracker leads since it's the traveler's actual spending, the thing
  /// they're more likely checking this tab for; the AI estimate is a
  /// secondary reference underneath it.
  List<Widget> _buildBudgetTabContent(
    ThemeData theme,
    Itinerary itinerary,
    List<Restaurant> restaurants,
  ) {
    return [
      Row(
        children: [
          Expanded(
            child: Text('Budget Tracker', style: theme.textTheme.titleLarge),
          ),
          if (_isTripMember && _editMode)
            TextButton.icon(
              onPressed: _addExpense,
              icon: const Icon(Symbols.add_rounded, size: 18),
              label: const Text('Add Expense'),
            ),
          _editToggleButton(),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      StreamBuilder<List<Expense>>(
        stream: _expenseRepository.streamForItinerary(widget.savedItineraryId!),
        builder: (context, snapshot) {
          final expenses = snapshot.data ?? const [];
          final memberIds =
              _savedItinerary?.memberIds ??
              (_uid != null ? [_uid!] : const <String>[]);
          final memberNames =
              _savedItinerary?.memberNames ?? const <String, String>{};
          return Column(
            children: [
              _BudgetTrackerCard(
                itinerary: itinerary,
                expenses: expenses,
                allMemberIds: memberIds,
                memberNames: memberNames,
                currentUid: _uid,
                isOwner: _isOwner,
                onDelete: _deleteExpense,
                onEdit: _editExpense,
              ),
              if (expenses.isNotEmpty)
                _ExpenseBreakdownChart(
                  itinerary: itinerary,
                  expenses: expenses,
                ),
              if (memberIds.length > 1 && expenses.isNotEmpty)
                _SplitSummaryCard(
                  memberIds: memberIds,
                  memberNames: memberNames,
                  currentUid: _uid,
                  expenses: expenses,
                ),
            ],
          );
        },
      ),
      // A manual trip is entirely the traveler's own numbers with nothing
      // for an AI estimate to correct.
      if (!itinerary.isManuallyCreated) ...[
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            Expanded(
              child: Text('Budget Summary', style: theme.textTheme.titleLarge),
            ),
            _editToggleButton(),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _BudgetSummaryCard(
          itinerary: itinerary.copyWith(
            budgetBreakdown: _budgetBreakdown,
            totalBudget: _totalBudget,
          ),
          onTapItem: (item) => _openBudgetItemPlace(item, restaurants),
          onEditItem: _showBudgetEditControls
              ? (category, item) => _editItemPrice(category, item)
              : null,
          onDeleteItem: _showBudgetEditControls
              ? (category, item) => _removeBudgetItem(category, item)
              : null,
          onAddItem: _showBudgetEditControls
              ? (category) => _addBudgetItem(category)
              : null,
        ),
      ],
    ];
  }

  /// Packing Checklist — waits on [_savedItinerary] itself (not just
  /// [widget.savedItineraryId]) since the items live on that fetched
  /// document, showing a spinner for the brief window before it arrives
  /// rather than an empty list that would look like "no items yet."
  List<Widget> _buildPackingTabContent(ThemeData theme) {
    if (_savedItinerary == null) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    return [
      Row(
        children: [
          Expanded(
            child: Text('Packing Checklist', style: theme.textTheme.titleLarge),
          ),
          if (_isTripMember && _editMode)
            TextButton.icon(
              onPressed: _addPackingItem,
              icon: const Icon(Symbols.add_rounded, size: 18),
              label: const Text('Add Item'),
            ),
          _editToggleButton(),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      _PackingChecklistCard(
        items: _savedItinerary!.packingItems,
        onToggle: _togglePackingItem,
        onRemove: _isTripMember && _editMode ? _removePackingItem : null,
      ),
    ];
  }

  /// Group Polls + Trip Companions — the trip's collaborative/social
  /// content, grouped together since both are about the group rather than
  /// the trip's plan or budget.
  List<Widget> _buildGroupTabContent(ThemeData theme) {
    return [
      Row(
        children: [
          Expanded(
            child: Text('Group Polls', style: theme.textTheme.titleLarge),
          ),
          if (_isTripMember)
            TextButton.icon(
              onPressed: _createPoll,
              icon: const Icon(Symbols.add_rounded, size: 18),
              label: const Text('New Poll'),
            ),
          _editToggleButton(),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      StreamBuilder<List<Poll>>(
        stream: _pollRepository.streamForItinerary(widget.savedItineraryId!),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              'Couldn\'t load polls for this trip.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            );
          }
          final polls = snapshot.data ?? const [];
          if (polls.isEmpty) {
            return Text(
              _isTripMember
                  ? 'No polls yet — start one to help the group decide something together.'
                  : 'No polls to show.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            );
          }
          return Column(
            children: polls
                .map(
                  (poll) => _PollCard(
                    poll: poll,
                    currentUid: _uid,
                    canDelete: _isOwner || poll.createdBy == _uid,
                    onVote: (optionIndex) => _votePoll(poll, optionIndex),
                    onDelete: () => _deletePoll(poll),
                    onEdit: () => _editPoll(poll),
                  ),
                )
                .toList(),
          );
        },
      ),
      const SizedBox(height: AppSpacing.xxl),
      Text('Trip Companions', style: theme.textTheme.titleLarge),
      const SizedBox(height: AppSpacing.md),
      _CompanionsCard(
        isOwner: _isOwner,
        collaboratorIds: _savedItinerary?.collaboratorIds ?? const [],
        memberNames: _savedItinerary?.memberNames ?? const {},
        onInvite: _inviteCompanions,
        onLeave: _leaveTrip,
      ),
    ];
  }
}

class _TransportNoteTile extends StatelessWidget {
  const _TransportNoteTile({required this.note});

  final TransportNote note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Symbols.directions_bus_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  note.mode,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            note.note,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

/// Lays [buttons] out three per row (rather than one cramped row stretching
/// to fit all of them — up to 6 when the trip is saved) so each keeps
/// comfortable width for its icon + label. An incomplete trailing row (e.g.
/// 4 buttons) keeps its buttons at the same width as a full row instead of
/// stretching to fill the row, via blank spacer cells.
class _ActionButtonGrid extends StatelessWidget {
  const _ActionButtonGrid({required this.buttons});

  final List<Widget> buttons;

  /// 4 or fewer fits on one row; more than that (unsaved trip: Save/Share/
  /// Download/Regenerate, 4 total; saved trip adds Remind/Offline, 6 total)
  /// wraps at 3 per row rather than stretching a single row to fit them all.
  int get _perRow => buttons.length <= 4 ? buttons.length : 3;

  @override
  Widget build(BuildContext context) {
    final perRow = _perRow;
    final rows = <Widget>[];
    for (var i = 0; i < buttons.length; i += perRow) {
      final rowButtons = buttons.skip(i).take(perRow).toList();
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.sm));
      rows.add(
        Row(
          children: [
            for (var j = 0; j < perRow; j++) ...[
              if (j > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: j < rowButtons.length ? rowButtons[j] : const SizedBox(),
              ),
            ],
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collects a manually-added activity — see
/// [_GeneratedItineraryScreenState._addActivity]'s doc comment — or, when
/// [existing] is given, edits one already on the trip (see
/// [_GeneratedItineraryScreenState._editActivity]), pre-filled with its
/// current time/title/description/location. The location is picked on the
/// same map used for the trip's own destination (see
/// [MapDestinationPicker]), anchored to it — an activity should be near the
/// trip, not anywhere in the country — so this activity gets real
/// coordinates and can show up on the day route map, unlike an AI-generated
/// one whose own location text failed to geocode, which really does have no
/// pin.
class _AddActivityDialog extends StatefulWidget {
  const _AddActivityDialog({
    this.anchorLatitude,
    this.anchorLongitude,
    this.anchorLabel,
    this.existing,
  });

  final double? anchorLatitude;
  final double? anchorLongitude;
  final String? anchorLabel;
  final ItineraryActivity? existing;

  @override
  State<_AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<_AddActivityDialog> {
  /// The only three time slots an activity may ever be assigned to — see
  /// [sortActivitiesByTimeSlot]'s doc comment for why free text isn't
  /// offered here any more: a stray custom label would sort after all
  /// three and break the fixed Morning → Afternoon → Evening sequence.
  static const List<String> _timeSlots = ['Morning', 'Afternoon', 'Evening'];

  /// Defaults to Morning for a genuinely new activity, or [_timeSlots]'s
  /// first entry for an [_AddActivityDialogState.widget]'s existing]
  /// activity saved before this restriction existed with some other
  /// free-text time — never left on a value this dropdown can't show.
  late String _selectedTime = _timeSlots.contains(widget.existing?.time)
      ? widget.existing!.time
      : _timeSlots.first;
  late final _titleController = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late MapPickedLocation? _location =
      widget.existing?.latitude != null && widget.existing?.longitude != null
      ? MapPickedLocation(
          name: widget.existing!.location,
          latitude: widget.existing!.latitude!,
          longitude: widget.existing!.longitude!,
        )
      : null;

  bool get _isValid => _titleController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.of(context).push<MapPickedLocation>(
      MaterialPageRoute(
        builder: (context) => MapDestinationPicker(
          title: 'Pin Activity Location',
          anchorLatitude: widget.anchorLatitude,
          anchorLongitude: widget.anchorLongitude,
          anchorLabel: widget.anchorLabel,
        ),
      ),
    );
    if (picked != null) setState(() => _location = picked);
  }

  void _submit() {
    if (!_isValid) return;
    final location = _location;
    Navigator.of(context).pop(
      ItineraryActivity(
        time: _selectedTime,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        // Kept as-is on edit — the icon was either AI-picked or already
        // defaulted at add time, and this dialog has no icon picker of its
        // own to let the traveler deliberately change it.
        iconKey: widget.existing?.iconKey ?? 'landscape',
        location: location?.name ?? '',
        latitude: location?.latitude,
        longitude: location?.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = _location;
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Activity' : 'Edit Activity'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedTime,
              decoration: const InputDecoration(labelText: 'Time'),
              items: _timeSlots
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedTime = value);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: _pickLocation,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Symbols.map_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        location?.name ?? 'Location (optional) — pin on map',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: location == null
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(
                      Symbols.chevron_right_rounded,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isValid ? _submit : null,
          child: Text(widget.existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

class _PlaceRecommendationCard extends StatelessWidget {
  const _PlaceRecommendationCard({
    required this.place,
    this.fallbackIcon = Symbols.hotel_rounded,
  });

  final PlaceRecommendation place;

  /// Shown in place of a missing photo — lets this same card serve both
  /// "Recommended Accommodations" (hotel icon) and "More to Explore Nearby"
  /// (landmark icon) without duplicating the widget.
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 200,
      child: InkWell(
        onTap: place.mapsUri.isNotEmpty
            ? () => MapsLauncher.openUrl(place.mapsUri)
            : place.hasCoordinates
            ? () => MapsLauncher.openDirections(
                latitude: place.latitude!,
                longitude: place.longitude!,
                label: place.name,
              )
            : () => MapsLauncher.openPlaceSearch('${place.name}, Philippines'),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TravelImageFrame(
              imageUrl: place.photoUrl,
              height: 120,
              emptyIcon: fallbackIcon,
              bottomRight: place.rating != null
                  ? RatingBadge(rating: place.rating!)
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            if (place.websiteUri.isNotEmpty) ...[
              const SizedBox(height: 2),
              InkWell(
                // The business's own real website, straight from Google
                // Places — never an AI-guessed link, same "never fabricate"
                // reasoning as every real-coordinate pin elsewhere in this
                // app. Nested inside the card's own InkWell deliberately:
                // Flutter resolves the tap to whichever InkWell's bounds
                // are hit, so this doesn't fight the outer "open in Maps" tap.
                onTap: () => MapsLauncher.openUrl(place.websiteUri),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.open_in_new_rounded,
                      size: 12,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Visit Website',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeatherTile extends StatelessWidget {
  const _WeatherTile({required this.forecast});

  final WeatherForecast forecast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        gradient: AppColors.gradient(forecast.gradient),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(
            forecast.dayLabel,
            style: theme.textTheme.labelMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Icon(forecast.icon, color: Colors.white, size: 26),
          const SizedBox(height: 6),
          Text(
            '${forecast.highTemp}° / ${forecast.lowTemp}°',
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({
    required this.itinerary,
    this.onTapItem,
    this.onEditItem,
    this.onDeleteItem,
    this.onAddItem,
  });

  final Itinerary itinerary;

  /// Null-safe to call even for a [BudgetLineItem] with no [BudgetLineItem.place]
  /// (an itinerary saved before that field existed) — the row just renders
  /// as plain, non-tappable text in that case (see the build method below).
  final void Function(BudgetLineItem item)? onTapItem;

  /// Null when the current user can't edit this trip's budget (not the
  /// owner, or an unsaved trip) — the edit icon just doesn't render at all
  /// in that case, same "no affordance offered" pattern as every other
  /// owner-only control on this screen.
  final void Function(BudgetItem category, BudgetLineItem item)? onEditItem;

  /// Same gating as [onEditItem] — removes the whole line (not just its
  /// price), for a recommendation that doesn't apply to this traveler at
  /// all (e.g. a food item they're skipping).
  final void Function(BudgetItem category, BudgetLineItem item)? onDeleteItem;

  /// Same gating as [onEditItem] — adds a traveler's own line item to
  /// [category] (something the AI never estimated at all, e.g. a souvenir
  /// they know they'll buy).
  final void Function(BudgetItem category)? onAddItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total Estimated Budget',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                '₱${itinerary.totalBudget.toStringAsFixed(0)}',
                style: theme.textTheme.headlineSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...itinerary.budgetBreakdown.map((item) {
            final percent = item.amount / itinerary.totalBudget;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(item.icon, size: 18, color: item.color),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          item.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        '₱${item.amount.toStringAsFixed(0)}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.outline,
                      color: item.color,
                    ),
                  ),
                  if (item.items.isNotEmpty || onAddItem != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in item.items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    // Plain text throughout — [line.name]
                                    // used to be styled/wrapped like a link
                                    // (blue + underline) even though tapping
                                    // it opened the *place*, not the food
                                    // item itself; that mismatch is what the
                                    // explicit "Go here" button below fixes.
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          line.name,
                                          // Darker/heavier than the "at
                                          // [place]" line below — the two
                                          // used to share the same muted
                                          // grey, making "what this line
                                          // item is" and "where it's from"
                                          // blend together at a glance.
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.onSurface,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        if (line.place.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    'at ${line.place}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: AppColors
                                                              .textTertiary,
                                                        ),
                                                  ),
                                                ),
                                                if (onTapItem != null) ...[
                                                  const SizedBox(width: 6),
                                                  InkWell(
                                                    onTap: () =>
                                                        onTapItem!(line),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          AppRadius.pill,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: theme
                                                            .colorScheme
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              AppRadius.pill,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Symbols
                                                                .location_on_rounded,
                                                            size: 11,
                                                            color: theme
                                                                .colorScheme
                                                                .primary,
                                                          ),
                                                          const SizedBox(
                                                            width: 2,
                                                          ),
                                                          Text(
                                                            'Go here',
                                                            style: theme
                                                                .textTheme
                                                                .labelSmall
                                                                ?.copyWith(
                                                                  color: theme
                                                                      .colorScheme
                                                                      .primary,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '~₱${line.price.toStringAsFixed(0)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                  if (onEditItem != null)
                                    InkWell(
                                      onTap: () => onEditItem!(item, line),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 6),
                                        child: Icon(
                                          Symbols.edit_rounded,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  if (onDeleteItem != null)
                                    InkWell(
                                      onTap: () => onDeleteItem!(item, line),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 6),
                                        child: Icon(
                                          Symbols.delete_outline_rounded,
                                          size: 14,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          if (onAddItem != null)
                            InkWell(
                              onTap: () => onAddItem!(item),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Symbols.add_rounded,
                                      size: 14,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Add item',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Symbols.info_rounded,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  onEditItem != null
                      ? 'Prices are AI-generated estimates, not live quotes — actual costs may vary. Tap the pencil icon to correct any that are off.'
                      : 'Prices are AI-generated estimates, not live quotes — actual costs may vary.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetTrackerCard extends StatelessWidget {
  const _BudgetTrackerCard({
    required this.itinerary,
    required this.expenses,
    required this.allMemberIds,
    required this.memberNames,
    required this.currentUid,
    required this.isOwner,
    required this.onDelete,
    required this.onEdit,
  });

  final Itinerary itinerary;
  final List<Expense> expenses;
  final List<String> allMemberIds;
  final Map<String, String> memberNames;
  final String? currentUid;

  /// The trip owner can remove any expense; a collaborator can only remove
  /// their own — matches the server-side rule (firestore.rules' `expenses`
  /// match block), so the button offered here never fails a tap with a
  /// permission error the traveler had no way to predict.
  final bool isOwner;
  final ValueChanged<Expense> onDelete;

  /// Narrower than [onDelete]'s gating: only offered for an expense the
  /// viewer logged themselves, even for the trip owner, since
  /// firestore.rules' update rule only lets an edit through when the
  /// resulting doc's `loggedBy` still matches the caller's own uid.
  final ValueChanged<Expense> onEdit;

  String _nameFor(String uid) =>
      uid == currentUid ? 'You' : (memberNames[uid] ?? 'Traveler');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSpent = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final overBudget = totalSpent > itinerary.totalBudget;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Actual Spend', style: theme.textTheme.bodyMedium),
              ),
              Text(
                '₱${totalSpent.toStringAsFixed(0)} / ₱${itinerary.totalBudget.toStringAsFixed(0)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: overBudget
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: itinerary.totalBudget > 0
                  ? (totalSpent / itinerary.totalBudget).clamp(0, 1)
                  : 0,
              minHeight: 8,
              backgroundColor: theme.colorScheme.outline,
              color: overBudget
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
          ),
          if (overBudget) ...[
            const SizedBox(height: 6),
            Text(
              'Over budget by ₱${(totalSpent - itinerary.totalBudget).toStringAsFixed(0)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (expenses.isEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'No expenses logged yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            ...expenses.map(
              (expense) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expense.category,
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (expense.note.isNotEmpty)
                            Text(
                              expense.note,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          if (allMemberIds.length > 1)
                            Builder(
                              builder: (context) {
                                final split = effectiveSplit(
                                  expense,
                                  allMemberIds,
                                );
                                final splitLabel =
                                    split.length == allMemberIds.length
                                    ? 'split equally'
                                    : 'split with ${split.map(_nameFor).join(', ')}';
                                return Text(
                                  'Paid by ${_nameFor(expense.loggedBy)} · $splitLabel',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '₱${expense.amount.toStringAsFixed(0)}',
                      style: theme.textTheme.labelMedium,
                    ),
                    if (expense.loggedBy == currentUid)
                      IconButton(
                        icon: Icon(
                          Symbols.edit_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => onEdit(expense),
                      ),
                    if (isOwner || expense.loggedBy == currentUid)
                      IconButton(
                        icon: Icon(
                          Symbols.close_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => onDelete(expense),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpenseBreakdownChart extends StatelessWidget {
  const _ExpenseBreakdownChart({
    required this.itinerary,
    required this.expenses,
  });

  final Itinerary itinerary;
  final List<Expense> expenses;

  Map<String, double> get _totalsByCategory {
    final totals = <String, double>{};
    for (final expense in expenses) {
      totals.update(
        expense.category,
        (v) => v + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    return totals;
  }

  Color _colorFor(String category, Color fallback) {
    final match = itinerary.budgetBreakdown.where((b) => b.label == category);
    return match.isEmpty ? fallback : match.first.color;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _totalsByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spend by Category', style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: PieChart(
                  PieChartData(
                    sections: [
                      for (final entry in entries)
                        PieChartSectionData(
                          value: entry.value,
                          color: _colorFor(
                            entry.key,
                            theme.colorScheme.onSurfaceVariant,
                          ),
                          radius: 22,
                          showTitle: false,
                        ),
                    ],
                    sectionsSpace: 2,
                    centerSpaceRadius: 28,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _colorFor(
                                  entry.key,
                                  theme.colorScheme.onSurfaceVariant,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                entry.key,
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '₱${entry.value.toStringAsFixed(0)}',
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SplitSummaryCard extends StatelessWidget {
  const _SplitSummaryCard({
    required this.memberIds,
    required this.memberNames,
    required this.currentUid,
    required this.expenses,
  });

  final List<String> memberIds;
  final Map<String, String> memberNames;
  final String? currentUid;
  final List<Expense> expenses;

  String _nameFor(String uid) =>
      uid == currentUid ? 'You' : (memberNames[uid] ?? 'Traveler');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balances = netBalances(memberIds, expenses);

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Who Owes What', style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          ...memberIds.map((id) {
            final net = balances[id] ?? 0;
            final settled = net.abs() < 1;
            final label = settled
                ? 'Settled up'
                : net > 0
                ? 'Gets back ₱${net.toStringAsFixed(0)}'
                : 'Owes ₱${(-net).toStringAsFixed(0)}';
            final color = settled
                ? theme.colorScheme.onSurfaceVariant
                : (net > 0 ? AppColors.success : theme.colorScheme.error);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _nameFor(id),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(color: color),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PackingChecklistCard extends StatelessWidget {
  const _PackingChecklistCard({
    required this.items,
    required this.onToggle,
    this.onRemove,
  });

  final List<PackingItem> items;
  final ValueChanged<PackingItem> onToggle;

  /// Null hides the remove "X" on every item — same "off until Edit mode"
  /// pattern the Day-by-Day and Budget Summary sections use (see
  /// [_GeneratedItineraryScreenState._editMode]), so checking items off the
  /// list is a clean tap with nothing else to accidentally hit until the
  /// traveler deliberately taps "Edit".
  final ValueChanged<PackingItem>? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
        horizontal: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'No items yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              children: items
                  .map(
                    (item) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: item.checked,
                      onChanged: (_) => onToggle(item),
                      title: Text(
                        item.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          decoration: item.checked
                              ? TextDecoration.lineThrough
                              : null,
                          color: item.checked
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      secondary: onRemove == null
                          ? null
                          : IconButton(
                              icon: Icon(
                                Symbols.close_rounded,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () => onRemove!(item),
                            ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _PollCard extends StatelessWidget {
  const _PollCard({
    required this.poll,
    required this.currentUid,
    required this.canDelete,
    required this.onVote,
    required this.onDelete,
    required this.onEdit,
  });

  final Poll poll;
  final String? currentUid;

  /// The poll's creator can remove it; a collaborator can only remove one
  /// they created — matches the server-side rule (firestore.rules' `polls`
  /// match block), same reasoning as `_BudgetTrackerCard`'s delete gating.
  /// Editing the question/options follows this same rule, so [onEdit] is
  /// offered under the same condition.
  final bool canDelete;
  final void Function(int optionIndex) onVote;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myVote = currentUid != null ? poll.votes[currentUid] : null;
    final counts = poll.voteCounts;
    final total = poll.totalVotes;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Symbols.how_to_vote_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(poll.question, style: theme.textTheme.titleSmall),
              ),
              if (canDelete) ...[
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Symbols.edit_rounded, size: 18),
                  ),
                ),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Symbols.close_rounded, size: 18),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < poll.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _PollOptionBar(
                label: poll.options[i],
                count: counts[i],
                total: total,
                selected: myVote == i,
                onTap: () => onVote(i),
              ),
            ),
          Text(
            total == 0 ? 'No votes yet' : '$total vote${total == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One tappable option row — a fill bar behind the label shows the current
/// share of votes, and the currently-selected option (if [currentUid] has
/// voted) gets a primary-tinted border so a re-vote is a visibly deliberate
/// change, not an accidental duplicate tap.
class _PollOptionBar extends StatelessWidget {
  const _PollOptionBar({
    required this.label,
    required this.count,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = total == 0 ? 0.0 : count / total;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (selected)
                  Icon(
                    Symbols.check_circle_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                if (selected) const SizedBox(width: 4),
                Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
                Text(
                  count == 0 ? '' : '$count',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 5,
                backgroundColor: theme.colorScheme.outline,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanionsCard extends StatelessWidget {
  const _CompanionsCard({
    required this.isOwner,
    required this.collaboratorIds,
    required this.memberNames,
    required this.onInvite,
    required this.onLeave,
  });

  final bool isOwner;
  final List<String> collaboratorIds;
  final Map<String, String> memberNames;
  final VoidCallback onInvite;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = collaboratorIds
        .map((id) => memberNames[id] ?? 'Traveler')
        .join(', ');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Icon(Symbols.group_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              collaboratorIds.isEmpty ? 'Just you so far' : names,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isOwner)
            TextButton.icon(
              onPressed: onInvite,
              icon: const Icon(Symbols.person_add_rounded, size: 18),
              label: const Text('Invite'),
            )
          else
            TextButton.icon(
              onPressed: onLeave,
              icon: Icon(
                Symbols.logout_rounded,
                size: 18,
                color: theme.colorScheme.error,
              ),
              label: Text(
                'Leave',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _TripDatesCard extends StatelessWidget {
  const _TripDatesCard({
    required this.trip,
    required this.isOwner,
    required this.onTap,
    required this.onToggleCompleted,
    required this.totalDays,
  });

  final SavedItinerary? trip;
  final bool isOwner;
  final VoidCallback? onTap;

  /// [Itinerary.totalDays] — the Weather Outlook's forecast window is the
  /// trip's whole span, not just its start date (see
  /// [_GeneratedItineraryScreenState._refreshWeatherForDate]), so the latest
  /// *startable* date within Open-Meteo's 16-day forecast range is 16 minus
  /// this, not a flat 16 days from today.
  final int totalDays;

  /// Owner-only — null (from a collaborator viewing someone else's trip)
  /// hides this row entirely rather than showing it read-only, since a
  /// self-reported "did the owner actually go" status isn't something a
  /// collaborator needs surfaced to them.
  final VoidCallback? onToggleCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startDate = trip?.startDate;
    final endDate = trip?.endDate;
    final completed = trip?.isCompleted ?? false;
    final label = startDate == null
        ? 'Set your travel dates'
        : (endDate != null && !_isSameDay(startDate, endDate))
        ? '${DateFormat('MMM d').format(startDate)} – ${DateFormat('MMM d, y').format(endDate)}'
        : DateFormat('EEEE, MMM d, y').format(startDate);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: onToggleCompleted != null
                ? const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg),
                  )
                : BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Symbols.calendar_month_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: startDate == null
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (isOwner && onTap != null)
                    Icon(
                      startDate == null
                          ? Symbols.add_rounded
                          : Symbols.edit_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
          // Set here rather than only after the traveler picks an
          // out-of-range date and sees the Weather Outlook's fallback
          // message — telling them up front is more useful than a surprise
          // after the fact. Only shown to the owner, who's the only one who
          // can actually pick a date (see [onTap]). Stated as the actual
          // cutoff date rather than a raw day count — reads as a real
          // forecast-provider limit rather than an arbitrary app rule, and
          // stays correct without the reader doing their own date math.
          if (isOwner && onTap != null && totalDays <= 16)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 24 + AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Choose a date before '
                      '${DateFormat('MMM d, y').format(DateTime.now().add(Duration(days: 16 - totalDays)))} '
                      'to see the live weather forecast.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Shown to a non-owner collaborator too, read-only, once the trip
          // actually is completed — the owner-only toggle affordance is
          // what's gated to [onToggleCompleted], not visibility of the
          // status itself; otherwise a collaborator had no way to tell the
          // owner had already marked the trip done.
          if (onToggleCompleted != null || completed) ...[
            const Divider(height: 1),
            InkWell(
              onTap: onToggleCompleted,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      completed
                          ? Symbols.check_circle_rounded
                          : Symbols.radio_button_unchecked_rounded,
                      size: 20,
                      color: completed
                          ? AppColors.success
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        completed
                            ? (onToggleCompleted != null
                                  ? 'Marked as completed — tap to undo'
                                  : 'Marked as completed')
                            : 'Mark this trip as completed',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: completed
                              ? AppColors.success
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    this.date,
    required this.restaurants,
    this.placeRecommendations = const [],
    this.mainDestinationId,
    this.mainDestinationName,
    this.mainDestinationLatitude,
    this.mainDestinationLongitude,
    this.onAddActivity,
    this.onRemoveActivity,
    this.onMoveActivity,
    this.onEditActivity,
    this.onRegenerateActivity,
    this.regeneratingActivity,
  });

  final ItineraryDay day;

  /// The real calendar date this day falls on, once the trip has a
  /// [SavedItinerary.startDate] set — shown alongside the AI's generic
  /// "Day 1" label rather than replacing it.
  final DateTime? date;

  /// The trip's already-resolved, real-coordinate recommendations — used to
  /// match this day's activities to a real place for [TripRouteMap] (see
  /// `matchDayToRoute`). Never re-fetched here; just what the parent screen
  /// already loaded. Attractions are Google Places-only now — see
  /// [placeRecommendations] — so `matchDayToRoute`'s own `destinations` param
  /// is always passed an empty list from here.
  final List<Restaurant> restaurants;
  final List<PlaceRecommendation> placeRecommendations;

  /// The trip's own destination — see `matchDayToRoute`'s doc comment for
  /// why this is checked separately from [destinations].
  final String? mainDestinationId;
  final String? mainDestinationName;
  final double? mainDestinationLatitude;
  final double? mainDestinationLongitude;

  /// Non-null only when
  /// [_GeneratedItineraryScreenState.canEditActivities] — null hides every
  /// add/remove/reorder affordance on this day, same pattern
  /// [_TimelineActivity]'s own callbacks use.
  final VoidCallback? onAddActivity;
  final ValueChanged<ItineraryActivity>? onRemoveActivity;
  final ValueChanged<ItineraryActivity>? onEditActivity;
  final ValueChanged<ItineraryActivity>? onRegenerateActivity;

  /// Set only while [_GeneratedItineraryScreenState._regenerateActivity] is
  /// in flight — drives that one activity's own spinner (see
  /// [_TimelineActivity.regenerating]), not a day-wide busy state.
  final ItineraryActivity? regeneratingActivity;

  /// `(activity, delta)` — `delta` is `-1`/`1`, see
  /// [_GeneratedItineraryScreenState._reorderWithinSlot]'s doc comment.
  /// Reorders [activity] against its same-time-slot neighbor; never crosses
  /// into a different slot, since Morning → Afternoon → Evening is fixed.
  final void Function(ItineraryActivity activity, int delta)? onMoveActivity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Sorted once, shared by the route line below and the timeline further
    // down — both must agree on "Morning → Afternoon → Evening" as the one
    // true display order, never the day's raw storage order.
    final sortedActivities = sortActivitiesByTimeSlot(day.activities);
    final routeStops = matchDayToRoute(
      ItineraryDay(
        dayNumber: day.dayNumber,
        dateLabel: day.dateLabel,
        activities: sortedActivities,
      ),
      restaurants: restaurants,
      destinations: const [],
      placeRecommendations: placeRecommendations,
      mainDestinationId: mainDestinationId,
      mainDestinationName: mainDestinationName,
      mainDestinationLatitude: mainDestinationLatitude,
      mainDestinationLongitude: mainDestinationLongitude,
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${day.dayNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(day.dateLabel, style: theme.textTheme.titleMedium),
                    if (date != null)
                      Text(
                        DateFormat('EEE, MMM d, y').format(date!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Always Morning → Afternoon → Evening — see [sortedActivities]'s
          // doc comment above.
          ...() {
            final sorted = sortedActivities;
            return List.generate(sorted.length, (i) {
              final activity = sorted[i];
              final isLast = i == sorted.length - 1;
              final prev = i > 0 ? sorted[i - 1] : null;
              final next = i < sorted.length - 1 ? sorted[i + 1] : null;
              return _TimelineActivity(
                activity: activity,
                isLast: isLast,
                onRemove: onRemoveActivity == null
                    ? null
                    : () => onRemoveActivity!(activity),
                // Only enabled when the neighbor shares this exact time
                // slot — reordering never crosses into a different one.
                onMoveUp: onMoveActivity == null || prev?.time != activity.time
                    ? null
                    : () => onMoveActivity!(activity, -1),
                onMoveDown:
                    onMoveActivity == null || next?.time != activity.time
                    ? null
                    : () => onMoveActivity!(activity, 1),
                onEdit: onEditActivity == null
                    ? null
                    : () => onEditActivity!(activity),
                onRegenerate: onRegenerateActivity == null
                    ? null
                    : () => onRegenerateActivity!(activity),
                regenerating: regeneratingActivity == activity,
              );
            });
          }(),
          if (onAddActivity != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onAddActivity,
                  icon: const Icon(Symbols.add_rounded, size: 16),
                  label: const Text('Add Activity'),
                ),
              ),
            ),
          if (routeStops.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Day\'s Route', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  TripRouteMap(stops: routeStops),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineActivity extends StatelessWidget {
  const _TimelineActivity({
    required this.activity,
    required this.isLast,
    this.onRemove,
    this.onMoveUp,
    this.onMoveDown,
    this.onEdit,
    this.onRegenerate,
    this.regenerating = false,
  });

  final ItineraryActivity activity;
  final bool isLast;

  /// Non-null only when [_GeneratedItineraryScreenState._canEditActivities]
  /// — null hides the whole trailing action column, same "no callback, no
  /// affordance" pattern the rest of this screen already uses (e.g.
  /// [ChatBubble.onOpenPlanner]). [onMoveUp]/[onMoveDown] are independently
  /// null both at either end of the day's own activity list *and* whenever
  /// the neighbor in that direction is in a different time slot — reordering
  /// never crosses Morning/Afternoon/Evening, see
  /// [_GeneratedItineraryScreenState._reorderWithinSlot]'s doc comment.
  final VoidCallback? onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onEdit;

  /// AI-regenerates just this one activity's time slot — see
  /// [_GeneratedItineraryScreenState._regenerateActivity]. Disabled (shown
  /// as a spinner instead) while [regenerating].
  final VoidCallback? onRegenerate;
  final bool regenerating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  activity.icon,
                  size: 17,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: theme.colorScheme.outline),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          activity.time,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      if (onRemove != null) ...[
                        Tooltip(
                          message: 'Move up within this time slot',
                          child: InkWell(
                            onTap: onMoveUp,
                            child: Icon(
                              Symbols.arrow_upward_rounded,
                              size: 15,
                              color: onMoveUp != null
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Move down within this time slot',
                          child: InkWell(
                            onTap: onMoveDown,
                            child: Icon(
                              Symbols.arrow_downward_rounded,
                              size: 15,
                              color: onMoveDown != null
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        if (onEdit != null) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Edit this activity',
                            child: InkWell(
                              onTap: regenerating ? null : onEdit,
                              child: Icon(
                                Symbols.edit_rounded,
                                size: 15,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                        if (onRegenerate != null) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Get a different pick for this time slot',
                            child: InkWell(
                              onTap: regenerating ? null : onRegenerate,
                              child: regenerating
                                  ? SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.primary,
                                      ),
                                    )
                                  : Icon(
                                      Symbols.refresh_rounded,
                                      size: 15,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Remove this activity',
                          child: InkWell(
                            onTap: regenerating ? null : onRemove,
                            child: Icon(
                              Symbols.close_rounded,
                              size: 15,
                              color: regenerating
                                  ? theme.colorScheme.outlineVariant
                                  : theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(activity.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(activity.description, style: theme.textTheme.bodySmall),
                  if (activity.location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Symbols.location_on_rounded,
                          size: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            activity.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
