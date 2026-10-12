import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/favorites_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/services/places_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/cards/business_card.dart';
import '../../core/widgets/cards/destination_card.dart';
import '../../core/widgets/cards/festival_card.dart';
import '../../core/widgets/cards/place_card.dart';
import '../../core/widgets/cards/restaurant_card.dart';
import '../../core/widgets/details/business_info_sheet.dart';
import '../../core/widgets/details/place_details_sheet.dart';
import '../../core/widgets/dialogs/add_to_collection_sheet.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/inputs/search_sort_bar.dart';
import '../../core/widgets/layout/max_width_container.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/business_repository.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/festival_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../domain/models/business.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/favorite_collection.dart';
import '../../domain/models/festival.dart';
import '../../domain/models/place.dart';
import '../../domain/models/restaurant.dart';

/// Image height used for every card in the two-column grid, kept in sync
/// with [_gridCellExtent] so card content never overflows its grid cell.
const double _gridImageHeight = 140;
const double _gridCellExtent = _gridImageHeight + 92;

/// One saved item as a tab lists it: what it's searched and sorted by, and
/// how to draw its card at a given width.
typedef _SavedEntry = ({
  String name,
  double rating,
  Widget Function(double width) card,
});

enum _SavedSort { saved, nameAscending, nameDescending, rating }

const Map<_SavedSort, String> _savedSortLabels = {
  _SavedSort.saved: 'Default order',
  _SavedSort.nameAscending: 'Name (A–Z)',
  _SavedSort.nameDescending: 'Name (Z–A)',
  _SavedSort.rating: 'Rating (High–Low)',
};

/// Never a real id list, so setting it forces the next lookup to rerun.
const String _staleKey = '\u0000';

/// Everything the traveler has bookmarked, split into Places, Food,
/// Festivals and Local Finds (businesses) tabs, all backed by
/// [FavoritesProvider] — catalog items resolved live against their own
/// Firestore collection given just a saved id, live Google Places results
/// rendered directly from their own fully-hydrated snapshot (a `Place` has
/// no other collection to resolve one from).
///
/// A saved live place is filed by what it *is*, not where it came from: a
/// restaurant or café saved from Google Places sits in Food alongside the
/// catalog restaurants (see [Place.isDining]); every other live place sits
/// in Places alongside the catalog tourist spots.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
  );
  final DestinationRepository _destinationRepository = DestinationRepository();
  final RestaurantRepository _restaurantRepository = RestaurantRepository();
  final FestivalRepository _festivalRepository = FestivalRepository();
  final BusinessRepository _businessRepository = BusinessRepository();
  final FavoritesRepository _favoritesRepository = FavoritesRepository();
  final PlacesService _places = PlacesService();

  /// Null means "All" — every tab shows its full saved list, unfiltered.
  String? _selectedCollectionId;

  // One search + sort shared by every tab.
  final TextEditingController _search = TextEditingController();
  _SavedSort _sort = _SavedSort.saved;

  // Each tab's lookup, kept until the ids it was made for change — started
  // straight from `build` it would otherwise rerun on every keystroke in
  // the search box.
  final Map<String, ({String key, Future<Object> future})> _lookups = {};

  Future<List<T>> _cached<T>(
    String tab,
    List<String> ids,
    Future<List<T>> Function() load,
  ) {
    final key = ids.join(',');
    final hit = _lookups[tab];
    if (hit != null && hit.key == key) return hit.future as Future<List<T>>;
    final future = load();
    _lookups[tab] = (key: key, future: future);
    return future;
  }

  /// Pull-to-refresh: drop every kept lookup so each tab fetches again.
  Future<void> _refresh() async {
    setState(() {
      _lookups.clear();
      _linkedKey = _staleKey;
    });
  }

  /// [entries] narrowed to the search text and put in the chosen order.
  List<_SavedEntry> _visible(List<_SavedEntry> entries) {
    final query = _search.text.trim().toLowerCase();
    final matches = entries
        .where((e) => query.isEmpty || e.name.toLowerCase().contains(query))
        .toList();
    int byName(_SavedEntry a, _SavedEntry b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    switch (_sort) {
      case _SavedSort.saved:
        break;
      case _SavedSort.nameAscending:
        matches.sort(byName);
      case _SavedSort.nameDescending:
        matches.sort((a, b) => byName(b, a));
      case _SavedSort.rating:
        matches.sort((a, b) {
          final ratings = b.rating.compareTo(a.rating);
          return ratings != 0 ? ratings : byName(a, b);
        });
    }
    return matches;
  }

  // A Food & Dining Local Find is saved under its mirrored restaurant's id,
  // as a *restaurant* favorite (see `businessFavoriteAndReviewTarget`), so
  // it never appeared under Local Finds — the tab it was saved from. These
  // are those listings, looked up from the saved restaurant ids and
  // refetched only when that set changes.
  String _linkedKey = '';
  Future<List<Business>> _linkedLocalFinds = Future.value(const []);
  int _linkedCount = 0;

  void _syncLinkedLocalFinds(List<String> restaurantIds) {
    final key = (restaurantIds.toList()..sort()).join(',');
    if (key == _linkedKey) return;
    _linkedKey = key;
    final lookup = _businessRepository
        .getApprovedByRestaurantIds(restaurantIds)
        // Best-effort: the directly saved Local Finds still show.
        .catchError((Object _) => const <Business>[]);
    _linkedLocalFinds = lookup;
    lookup.then((linked) {
      if (!mounted || _linkedLocalFinds != lookup) return;
      if (linked.length != _linkedCount) {
        setState(() => _linkedCount = linked.length);
      }
    });
  }

  /// Everything the Local Finds tab lists: listings saved in their own
  /// right, then the Food & Dining ones saved through their restaurant.
  Future<List<Business>> _loadLocalFinds(
    List<String> businessIds,
    Map<String, String?> collectionByKey,
  ) async {
    final direct = await _businessRepository.getByIds(businessIds);
    final linked = await _linkedLocalFinds;
    final seen = direct.map((b) => b.id).toSet();
    return [
      ...direct,
      for (final business in linked)
        if (seen.add(business.id) &&
            (_selectedCollectionId == null ||
                collectionByKey['${FavoriteType.restaurant.name}:${business.restaurantId}'] ==
                    _selectedCollectionId))
          business,
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    _search.dispose();
    super.dispose();
  }

  /// [FavoriteType.destination]/etc ids filtered down to just the ones
  /// assigned to [_selectedCollectionId] — a no-op (every id passes) when
  /// "All" is selected.
  List<String> _filterByCollection(
    List<String> ids,
    FavoriteType type,
    Map<String, String?> collectionByKey,
  ) {
    if (_selectedCollectionId == null) return ids;
    return ids
        .where(
          (id) => collectionByKey['${type.name}:$id'] == _selectedCollectionId,
        )
        .toList();
  }

  Future<void> _showCollectionOptions(
    FavoriteCollection collection,
    String uid,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.edit_rounded),
              title: const Text('Rename list'),
              onTap: () => Navigator.of(context).pop('rename'),
            ),
            ListTile(
              leading: const Icon(
                Symbols.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: const Text(
                'Delete list',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'rename') {
      await _renameCollection(collection);
    } else if (action == 'delete') {
      await _deleteCollection(collection, uid);
    }
  }

  Future<void> _renameCollection(FavoriteCollection collection) async {
    final controller = TextEditingController(text: collection.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          // Scrolls on a short viewport (landscape, keyboard open) instead of overflowing.
          scrollable: true,
          title: const Text('Rename list'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 60,
            onChanged: (_) => setDialogState(() {}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (name == null || !mounted) return;
    try {
      await _favoritesRepository.renameCollection(collection.id, name);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Future<void> _deleteCollection(
    FavoriteCollection collection,
    String uid,
  ) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete "${collection.name}"?',
      message:
          'Favorites in this list aren\'t removed — they just go back to Unsorted.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await _favoritesRepository.deleteCollection(uid, collection.id);
      if (_selectedCollectionId == collection.id)
        setState(() => _selectedCollectionId = null);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Widget _cardWithCollectionButton({
    required Widget card,
    required String userId,
    required List<FavoriteCollection> collections,
    required String? currentCollectionId,
    required FavoriteType type,
    required String itemId,
  }) {
    return Stack(
      children: [
        card,
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.black.withValues(alpha: 0.45),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => showAddToCollectionSheet(
                context,
                collections: collections,
                currentCollectionId: currentCollectionId,
                repository: _favoritesRepository,
                userId: userId,
                type: type,
                itemId: itemId,
              ),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Symbols.playlist_add_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saved = context.watch<FavoritesProvider>();
    final uid = context.watch<AuthProvider>().firebaseUser?.uid;
    final destinationIds = saved.savedDestinationIds.toList();
    final restaurantIds = saved.savedRestaurantIds.toList();
    final festivalIds = saved.savedFestivalIds.toList();
    final businessIds = saved.savedBusinessIds.toList();
    _syncLinkedLocalFinds(restaurantIds);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                MaxWidthContainer.sidePadding(context, maxWidth: 1400),
                AppSpacing.sm,
                MaxWidthContainer.sidePadding(context, maxWidth: 1400),
                AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Saved', style: theme.textTheme.displayMedium),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                MaxWidthContainer.sidePadding(context, maxWidth: 1400),
                0,
                MaxWidthContainer.sidePadding(context, maxWidth: 1400),
                AppSpacing.xs,
              ),
              child: SearchSortBar<_SavedSort>(
                controller: _search,
                hintText: 'Search saved...',
                onQueryChanged: () => setState(() {}),
                sort: _sort,
                sortLabels: _savedSortLabels,
                onSortChanged: (sort) => setState(() => _sort = sort),
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.textTheme.bodyMedium?.color,
              indicatorColor: theme.colorScheme.primary,
              labelStyle: theme.textTheme.labelLarge,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(
                  icon: const Icon(Symbols.landscape_rounded),
                  text:
                      'Places (${destinationIds.length + saved.savedPlaces.where((p) => !p.isDining).length})',
                ),
                Tab(
                  icon: const Icon(Symbols.restaurant_rounded),
                  text:
                      'Food (${restaurantIds.length + saved.savedPlaces.where((p) => p.isDining).length})',
                ),
                Tab(
                  icon: const Icon(Symbols.celebration_rounded),
                  text: 'Festivals (${festivalIds.length})',
                ),
                Tab(
                  icon: const Icon(Symbols.storefront_rounded),
                  text: 'Local Finds (${businessIds.length + _linkedCount})',
                ),
              ],
            ),
            if (uid != null)
              StreamBuilder<List<FavoriteCollection>>(
                stream: _favoritesRepository.streamCollections(uid),
                builder: (context, collectionsSnapshot) {
                  final collections = collectionsSnapshot.data ?? const [];
                  // No lists created yet and nothing to filter by — the chip
                  // row would just be a single meaningless "All" pill.
                  if (collections.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      MaxWidthContainer.sidePadding(context, maxWidth: 1400),
                      AppSpacing.sm,
                      MaxWidthContainer.sidePadding(context, maxWidth: 1400),
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('All'),
                                selected: _selectedCollectionId == null,
                                onSelected: (_) => setState(
                                  () => _selectedCollectionId = null,
                                ),
                              ),
                              for (final collection in collections) ...[
                                const SizedBox(width: AppSpacing.sm),
                                GestureDetector(
                                  onLongPress: () =>
                                      _showCollectionOptions(collection, uid),
                                  child: ChoiceChip(
                                    label: Text(collection.name),
                                    selected:
                                        _selectedCollectionId == collection.id,
                                    onSelected: (_) => setState(
                                      () => _selectedCollectionId =
                                          _selectedCollectionId == collection.id
                                          ? null
                                          : collection.id,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Long-press a list to rename or delete it.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            Expanded(
              child: uid == null
                  ? _buildTabs(
                      destinationIds,
                      restaurantIds,
                      festivalIds,
                      businessIds,
                      saved,
                      uid: '',
                      collections: const [],
                      collectionByKey: const {},
                    )
                  : StreamBuilder<List<FavoriteCollection>>(
                      stream: _favoritesRepository.streamCollections(uid),
                      builder: (context, collectionsSnapshot) {
                        final collections =
                            collectionsSnapshot.data ?? const [];
                        return StreamBuilder<List<FavoriteDoc>>(
                          stream: _favoritesRepository.streamFavoriteDocs(uid),
                          builder: (context, docsSnapshot) {
                            final collectionByKey = <String, String?>{
                              for (final doc
                                  in docsSnapshot.data ?? const <FavoriteDoc>[])
                                '${doc.type.name}:${doc.itemId}':
                                    doc.collectionId,
                            };
                            return _buildTabs(
                              destinationIds,
                              restaurantIds,
                              festivalIds,
                              businessIds,
                              saved,
                              uid: uid,
                              collections: collections,
                              collectionByKey: collectionByKey,
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(
    List<String> destinationIds,
    List<String> restaurantIds,
    List<String> festivalIds,
    List<String> businessIds,
    FavoritesProvider saved, {
    required String uid,
    required List<FavoriteCollection> collections,
    required Map<String, String?> collectionByKey,
  }) {
    final filteredDestinationIds = _filterByCollection(
      destinationIds,
      FavoriteType.destination,
      collectionByKey,
    );
    final filteredRestaurantIds = _filterByCollection(
      restaurantIds,
      FavoriteType.restaurant,
      collectionByKey,
    );
    final filteredFestivalIds = _filterByCollection(
      festivalIds,
      FavoriteType.festival,
      collectionByKey,
    );
    final filteredBusinessIds = _filterByCollection(
      businessIds,
      FavoriteType.business,
      collectionByKey,
    );
    final filteredPlaces = _selectedCollectionId == null
        ? saved.savedPlaces
        : saved.savedPlaces
              .where(
                (p) =>
                    collectionByKey['${FavoriteType.place.name}:${p.id}'] ==
                    _selectedCollectionId,
              )
              .toList();
    final diningPlaces = filteredPlaces.where((p) => p.isDining).toList();
    final attractionPlaces = filteredPlaces.where((p) => !p.isDining).toList();

    Widget placeCard(Place place, double width) => _cardWithCollectionButton(
      card: PlaceCard(
        place: place,
        width: width,
        imageHeight: _gridImageHeight,
        imageUrl: place.photoNames.isNotEmpty
            ? _places.photoUrl(place.photoNames.first)
            : '',
        onTap: () => showPlaceDetailsSheet(
          context,
          place: place,
          placesService: _places,
        ),
      ),
      userId: uid,
      collections: collections,
      currentCollectionId:
          collectionByKey['${FavoriteType.place.name}:${place.id}'],
      type: FavoriteType.place,
      itemId: place.id,
    );

    // One tab's grid: [entries] narrowed to the search text and put in the
    // chosen order.
    Widget grid({
      required List<_SavedEntry> entries,
      required bool isLoading,
      required String emptyTitle,
      required String emptyMessage,
    }) {
      final visible = _visible(entries);
      final searching = entries.isNotEmpty && visible.isEmpty;
      return _SavedGrid(
        itemCount: visible.length,
        isLoading: isLoading,
        emptyTitle: searching ? 'No matches' : emptyTitle,
        emptyMessage: searching
            ? 'Nothing saved here matches your search.'
            : emptyMessage,
        itemBuilder: (context, width, i) => visible[i].card(width),
      );
    }

    _SavedEntry placeEntry(Place place) => (
      name: place.name,
      rating: place.rating ?? 0,
      card: (width) => placeCard(place, width),
    );

    return TabBarView(
      controller: _tabController,
      children: [
        RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Destination>>(
            future: _cached(
              'places',
              filteredDestinationIds,
              () => _destinationRepository.getByIds(filteredDestinationIds),
            ),
            // Tourist spots first, then the saved Google attractions — those
            // need no lookup: a saved place is never persisted anywhere
            // else, so `saved.savedPlaces` is already the fully-hydrated
            // favorite data straight off FavoritesProvider's live stream
            // (see FavoritesRepository.streamSavedPlaces).
            builder: (context, snapshot) => grid(
              entries: [
                for (final destination
                    in snapshot.data ?? const <Destination>[])
                  (
                    name: destination.name,
                    rating: destination.rating,
                    card: (width) => _cardWithCollectionButton(
                      card: DestinationCard(
                        destination: destination,
                        width: width,
                        imageHeight: _gridImageHeight,
                        onTap: () => context.push(
                          RoutePaths.destinationDetails(destination.id),
                        ),
                      ),
                      userId: uid,
                      collections: collections,
                      currentCollectionId:
                          collectionByKey['${FavoriteType.destination.name}:${destination.id}'],
                      type: FavoriteType.destination,
                      itemId: destination.id,
                    ),
                  ),
                ...attractionPlaces.map(placeEntry),
              ],
              isLoading: snapshot.connectionState != ConnectionState.done,
              emptyTitle: _selectedCollectionId == null
                  ? 'No saved places yet'
                  : 'No places in this list yet',
              emptyMessage: _selectedCollectionId == null
                  ? 'Tap the bookmark icon on any destination or attraction to save it here.'
                  : 'Add a saved place to this list from the small list icon on its card.',
            ),
          ),
        ),
        RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Restaurant>>(
            future: _cached(
              'food',
              filteredRestaurantIds,
              () => _restaurantRepository.getByIds(filteredRestaurantIds),
            ),
            // Catalog restaurants first, then restaurants/cafés saved from
            // live Google Places results — see the class doc.
            builder: (context, snapshot) => grid(
              entries: [
                for (final restaurant
                    in snapshot.data ?? const <Restaurant>[])
                  (
                    name: restaurant.name,
                    rating: restaurant.rating,
                    card: (width) => _cardWithCollectionButton(
                      card: RestaurantCard(
                        restaurant: restaurant,
                        width: width,
                        imageHeight: _gridImageHeight,
                        onTap: () => context.push(
                          RoutePaths.restaurantDetails(restaurant.id),
                        ),
                      ),
                      userId: uid,
                      collections: collections,
                      currentCollectionId:
                          collectionByKey['${FavoriteType.restaurant.name}:${restaurant.id}'],
                      type: FavoriteType.restaurant,
                      itemId: restaurant.id,
                    ),
                  ),
                ...diningPlaces.map(placeEntry),
              ],
              isLoading: snapshot.connectionState != ConnectionState.done,
              emptyTitle: _selectedCollectionId == null
                  ? 'No saved restaurants yet'
                  : 'No restaurants in this list yet',
              emptyMessage: _selectedCollectionId == null
                  ? 'Bookmark restaurants you want to try to see them here.'
                  : 'Add a saved restaurant to this list from the small list icon on its card.',
            ),
          ),
        ),
        RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Festival>>(
            future: _cached(
              'festivals',
              filteredFestivalIds,
              () => _festivalRepository.getByIds(filteredFestivalIds),
            ),
            builder: (context, snapshot) => grid(
              entries: [
                for (final festival in snapshot.data ?? const <Festival>[])
                  (
                    name: festival.name,
                    rating: festival.rating,
                    card: (width) => _cardWithCollectionButton(
                      card: FestivalCard(
                        festival: festival,
                        width: width,
                        imageHeight: _gridImageHeight,
                        onTap: () => context.push(
                          RoutePaths.festivalDetails(festival.id),
                        ),
                      ),
                      userId: uid,
                      collections: collections,
                      currentCollectionId:
                          collectionByKey['${FavoriteType.festival.name}:${festival.id}'],
                      type: FavoriteType.festival,
                      itemId: festival.id,
                    ),
                  ),
              ],
              isLoading: snapshot.connectionState != ConnectionState.done,
              emptyTitle: _selectedCollectionId == null
                  ? 'No saved festivals yet'
                  : 'No festivals in this list yet',
              emptyMessage: _selectedCollectionId == null
                  ? 'Bookmark festivals to plan your trips around them.'
                  : 'Add a saved festival to this list from the small list icon on its card.',
            ),
          ),
        ),
        RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Business>>(
            future: _cached(
              'localFinds',
              // Everything the combined lookup depends on, not just the ids.
              [...filteredBusinessIds, _linkedKey, _selectedCollectionId ?? ''],
              () => _loadLocalFinds(filteredBusinessIds, collectionByKey),
            ),
            builder: (context, snapshot) => grid(
              entries: [
                for (final business in snapshot.data ?? const <Business>[])
                  (
                    name: business.name,
                    rating: business.rating,
                    card: (width) {
                      // The favorite this card stands for — the listing's
                      // own, or its restaurant's for a Food & Dining one.
                      final (favoriteType, _, favoriteId) =
                          businessFavoriteAndReviewTarget(business);
                      return _cardWithCollectionButton(
                        card: BusinessCard(
                          business: business,
                          width: width,
                          imageHeight: _gridImageHeight,
                          onTap: () =>
                              showBusinessInfoSheet(context, business),
                        ),
                        userId: uid,
                        collections: collections,
                        currentCollectionId:
                            collectionByKey['${favoriteType.name}:$favoriteId'],
                        type: favoriteType,
                        itemId: favoriteId,
                      );
                    },
                  ),
              ],
              isLoading: snapshot.connectionState != ConnectionState.done,
              emptyTitle: _selectedCollectionId == null
                  ? 'No saved local finds yet'
                  : 'No local finds in this list yet',
              emptyMessage: _selectedCollectionId == null
                  ? 'Tap the heart icon on any local find to save it here.'
                  : 'Add a saved local find to this list from the small list icon on its card.',
            ),
          ),
        ),
      ],
    );
  }
}

class _SavedGrid extends StatelessWidget {
  const _SavedGrid({
    required this.itemCount,
    required this.isLoading,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.itemBuilder,
  });

  final int itemCount;
  final bool isLoading;
  final String emptyTitle;
  final String emptyMessage;
  final Widget Function(BuildContext, double width, int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (isLoading && itemCount == 0) {
      return LoadingWidget.grid();
    }
    if (itemCount == 0) {
      return Center(
        child: EmptyStateWidget(
          icon: Symbols.bookmark_border_rounded,
          title: emptyTitle,
          message: emptyMessage,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = context.gridColumns;
        final side = MaxWidthContainer.sidePadding(context, maxWidth: 1400);
        final cardWidth =
            (constraints.maxWidth - side * 2 - AppSpacing.md * (columns - 1)) /
            columns;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            side,
            AppSpacing.md,
            side,
            // Taller than AppSpacing.huge alone — this tab also has the
            // floating AI Chat FAB (`_AiChatFab` in `MainShellScreen`)
            // hovering above the bottom nav bar, which the plain nav-bar
            // clearance doesn't account for, letting the last row sit right
            // behind it.
            AppSpacing.huge + AppSpacing.xxxl,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.lg,
            mainAxisExtent: _gridCellExtent,
          ),
          itemCount: itemCount,
          itemBuilder: (context, i) => itemBuilder(context, cardWidth, i),
        );
      },
    );
  }
}
