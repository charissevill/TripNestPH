import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

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
import '../../core/widgets/layout/max_width_container.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/festival_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../domain/models/destination.dart';
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
  final PlacesService _places = PlacesService();

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saved = context.watch<FavoritesProvider>();
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
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: FutureBuilder<List<Destination>>(
                      future: _destinationRepository.getByIds(destinationIds),
                      builder: (context, snapshot) => _SavedGrid(
                        itemCount: snapshot.data?.length ?? 0,
                        isLoading:
                            snapshot.connectionState != ConnectionState.done,
                        emptyTitle: 'No saved places yet',
                        emptyMessage:
                            'Tap the bookmark icon on any destination to save it here.',
                        itemBuilder: (context, width, i) {
                          final destination = snapshot.data![i];
                          return DestinationCard(
                            destination: destination,
                            width: width,
                            imageHeight: _gridImageHeight,
                            onTap: () => context.push(
                              RoutePaths.destinationDetails(destination.id),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: FutureBuilder<List<Restaurant>>(
                      future: _restaurantRepository.getByIds(restaurantIds),
                      builder: (context, snapshot) => _SavedGrid(
                        itemCount: snapshot.data?.length ?? 0,
                        isLoading:
                            snapshot.connectionState != ConnectionState.done,
                        emptyTitle: 'No saved restaurants yet',
                        emptyMessage:
                            'Bookmark restaurants you want to try to see them here.',
                        itemBuilder: (context, width, i) {
                          final restaurant = snapshot.data![i];
                          return RestaurantCard(
                            restaurant: restaurant,
                            width: width,
                            imageHeight: _gridImageHeight,
                            onTap: () => context.push(
                              RoutePaths.restaurantDetails(restaurant.id),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: FutureBuilder<List<Festival>>(
                      future: _festivalRepository.getByIds(festivalIds),
                      builder: (context, snapshot) => _SavedGrid(
                        itemCount: snapshot.data?.length ?? 0,
                        isLoading:
                            snapshot.connectionState != ConnectionState.done,
                        emptyTitle: 'No saved festivals yet',
                        emptyMessage:
                            'Bookmark festivals to plan your trips around them.',
                        itemBuilder: (context, width, i) {
                          final festival = snapshot.data![i];
                          return FestivalCard(
                            festival: festival,
                            width: width,
                            imageHeight: _gridImageHeight,
                            onTap: () => context.push(
                              RoutePaths.festivalDetails(festival.id),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // No FutureBuilder/repository lookup — a saved place is
                  // never persisted anywhere else, so `saved.savedPlaces` is
                  // already the fully-hydrated favorite data straight off
                  // FavoritesProvider's live stream (see
                  // FavoritesRepository.streamSavedPlaces).
                  _SavedGrid(
                    itemCount: saved.savedPlaces.length,
                    isLoading: false,
                    emptyTitle: 'No saved attractions yet',
                    emptyMessage:
                        'Tap the bookmark icon on any attraction to save it here.',
                    itemBuilder: (context, width, i) {
                      final place = saved.savedPlaces[i];
                      return PlaceCard(
                        place: place,
                        width: width,
                        imageHeight: _gridImageHeight,
                        imageUrl: place.photoNames.isNotEmpty ? _places.photoUrl(place.photoNames.first) : '',
                        onTap: () => showPlaceDetailsSheet(context, place: place, placesService: _places),
                      );
                    },
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
