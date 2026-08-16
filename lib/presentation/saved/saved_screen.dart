import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/favorites_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/services/places_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/widgets/cards/destination_card.dart';
import '../../core/widgets/cards/festival_card.dart';
import '../../core/widgets/cards/place_card.dart';
import '../../core/widgets/cards/restaurant_card.dart';
import '../../core/widgets/details/place_details_sheet.dart';
import '../../core/widgets/dialogs/add_to_collection_sheet.dart';
import '../../core/widgets/layout/max_width_container.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/festival_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/favorite_collection.dart';
import '../../domain/models/festival.dart';
import '../../domain/models/restaurant.dart';

/// Image height used for every card in the two-column grid, kept in sync
/// with [_gridCellExtent] so card content never overflows its grid cell.
const double _gridImageHeight = 140;
const double _gridCellExtent = _gridImageHeight + 92;

/// Everything the traveler has bookmarked, split into Destinations,
/// Restaurants, Festivals, and Attractions (live Google Places results)
/// tabs, all backed by [FavoritesProvider] — the first three resolved live
/// against their own Firestore collection given just a saved id, the last
/// rendered directly from its own fully-hydrated snapshot (a `Place` has no
/// other collection to resolve one from).
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
  final FavoritesRepository _favoritesRepository = FavoritesRepository();
  final PlacesService _places = PlacesService();

  /// Null means "All" — every tab shows its full saved list, unfiltered.
  String? _selectedCollectionId;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// [FavoriteType.destination]/etc ids filtered down to just the ones
  /// assigned to [_selectedCollectionId] — a no-op (every id passes) when
  /// "All" is selected.
  List<String> _filterByCollection(List<String> ids, FavoriteType type, Map<String, String?> collectionByKey) {
    if (_selectedCollectionId == null) return ids;
    return ids.where((id) => collectionByKey['${type.name}:$id'] == _selectedCollectionId).toList();
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
                child: Icon(Symbols.playlist_add_rounded, size: 18, color: Colors.white),
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
            TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.textTheme.bodyMedium?.color,
              indicatorColor: theme.colorScheme.primary,
              labelStyle: theme.textTheme.labelLarge,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Places (${destinationIds.length})'),
                Tab(text: 'Food (${restaurantIds.length})'),
                Tab(text: 'Festivals (${festivalIds.length})'),
                Tab(text: 'Attractions (${saved.savedPlaces.length})'),
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
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: _selectedCollectionId == null,
                            onSelected: (_) => setState(() => _selectedCollectionId = null),
                          ),
                          for (final collection in collections) ...[
                            const SizedBox(width: AppSpacing.sm),
                            ChoiceChip(
                              label: Text(collection.name),
                              selected: _selectedCollectionId == collection.id,
                              onSelected: (_) => setState(
                                () => _selectedCollectionId = _selectedCollectionId == collection.id ? null : collection.id,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            Expanded(
              child: uid == null
                  ? _buildTabs(destinationIds, restaurantIds, festivalIds, saved, uid: '', collections: const [], collectionByKey: const {})
                  : StreamBuilder<List<FavoriteCollection>>(
                      stream: _favoritesRepository.streamCollections(uid),
                      builder: (context, collectionsSnapshot) {
                        final collections = collectionsSnapshot.data ?? const [];
                        return StreamBuilder<List<FavoriteDoc>>(
                          stream: _favoritesRepository.streamFavoriteDocs(uid),
                          builder: (context, docsSnapshot) {
                            final collectionByKey = <String, String?>{
                              for (final doc in docsSnapshot.data ?? const <FavoriteDoc>[])
                                '${doc.type.name}:${doc.itemId}': doc.collectionId,
                            };
                            return _buildTabs(
                              destinationIds,
                              restaurantIds,
                              festivalIds,
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
    FavoritesProvider saved, {
    required String uid,
    required List<FavoriteCollection> collections,
    required Map<String, String?> collectionByKey,
  }) {
    final filteredDestinationIds = _filterByCollection(destinationIds, FavoriteType.destination, collectionByKey);
    final filteredRestaurantIds = _filterByCollection(restaurantIds, FavoriteType.restaurant, collectionByKey);
    final filteredFestivalIds = _filterByCollection(festivalIds, FavoriteType.festival, collectionByKey);
    final filteredPlaces = _selectedCollectionId == null
        ? saved.savedPlaces
        : saved.savedPlaces.where((p) => collectionByKey['${FavoriteType.place.name}:${p.id}'] == _selectedCollectionId).toList();

    return TabBarView(
      controller: _tabController,
      children: [
        RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: FutureBuilder<List<Destination>>(
            future: _destinationRepository.getByIds(filteredDestinationIds),
            builder: (context, snapshot) => _SavedGrid(
              itemCount: snapshot.data?.length ?? 0,
              isLoading: snapshot.connectionState != ConnectionState.done,
              emptyTitle: _selectedCollectionId == null ? 'No saved places yet' : 'No places in this list yet',
              emptyMessage: _selectedCollectionId == null
                  ? 'Tap the bookmark icon on any destination to save it here.'
                  : 'Add a saved place to this list from the small list icon on its card.',
              itemBuilder: (context, width, i) {
                final destination = snapshot.data![i];
                return _cardWithCollectionButton(
                  card: DestinationCard(
                    destination: destination,
                    width: width,
                    imageHeight: _gridImageHeight,
                    onTap: () => context.push(RoutePaths.destinationDetails(destination.id)),
                  ),
                  userId: uid,
                  collections: collections,
                  currentCollectionId: collectionByKey['${FavoriteType.destination.name}:${destination.id}'],
                  type: FavoriteType.destination,
                  itemId: destination.id,
                );
              },
            ),
          ),
        ),
        RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: FutureBuilder<List<Restaurant>>(
            future: _restaurantRepository.getByIds(filteredRestaurantIds),
            builder: (context, snapshot) => _SavedGrid(
              itemCount: snapshot.data?.length ?? 0,
              isLoading: snapshot.connectionState != ConnectionState.done,
              emptyTitle: _selectedCollectionId == null ? 'No saved restaurants yet' : 'No restaurants in this list yet',
              emptyMessage: _selectedCollectionId == null
                  ? 'Bookmark restaurants you want to try to see them here.'
                  : 'Add a saved restaurant to this list from the small list icon on its card.',
              itemBuilder: (context, width, i) {
                final restaurant = snapshot.data![i];
                return _cardWithCollectionButton(
                  card: RestaurantCard(
                    restaurant: restaurant,
                    width: width,
                    imageHeight: _gridImageHeight,
                    onTap: () => context.push(RoutePaths.restaurantDetails(restaurant.id)),
                  ),
                  userId: uid,
                  collections: collections,
                  currentCollectionId: collectionByKey['${FavoriteType.restaurant.name}:${restaurant.id}'],
                  type: FavoriteType.restaurant,
                  itemId: restaurant.id,
                );
              },
            ),
          ),
        ),
        RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: FutureBuilder<List<Festival>>(
            future: _festivalRepository.getByIds(filteredFestivalIds),
            builder: (context, snapshot) => _SavedGrid(
              itemCount: snapshot.data?.length ?? 0,
              isLoading: snapshot.connectionState != ConnectionState.done,
              emptyTitle: _selectedCollectionId == null ? 'No saved festivals yet' : 'No festivals in this list yet',
              emptyMessage: _selectedCollectionId == null
                  ? 'Bookmark festivals to plan your trips around them.'
                  : 'Add a saved festival to this list from the small list icon on its card.',
              itemBuilder: (context, width, i) {
                final festival = snapshot.data![i];
                return _cardWithCollectionButton(
                  card: FestivalCard(
                    festival: festival,
                    width: width,
                    imageHeight: _gridImageHeight,
                    onTap: () => context.push(RoutePaths.festivalDetails(festival.id)),
                  ),
                  userId: uid,
                  collections: collections,
                  currentCollectionId: collectionByKey['${FavoriteType.festival.name}:${festival.id}'],
                  type: FavoriteType.festival,
                  itemId: festival.id,
                );
              },
            ),
          ),
        ),
        // No FutureBuilder/repository lookup — a saved place is never
        // persisted anywhere else, so `saved.savedPlaces` is already the
        // fully-hydrated favorite data straight off FavoritesProvider's live
        // stream (see FavoritesRepository.streamSavedPlaces).
        _SavedGrid(
          itemCount: filteredPlaces.length,
          isLoading: false,
          emptyTitle: _selectedCollectionId == null ? 'No saved attractions yet' : 'No attractions in this list yet',
          emptyMessage: _selectedCollectionId == null
              ? 'Tap the bookmark icon on any attraction to save it here.'
              : 'Add a saved attraction to this list from the small list icon on its card.',
          itemBuilder: (context, width, i) {
            final place = filteredPlaces[i];
            return _cardWithCollectionButton(
              card: PlaceCard(
                place: place,
                width: width,
                imageHeight: _gridImageHeight,
                imageUrl: place.photoNames.isNotEmpty ? _places.photoUrl(place.photoNames.first) : '',
                onTap: () => showPlaceDetailsSheet(context, place: place, placesService: _places),
              ),
              userId: uid,
              collections: collections,
              currentCollectionId: collectionByKey['${FavoriteType.place.name}:${place.id}'],
              type: FavoriteType.place,
              itemId: place.id,
            );
          },
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
            (constraints.maxWidth - side * 2 - AppSpacing.md * (columns - 1)) / columns;
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
