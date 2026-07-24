import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/favorites_repository.dart';

/// Firestore-backed favorites state, exposing the exact same API the Phase 1
/// UI already calls (`isDestinationSaved`, `toggleDestination`, ...) so no
/// screen or card widget needs to change — only where the data comes from.
class FavoritesProvider extends ChangeNotifier {
  FavoritesProvider({FavoritesRepository? repository}) : _repository = repository ?? FavoritesRepository();

  final FavoritesRepository _repository;
  StreamSubscription<Map<FavoriteType, Set<String>>>? _subscription;

  String? _userId;
  Set<String> _savedDestinationIds = {};
  Set<String> _savedRestaurantIds = {};
  Set<String> _savedFestivalIds = {};

  bool isDestinationSaved(String id) => _savedDestinationIds.contains(id);
  bool isRestaurantSaved(String id) => _savedRestaurantIds.contains(id);
  bool isFestivalSaved(String id) => _savedFestivalIds.contains(id);

  int get totalSavedCount => _savedDestinationIds.length + _savedRestaurantIds.length + _savedFestivalIds.length;

  Set<String> get savedDestinationIds => _savedDestinationIds;
  Set<String> get savedRestaurantIds => _savedRestaurantIds;
  Set<String> get savedFestivalIds => _savedFestivalIds;

  /// Called whenever the signed-in user changes (including sign-out, where
  /// [userId] is null and every favorite clears from view).
  void bindToUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _subscription?.cancel();
    _savedDestinationIds = {};
    _savedRestaurantIds = {};
    _savedFestivalIds = {};
    notifyListeners();

    if (userId == null) return;
    _subscription = _repository.streamFavorites(userId).listen((byType) {
      _savedDestinationIds = byType[FavoriteType.destination] ?? {};
      _savedRestaurantIds = byType[FavoriteType.restaurant] ?? {};
      _savedFestivalIds = byType[FavoriteType.festival] ?? {};
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
}
