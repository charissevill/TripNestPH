import 'package:flutter/foundation.dart';

import '../../core/utils/view_status.dart';
import '../../domain/models/itinerary.dart';
import '../../domain/models/place.dart';
import '../../domain/models/province.dart';
import '../models/itinerary_request.dart';
import '../repositories/ai_repository.dart';
import '../services/openai_service.dart';

/// Drives the AI Planner form's "Generate Itinerary" flow: calls
/// [AiRepository.generateItinerary] and exposes loading/error/result state
/// for [AiPlannerScreen] to render with the existing UI.
class AiPlannerProvider extends ChangeNotifier {
  AiPlannerProvider({AiRepository? repository}) : _repository = repository ?? AiRepository();

  final AiRepository _repository;

  ViewStatus status = ViewStatus.initial;
  String? errorMessage;
  Itinerary? result;

  /// Incremented per call so a superseded request's response is silently
  /// dropped instead of clobbering a newer one (e.g. user hits Regenerate
  /// twice quickly).
  int _requestVersion = 0;

  bool get isGenerating => status == ViewStatus.loading;

  Place? _pendingPlace;
  Province? _pendingProvince;

  /// Set by "Plan a Trip Here" on [PlaceDetailsSheet] right before
  /// navigating to the Planner tab — [RoutePaths.planner] is a `GoRoute`
  /// inside a `StatefulShellBranch`, which doesn't reliably carry a fresh
  /// route `extra` the way a plain pushed route does, so this provider
  /// (already read via `context.read` in `AiPlannerScreen`) is the hand-off
  /// channel instead.
  void setPendingDestination(Place place, Province? province) {
    _pendingPlace = place;
    _pendingProvince = province;
  }

  /// Consumed once by `AiPlannerScreen.initState()` — clearing here means
  /// switching tabs away and back doesn't re-apply a stale pre-fill.
  ({Place place, Province? province})? takePendingDestination() {
    final place = _pendingPlace;
    if (place == null) return null;
    final province = _pendingProvince;
    _pendingPlace = null;
    _pendingProvince = null;
    return (place: place, province: province);
  }

  Future<Itinerary?> generate(
    AiItineraryRequest request, {
    required String coverImageUrl,
    bool forceRefresh = false,
  }) async {
    final version = ++_requestVersion;
    status = ViewStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final itinerary = await _repository.generateItinerary(
        request,
        coverImageUrl: coverImageUrl,
        forceRefresh: forceRefresh,
      );
      if (version != _requestVersion) return null;
      result = itinerary;
      status = ViewStatus.loaded;
      notifyListeners();
      return itinerary;
    } catch (e) {
      if (version != _requestVersion) return null;
      status = ViewStatus.error;
      errorMessage = e is AiException ? e.message : 'Couldn\'t generate your itinerary. Please try again.';
      notifyListeners();
      return null;
    }
  }

  void reset() {
    status = ViewStatus.initial;
    errorMessage = null;
    result = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
