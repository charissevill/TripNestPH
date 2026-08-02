import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/favorites_repository.dart';
import '../../domain/models/place.dart';

/// Firestore-backed favorites state, exposing the exact same API the Phase 1
/// UI already calls (`isDestinationSaved`, `toggleDestination`, ...) so no
/// screen or card widget needs to change — only where the data comes from.
class FavoritesProvider extends ChangeNotifier {
  FavoritesProvider({FavoritesRepository? repository}) : _repository = repository ?? FavoritesRepository();

  final FavoritesRepository _repository;
  StreamSubscription<Map<FavoriteType, Set<String>>>? _subscription;
  StreamSubscription<List<Place>>? _placesSubscription;

  String? _userId;
  Set<String> _savedDestinationIds = {};
  Set<String> _savedRestaurantIds = {};
  Set<String> _savedFestivalIds = {};

  /// A live Places result is never persisted to Firestore anywhere else, so
  /// unlike the three sets above (each backed by its own collection to
  /// re-resolve an id against), this is the fully-hydrated favorite data
  /// itself — see `FavoritesRepository.streamSavedPlaces`.
  List<Place> _savedPlaces = [];
  Set<String> _savedPlaceIds = {};

  bool isDestinationSaved(String id) => _savedDestinationIds.contains(id);
  bool isRestaurantSaved(String id) => _savedRestaurantIds.contains(id);
  bool isFestivalSaved(String id) => _savedFestivalIds.contains(id);
  bool isPlaceSaved(String id) => _savedPlaceIds.contains(id);

  int get totalSavedCount =>
      _savedDestinationIds.length + _savedRestaurantIds.length + _savedFestivalIds.length + _savedPlaces.length;

  Set<String> get savedDestinationIds => _savedDestinationIds;
  Set<String> get savedRestaurantIds => _savedRestaurantIds;
  Set<String> get savedFestivalIds => _savedFestivalIds;
  List<Place> get savedPlaces => _savedPlaces;

  /// Called whenever the signed-in user changes (including sign-out, where
  /// [userId] is null and every favorite clears from view).
  void bindToUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _subscription?.cancel();
    _placesSubscription?.cancel();
    _savedDestinationIds = {};
    _savedRestaurantIds = {};
    _savedFestivalIds = {};
    _savedPlaces = [];
    _savedPlaceIds = {};
    notifyListeners();

    if (userId == null) return;
    _subscription = _repository.streamFavorites(userId).listen((byType) {
      _savedDestinationIds = byType[FavoriteType.destination] ?? {};
      _savedRestaurantIds = byType[FavoriteType.restaurant] ?? {};
      _savedFestivalIds = byType[FavoriteType.festival] ?? {};
      notifyListeners();
    });
    _placesSubscription = _repository.streamSavedPlaces(userId).listen((places) {
      _savedPlaces = places;
      _savedPlaceIds = places.map((p) => p.id).toSet();
      notifyListeners();
    });
  }

  void toggleDestination(String id) => _toggle(FavoriteType.destination, id, _savedDestinationIds);
  void toggleRestaurant(String id) => _toggle(FavoriteType.restaurant, id, _savedRestaurantIds);
  void toggleFestival(String id) => _toggle(FavoriteType.festival, id, _savedFestivalIds);

  void _toggle(FavoriteType type, String id, Set<String> currentSet) {
    final userId = _userId;
    if (userId == null) return;

    // Optimistic local update — the live Firestore listener will reconcile
    // this shortly after, but the tap should feel instant.
    final wasSaved = currentSet.contains(id);
    if (wasSaved) {
      currentSet.remove(id);
    } else {
      currentSet.add(id);
    }
    notifyListeners();

    final future = wasSaved ? _repository.remove(userId, type, id) : _repository.add(userId, type, id);
    future.catchError((_) {
      // Offline persistence queues the write for later; nothing to revert.
    });
  }

  /// Same optimistic-update shape as [_toggle], but list-based (there's no
  /// pre-existing set of ids to flip a membership bit on) and carrying the
  /// place's own data on add, since that's what [FavoritesRepository.add]
  /// needs to snapshot for a type with no other collection to resolve from.
  void togglePlace(Place place) {
    final userId = _userId;
    if (userId == null) return;

    final wasSaved = _savedPlaceIds.contains(place.id);
    _savedPlaces = wasSaved
        ? _savedPlaces.where((p) => p.id != place.id).toList()
        : [..._savedPlaces, place];
    _savedPlaceIds = _savedPlaces.map((p) => p.id).toSet();
    notifyListeners();

    final future = wasSaved
        ? _repository.remove(userId, FavoriteType.place, place.id)
        : _repository.add(
            userId,
            FavoriteType.place,
            place.id,
            // Stale once persisted — it's the distance from wherever this
            // place was originally found, not from the traveler's position
            // whenever they later revisit their saved list.
            snapshot: Map<String, dynamic>.from(place.toJson())..remove('distanceMeters'),
          );
    future.catchError((_) {
      // Offline persistence queues the write for later; nothing to revert.
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _placesSubscription?.cancel();
    super.dispose();
  }
}
