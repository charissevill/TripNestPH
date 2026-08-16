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
import '../../ai/providers/ai_planner_provider.dart';
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

class _GeneratedItineraryScreenState extends State<GeneratedItineraryScreen> {
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

  List<WeatherForecast> get _weather =>
      _weatherOverride ?? widget.itinerary.weather;

  /// Set right before a deliberate pop (after the traveler chooses Save or
  /// Discard in [_handleUnsavedPopAttempt]) so that second, self-triggered
  /// pop attempt isn't intercepted all over again.
  bool _readyToPop = false;

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

  /// A local, editable copy of the budget breakdown/total — same reasoning
  /// as [_days] below, mutated on an item price edit and persisted via
  /// [_persistBudget].
  late List<BudgetItem> _budgetBreakdown = widget.itinerary.budgetBreakdown;
  late double _totalBudget = widget.itinerary.totalBudget;

  /// A local, editable copy of the itinerary's days — [widget.itinerary] is
  /// immutable (it's the value passed in via navigation), so manual activity
  /// edits mutate this instead and persist via [_persistDays].
  late List<ItineraryDay> _days = widget.itinerary.days;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
    unawaited(_resolveProvince());
    if (widget.savedItineraryId != null) {
      _loadSavedItinerary();
      _loadOfflineStatus();
    }
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
            .makeAvailableOffline(context: context, itineraryId: widget.savedItineraryId!, itinerary: widget.itinerary)
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
    setState(() => _savedItinerary = trip.copyWith(startDate: picked));
    try {
      await _repository.updateStartDate(trip.id, picked);
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
    await NotificationService.instance.cancelReminder(_reminderId(isTravelDay: true));
    await NotificationService.instance.cancelReminder(_reminderId(isTravelDay: false));
    await _refreshWeatherForDate(picked);
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
    if (mounted) setState(() => _weatherOverride = forTrip);
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
    final placeMatch = [
      ...widget.itinerary.recommendedPlaceAttractions,
      ...widget.itinerary.recommendedAccommodations,
    ].where((p) => p.name.toLowerCase() == line.place.toLowerCase()).firstOrNull;
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

  /// Asks for a specific change (e.g. "make day 2 cheaper", "swap the beach
  /// activity for a hike"), then regenerates with that instruction applied —
  /// see [AiItineraryRequest.refinementInstruction]'s doc comment. Declines
  /// to even try on an empty/whitespace-only answer rather than silently
  /// falling back to a plain regenerate the traveler didn't ask for.
  Future<void> _refine() async {
    final instruction = await showDialog<String>(
      context: context,
      builder: (context) => const _RefineInstructionDialog(),
    );
    if (instruction == null || instruction.trim().isEmpty || !mounted) return;
    await _regenerateInternal(refinementInstruction: instruction.trim());
  }

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
      final (budgetTierLabel, budgetRange) = _inferBudgetTier(
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
          transportation: const {'Van / Car Rental'},
          interests: const {'Beaches', 'Food'},
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
        // defeating the point of "Regenerate"/"Refine".
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
            message: 'This swaps in the new plan and can\'t be undone. Your current saved itinerary will be gone.',
            confirmLabel: 'Replace',
            isDestructive: true,
          );
          if (!confirmed || !mounted) return;
          // Already saved — overwrite the same trip in place instead of
          // leaving it stale/orphaned while this pushes a second, separate
          // unsaved copy (see updateItinerary's doc comment).
          try {
            await _repository.updateItinerary(savedId, title: itinerary.destinationName, itinerary: itinerary);
          } catch (e) {
            if (!mounted) return;
            _showRegenerateError(AppException.from(e).message);
            return;
          }
        }
        if (!mounted) return;
        context.pushReplacement(
          RoutePaths.generatedItinerary,
          extra: {'itinerary': itinerary, if (savedId != null) 'savedId': savedId},
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

  (String, String) _inferBudgetTier(double totalBudget) {
    if (totalBudget >= 40000) return ('Luxury', '₱40k+');
    if (totalBudget >= 15000) return ('Mid-range', '₱15k – ₱40k');
    return ('Budget', '₱5k – ₱15k');
  }

  Rect? _sharePositionOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _share() async {
    await Share.share(
      ItineraryExport.buildShareText(widget.itinerary),
      subject: '${widget.itinerary.destinationName} itinerary — TripNest PH',
      sharePositionOrigin: _sharePositionOrigin(),
    );
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
                    prefixIcon: const Icon(Symbols.how_to_vote_rounded, size: 20),
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
                                icon: const Icon(Symbols.close_rounded, size: 18),
                                onPressed: () => setDialogState(() {
                                  optionControllers = [...optionControllers]..removeAt(i);
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
                        () => optionControllers = [...optionControllers, TextEditingController()],
                      ),
                      icon: const Icon(Symbols.add_rounded, size: 18),
                      label: const Text('Add option'),
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
                  setDialogState(() => errorText = 'Enter a question');
                  return;
                }
                final filled = optionControllers
                    .map((c) => c.text.trim())
                    .where((t) => t.isNotEmpty)
                    .toList();
                if (filled.length < 2) {
                  setDialogState(() => errorText = null);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Add at least 2 options.')),
                  );
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
  /// Regenerate/Refine already use, since activities live nested inside
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  /// Same whole-document overwrite + optimistic-then-revert pattern as
  /// [_persistDays] — see that method's doc comment for why a race isn't a
  /// concern here either (owner-only, see [_canEditBudget]).
  Future<void> _persistBudget(List<BudgetItem> updatedBreakdown, double updatedTotal) async {
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
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
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
                  ? BudgetLineItem(name: line.name, price: newPrice, place: line.place)
                  : i,
            )
            .toList(),
      );
    }).toList();
    final updatedTotal = (_totalBudget + delta).clamp(0.0, double.infinity);

    await _persistBudget(updatedBreakdown, updatedTotal);
  }

  Future<void> _addActivity(int dayNumber) async {
    final result = await showDialog<ItineraryActivity>(
      context: context,
      builder: (context) => const _AddActivityDialog(),
    );
    if (result == null || !mounted) return;
    final updated = _days
        .map((d) => d.dayNumber == dayNumber ? ItineraryDay(dayNumber: d.dayNumber, dateLabel: d.dateLabel, activities: [...d.activities, result]) : d)
        .toList();
    await _persistDays(updated);
  }

  Future<void> _removeActivity(int dayNumber, ItineraryActivity activity) async {
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
              ? ItineraryDay(dayNumber: d.dayNumber, dateLabel: d.dateLabel, activities: d.activities.where((a) => a != activity).toList())
              : d,
        )
        .toList();
    await _persistDays(updated);
  }

  /// [delta] is `-1` (move earlier) or `1` (move later) — a no-op past
  /// either end of the day's own activity list, never wrapping around or
  /// spilling into a neighboring day.
  Future<void> _moveActivity(int dayNumber, int index, int delta) async {
    final updated = _days.map((d) {
      if (d.dayNumber != dayNumber) return d;
      final newIndex = index + delta;
      if (newIndex < 0 || newIndex >= d.activities.length) return d;
      final activities = [...d.activities];
      final moved = activities.removeAt(index);
      activities.insert(newIndex, moved);
      return ItineraryDay(dayNumber: d.dayNumber, dateLabel: d.dateLabel, activities: activities);
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
              child: CustomScrollView(
                slivers: [
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
                          CachedNetworkImage(
                            imageUrl: itinerary.coverImageUrl,
                            fit: BoxFit.cover,
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
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.huge,
                    ),
                    sliver: SliverList.list(
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
                            _ActionButton(
                              icon: Symbols.refresh_rounded,
                              label: 'Regenerate',
                              busy: _regenerating,
                              onTap: _regenerate,
                            ),
                            _ActionButton(
                              icon: Symbols.auto_awesome_rounded,
                              label: 'Refine',
                              busy: _regenerating,
                              onTap: _refine,
                            ),
                          ],
                        ),
                        if (widget.savedItineraryId != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _TripDatesCard(
                            trip: _savedItinerary,
                            isOwner: _isOwner,
                            onTap: _isOwner ? _editStartDate : null,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          'Weather Outlook',
                          style: theme.textTheme.titleLarge,
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
                                          padding: const EdgeInsets.only(
                                            right: AppSpacing.sm,
                                          ),
                                          child: _WeatherTile(forecast: w),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                        if (itinerary.recommendedAccommodations.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xxl),
                          Text(
                            'Recommended Accommodations',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            height: 210,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount:
                                  itinerary.recommendedAccommodations.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: AppSpacing.md),
                              itemBuilder: (context, i) =>
                                  _PlaceRecommendationCard(
                                    place:
                                        itinerary.recommendedAccommodations[i],
                                  ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          'Budget Summary',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _BudgetSummaryCard(
                          itinerary: itinerary.copyWith(
                            budgetBreakdown: _budgetBreakdown,
                            totalBudget: _totalBudget,
                          ),
                          onTapItem: (item) =>
                              _openBudgetItemPlace(item, restaurants),
                          onEditItem: _canEditBudget
                              ? (category, item) =>
                                    _editItemPrice(category, item)
                              : null,
                        ),
                        if (widget.savedItineraryId != null) ...[
                          const SizedBox(height: AppSpacing.xxl),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Budget Tracker',
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _addExpense,
                                icon: const Icon(Symbols.add_rounded, size: 18),
                                label: const Text('Add Expense'),
                              ),
                            ],
                          ),
                          StreamBuilder<List<Expense>>(
                            stream: _expenseRepository.streamForItinerary(
                              widget.savedItineraryId!,
                            ),
                            builder: (context, snapshot) {
                              final expenses = snapshot.data ?? const [];
                              final memberIds =
                                  _savedItinerary?.memberIds ??
                                  (_uid != null ? [_uid!] : const <String>[]);
                              final memberNames =
                                  _savedItinerary?.memberNames ??
                                  const <String, String>{};
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
                                  ),
                                  if (expenses.isNotEmpty)
                                    _ExpenseBreakdownChart(
                                      itinerary: itinerary,
                                      expenses: expenses,
                                    ),
                                  if (memberIds.length > 1 &&
                                      expenses.isNotEmpty)
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
                        ],
                        if (widget.savedItineraryId != null &&
                            _savedItinerary != null) ...[
                          const SizedBox(height: AppSpacing.xxl),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Packing Checklist',
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _addPackingItem,
                                icon: const Icon(Symbols.add_rounded, size: 18),
                                label: const Text('Add Item'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _PackingChecklistCard(
                            items: _savedItinerary!.packingItems,
                            onToggle: _togglePackingItem,
                            onRemove: _removePackingItem,
                          ),
                        ],
                        if (widget.savedItineraryId != null) ...[
                          const SizedBox(height: AppSpacing.xxl),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Group Polls',
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _createPoll,
                                icon: const Icon(Symbols.add_rounded, size: 18),
                                label: const Text('New Poll'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          StreamBuilder<List<Poll>>(
                            stream: _pollRepository.streamForItinerary(
                              widget.savedItineraryId!,
                            ),
                            builder: (context, snapshot) {
                              final polls = snapshot.data ?? const [];
                              if (polls.isEmpty) {
                                return Text(
                                  'No polls yet — start one to help the group decide something together.',
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
                                        canDelete:
                                            _isOwner || poll.createdBy == _uid,
                                        onVote: (optionIndex) =>
                                            _votePoll(poll, optionIndex),
                                        onDelete: () => _deletePoll(poll),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                        ],
                        if (widget.savedItineraryId != null) ...[
                          const SizedBox(height: AppSpacing.xxl),
                          Text(
                            'Trip Companions',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _CompanionsCard(
                            isOwner: _isOwner,
                            collaboratorIds:
                                _savedItinerary?.collaboratorIds ?? const [],
                            memberNames:
                                _savedItinerary?.memberNames ?? const {},
                            onInvite: _inviteCompanions,
                            onLeave: _leaveTrip,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          'Day-by-Day Plan',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ..._days.map(
                          (day) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.lg,
                            ),
                            child: _DayCard(
                              day: day,
                              date: _savedItinerary?.dateForDay(day.dayNumber),
                              restaurants: restaurants,
                              placeRecommendations: [
                                ...itinerary.recommendedAccommodations,
                                ...itinerary.recommendedPlaceAttractions,
                              ],
                              mainDestinationId: itinerary.destinationId,
                              mainDestinationName: itinerary.destinationName,
                              mainDestinationLatitude:
                                  itinerary.destinationLatitude,
                              mainDestinationLongitude:
                                  itinerary.destinationLongitude,
                              onAddActivity: _canEditActivities ? () => _addActivity(day.dayNumber) : null,
                              onRemoveActivity: _canEditActivities ? (activity) => _removeActivity(day.dayNumber, activity) : null,
                              onMoveActivity: _canEditActivities ? (index, delta) => _moveActivity(day.dayNumber, index, delta) : null,
                            ),
                          ),
                        ),
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
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: AppSpacing.md),
                              itemBuilder: (context, i) => RestaurantCard(
                                restaurant: restaurants[i],
                                onTap: () => context.push(
                                  RoutePaths.restaurantDetails(
                                    restaurants[i].id,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (itinerary
                            .recommendedPlaceAttractions
                            .isNotEmpty) ...[
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
                              itemCount:
                                  itinerary.recommendedPlaceAttractions.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: AppSpacing.md),
                              itemBuilder: (context, i) =>
                                  _PlaceRecommendationCard(
                                    place: itinerary
                                        .recommendedPlaceAttractions[i],
                                    fallbackIcon: Symbols.landscape_rounded,
                                  ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        Text('Travel Tips', style: theme.textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Column(
                            children: itinerary.travelTips
                                .map(
                                  (tip) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Symbols.eco_rounded,
                                          size: 18,
                                          color: theme.colorScheme.secondary,
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Text(
                                            tip,
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        if (_emergencyProvince != null &&
                            _emergencyProvince!.localTransport.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Getting Around',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Column(
                            children: [
                              for (final note
                                  in _emergencyProvince!.localTransport) ...[
                                _TransportNoteTile(note: note),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
  /// Download/Regenerate/Refine, 5 total; saved trip adds Remind/Offline,
  /// 7 total) wraps at 3 per row rather than stretching a single row to fit
  /// them all.
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

/// Asks for a specific change before "Refine with AI" regenerates —
/// see [_GeneratedItineraryScreenState._refine]'s doc comment.
class _RefineInstructionDialog extends StatefulWidget {
  const _RefineInstructionDialog();

  @override
  State<_RefineInstructionDialog> createState() => _RefineInstructionDialogState();
}

class _RefineInstructionDialogState extends State<_RefineInstructionDialog> {
  final _controller = TextEditingController();

  static const List<String> _examples = [
    'Make it cheaper overall',
    'Swap Day 2 for something more relaxed',
    'Add more local food spots',
    'Make it more kid-friendly',
  ];

  bool get _hasInstruction => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Keeps the Refine button's enabled state (and Enter-to-submit) in sync
    // with whether there's actually anything to refine with — otherwise
    // submitting empty text closed the dialog and silently did nothing,
    // with no explanation why "Refine" didn't seem to work.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_hasInstruction) return;
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Refine with AI'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell it what to change — everything else about the plan stays close to what you already have.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(hintText: 'e.g. "Make Day 2 cheaper"'),
            onSubmitted: (_) => _submit(),
          ),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: _examples
                .map(
                  (example) => ActionChip(
                    label: Text(example, style: theme.textTheme.labelSmall),
                    onPressed: () => setState(() => _controller.text = example),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _hasInstruction ? _submit : null,
          child: const Text('Refine'),
        ),
      ],
    );
  }
}

/// Collects a manually-added activity — see
/// [_GeneratedItineraryScreenState._addActivity]'s doc comment. Never
/// geocoded (no [ItineraryActivity.latitude]/`longitude`), same as any
/// activity the AI's own location text failed to resolve — the day route
/// map already handles that gracefully, just without a pin for this one.
class _AddActivityDialog extends StatefulWidget {
  const _AddActivityDialog();

  @override
  State<_AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<_AddActivityDialog> {
  final _timeController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  bool get _isValid => _timeController.text.trim().isNotEmpty && _titleController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    for (final c in [_timeController, _titleController]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _timeController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_isValid) return;
    Navigator.of(context).pop(
      ItineraryActivity(
        time: _timeController.text.trim(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        iconKey: 'landscape',
        location: _locationController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Activity'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _timeController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Time', hintText: 'e.g. "Morning" or "2:00 PM"'),
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
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _isValid ? _submit : null, child: const Text('Add')),
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
  const _BudgetSummaryCard({required this.itinerary, this.onTapItem, this.onEditItem});

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
                  if (item.items.isNotEmpty) ...[
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
                                    child: InkWell(
                                      onTap:
                                          (onTapItem != null &&
                                              line.place.isNotEmpty)
                                          ? () => onTapItem!(line)
                                          : null,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            line.name,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: line.place.isNotEmpty
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                      : AppColors
                                                            .textTertiary,
                                                  decoration:
                                                      line.place.isNotEmpty
                                                      ? TextDecoration
                                                            .underline
                                                      : null,
                                                ),
                                          ),
                                          if (line.place.isNotEmpty)
                                            Text(
                                              'at ${line.place}',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    color: AppColors
                                                        .textTertiary,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '~₱${line.price.toStringAsFixed(0)}',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
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
                                ],
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
    required this.onRemove,
  });

  final List<PackingItem> items;
  final ValueChanged<PackingItem> onToggle;
  final ValueChanged<PackingItem> onRemove;

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
                      secondary: IconButton(
                        icon: Icon(
                          Symbols.close_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => onRemove(item),
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
  });

  final Poll poll;
  final String? currentUid;

  /// The poll's creator can remove it; a collaborator can only remove one
  /// they created — matches the server-side rule (firestore.rules' `polls`
  /// match block), same reasoning as `_BudgetTrackerCard`'s delete gating.
  final bool canDelete;
  final void Function(int optionIndex) onVote;
  final VoidCallback onDelete;

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
              if (canDelete)
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Symbols.close_rounded, size: 18),
                  ),
                ),
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
            color: selected
                ? theme.colorScheme.primary
                : AppColors.border,
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
                Expanded(
                  child: Text(label, style: theme.textTheme.bodyMedium),
                ),
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
  });

  final SavedItinerary? trip;
  final bool isOwner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startDate = trip?.startDate;
    final endDate = trip?.endDate;
    final label = startDate == null
        ? 'Set your travel dates'
        : (endDate != null && !_isSameDay(startDate, endDate))
        ? '${DateFormat('MMM d').format(startDate)} – ${DateFormat('MMM d, y').format(endDate)}'
        : DateFormat('EEEE, MMM d, y').format(startDate);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
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
                startDate == null ? Symbols.add_rounded : Symbols.edit_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
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

  /// `(activityIndex, delta)` — `delta` is `-1`/`1`, see
  /// [_GeneratedItineraryScreenState._moveActivity]'s doc comment.
  final void Function(int index, int delta)? onMoveActivity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routeStops = matchDayToRoute(
      day,
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
          ...List.generate(day.activities.length, (i) {
            final activity = day.activities[i];
            final isLast = i == day.activities.length - 1;
            return _TimelineActivity(
              activity: activity,
              isLast: isLast,
              onRemove: onRemoveActivity == null ? null : () => onRemoveActivity!(activity),
              onMoveUp: onMoveActivity == null || i == 0 ? null : () => onMoveActivity!(i, -1),
              onMoveDown: onMoveActivity == null || i == day.activities.length - 1 ? null : () => onMoveActivity!(i, 1),
            );
          }),
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
  });

  final ItineraryActivity activity;
  final bool isLast;

  /// Non-null only when [_GeneratedItineraryScreenState._canEditActivities]
  /// — null hides the whole trailing action column, same "no callback, no
  /// affordance" pattern the rest of this screen already uses (e.g.
  /// [ChatBubble.onOpenPlanner]). [onMoveUp]/[onMoveDown] are independently
  /// null at either end of the day's own activity list.
  final VoidCallback? onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

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
                        InkWell(
                          onTap: onMoveUp,
                          child: Icon(
                            Symbols.arrow_upward_rounded,
                            size: 15,
                            color: onMoveUp != null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.outlineVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: onMoveDown,
                          child: Icon(
                            Symbols.arrow_downward_rounded,
                            size: 15,
                            color: onMoveDown != null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.outlineVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: onRemove,
                          child: Icon(Symbols.close_rounded, size: 15, color: theme.colorScheme.error),
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
