import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/cards/category_card.dart';
import '../../core/widgets/cards/destination_card.dart';
import '../../core/widgets/cards/festival_card.dart';
import '../../core/widgets/cards/restaurant_card.dart';
import '../../core/widgets/dialogs/active_filter_chips.dart';
import '../../core/widgets/dialogs/search_filter_sheet.dart';
import '../../core/widgets/inputs/search_bar_widget.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/mock/mock_categories.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/festival_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../data/repositories/region_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/festival.dart';
import '../../domain/models/province.dart';
import '../../domain/models/region.dart';
import '../../domain/models/restaurant.dart';

enum _ExploreTab { destinations, restaurants, festivals }

/// Image height used for every card in the two-column grid, kept in sync
/// with [_gridCellExtent] so card content never overflows its grid cell.
const double _gridImageHeight = 140;
const double _gridCellExtent = _gridImageHeight + 92;
const int _pageSize = 20;

/// Browse-everything screen: category chips + a destinations / restaurants /
/// festivals tab switch, all rendered as a responsive, paginated two-column
/// grid loaded live from Firestore.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, this.initialCategoryId});

  final String? initialCategoryId;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final DestinationRepository _destinationRepository = DestinationRepository();
  final RestaurantRepository _restaurantRepository = RestaurantRepository();
  final FestivalRepository _festivalRepository = FestivalRepository();
  final RegionRepository _regionRepository = RegionRepository();
  final ProvinceRepository _provinceRepository = ProvinceRepository();

  _ExploreTab _tab = _ExploreTab.destinations;
  String? _selectedCategory;

  String? _regionId;
  String? _provinceId;
  String? _provinceName;
  double? _minRating;
  List<Region> _regions = [];
  List<Province> _provinces = [];
  bool get _hasFilters => _provinceId != null || _minRating != null;

  List<Destination>? _destinations;
  DocumentSnapshot<Map<String, dynamic>>? _destinationsCursor;
  bool _destinationsHasMore = true;
  bool _loadingDestinations = false;
  Object? _destinationsError;

  List<Restaurant>? _restaurants;
  DocumentSnapshot<Map<String, dynamic>>? _restaurantsCursor;
  bool _restaurantsHasMore = true;
  bool _loadingRestaurants = false;
  Object? _restaurantsError;

  List<Festival>? _festivals;
  DocumentSnapshot<Map<String, dynamic>>? _festivalsCursor;
  bool _festivalsHasMore = true;
  bool _loadingFestivals = false;
  Object? _festivalsError;

  @override
  void initState() {
    super.initState();
    _applyInitialCategory(widget.initialCategoryId);
    _ensureLoaded(_tab);
    _loadGeography();
  }

  /// One bounded read each against the small, fixed `regions`/`provinces`
  /// reference collections — replaces the old per-content-collection
  /// `distinctProvinces()` scan, which read every destination/restaurant/
  /// festival just to dedupe province names.
  Future<void> _loadGeography() async {
    try {
      final results = await Future.wait([_regionRepository.getAll(), _provinceRepository.getAll()]);
      if (!mounted) return;
      setState(() {
        _regions = results[0] as List<Region>;
        _provinces = results[1] as List<Province>;
      });
    } catch (_) {
      // Non-critical — the filter sheet just shows fewer options.
    }
  }

  Future<void> _openFilterSheet() async {
    final applied = await showSearchFilterSheet(
      context,
      regions: _regions,
      provinces: _provinces,
      regionId: _regionId,
      provinceId: _provinceId,
      minRating: _minRating,
      onApply: (regionId, provinceId, r) => setState(() {
        _regionId = regionId;
        _provinceId = provinceId;
        final matches = _provinces.where((p) => p.id == provinceId);
        _provinceName = matches.isEmpty ? null : matches.first.name;
        _minRating = r;
      }),
    );
    if (applied == true) _invalidateAllTabsAndReload();
  }

  void _removeProvinceFilter() {
    setState(() {
      _regionId = null;
      _provinceId = null;
      _provinceName = null;
    });
    _invalidateAllTabsAndReload();
  }

  void _removeMinRatingFilter() {
    setState(() => _minRating = null);
    _invalidateAllTabsAndReload();
  }

  void _clearFilters() {
    setState(() {
      _regionId = null;
      _provinceId = null;
      _provinceName = null;
      _minRating = null;
    });
    _invalidateAllTabsAndReload();
  }

  /// Province/rating apply across all three tabs, but only the active tab
  /// is visible right now — clearing every tab's cache means the other two
  /// pick up the new filters lazily via [_ensureLoaded] next time the
  /// traveler switches to them, instead of silently showing stale results.
  void _invalidateAllTabsAndReload() {
    setState(() {
      _destinations = null;
      _destinationsCursor = null;
      _destinationsHasMore = true;
      _restaurants = null;
      _restaurantsCursor = null;
      _restaurantsHasMore = true;
      _festivals = null;
      _festivalsCursor = null;
      _festivalsHasMore = true;
    });
    _ensureLoaded(_tab);
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategoryId != widget.initialCategoryId) {
      _applyInitialCategory(widget.initialCategoryId);
      _loadDestinations(reset: true);
    }
  }

  void _applyInitialCategory(String? categoryId) {
    if (categoryId == null) return;
    switch (categoryId) {
      case 'food':
        _tab = _ExploreTab.restaurants;
        _selectedCategory = null;
      case 'festivals':
        _tab = _ExploreTab.festivals;
        _selectedCategory = null;
      default:
        _tab = _ExploreTab.destinations;
        _selectedCategory = categoryId;
    }
  }

  void _ensureLoaded(_ExploreTab tab) {
    switch (tab) {
      case _ExploreTab.destinations:
        if (_destinations == null) _loadDestinations();
      case _ExploreTab.restaurants:
        if (_restaurants == null) _loadRestaurants();
      case _ExploreTab.festivals:
        if (_festivals == null) _loadFestivals();
    }
  }

  Future<void> _loadDestinations({bool reset = false}) async {
    if (_loadingDestinations) return;
    setState(() {
      _loadingDestinations = true;
      _destinationsError = null;
      if (reset) {
        _destinations = null;
        _destinationsCursor = null;
        _destinationsHasMore = true;
      }
    });
    try {
      List<Destination> page;
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      bool hasMore;
      if (_selectedCategory != null || _hasFilters) {
        page = await _destinationRepository.filter(categoryId: _selectedCategory, provinceId: _provinceId, minRating: _minRating, limit: 60);
        cursor = null;
        hasMore = false;
      } else {
        final result = await _destinationRepository.getPage(pageSize: _pageSize, startAfter: _destinationsCursor);
        page = result.items;
        cursor = result.lastDoc;
        hasMore = result.items.length == _pageSize;
      }
      if (!mounted) return;
      setState(() {
        _destinations = [...(_destinations ?? []), ...page];
        _destinationsCursor = cursor;
        _destinationsHasMore = hasMore;
        _loadingDestinations = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _destinationsError = e;
        _loadingDestinations = false;
      });
    }
  }

  Future<void> _loadRestaurants({bool reset = false}) async {
    if (_loadingRestaurants) return;
    setState(() {
      _loadingRestaurants = true;
      _restaurantsError = null;
      if (reset) {
        _restaurants = null;
        _restaurantsCursor = null;
        _restaurantsHasMore = true;
      }
    });
    try {
      List<Restaurant> page;
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      bool hasMore;
      if (_hasFilters) {
        page = await _restaurantRepository.filter(provinceId: _provinceId, minRating: _minRating, limit: 60);
        cursor = null;
        hasMore = false;
      } else {
        final result = await _restaurantRepository.getPage(pageSize: _pageSize, startAfter: _restaurantsCursor);
        page = result.items;
        cursor = result.lastDoc;
        hasMore = result.items.length == _pageSize;
      }
      if (!mounted) return;
      setState(() {
        _restaurants = [...(_restaurants ?? []), ...page];
        _restaurantsCursor = cursor;
        _restaurantsHasMore = hasMore;
        _loadingRestaurants = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _restaurantsError = e;
        _loadingRestaurants = false;
      });
    }
  }

  Future<void> _loadFestivals({bool reset = false}) async {
    if (_loadingFestivals) return;
    setState(() {
      _loadingFestivals = true;
      _festivalsError = null;
      if (reset) {
        _festivals = null;
        _festivalsCursor = null;
        _festivalsHasMore = true;
      }
    });
    try {
      List<Festival> page;
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      bool hasMore;
      if (_hasFilters) {
        page = await _festivalRepository.filter(provinceId: _provinceId, minRating: _minRating, limit: 60);
        cursor = null;
        hasMore = false;
      } else {
        final result = await _festivalRepository.getPage(pageSize: _pageSize, startAfter: _festivalsCursor);
        page = result.items;
        cursor = result.lastDoc;
        hasMore = result.items.length == _pageSize;
      }
      if (!mounted) return;
      setState(() {
        _festivals = [...(_festivals ?? []), ...page];
        _festivalsCursor = cursor;
        _festivalsHasMore = hasMore;
        _loadingFestivals = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _festivalsError = e;
        _loadingFestivals = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Explore', style: theme.textTheme.displayMedium),
                  const SizedBox(height: 2),
                  Text('Find your next Philippine adventure', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.lg),
                  SearchBarWidget(
                    readOnly: true,
                    onTap: () => context.push(RoutePaths.search),
                    onFilterTap: _openFilterSheet,
                  ),
                  if (_hasFilters) ...[
                    const SizedBox(height: AppSpacing.sm),
                    ActiveFilterChips(
                      provinceName: _provinceName,
                      minRating: _minRating,
                      onRemoveProvince: _removeProvinceFilter,
                      onRemoveMinRating: _removeMinRatingFilter,
                      onClearAll: _clearFilters,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: _ExploreTab.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final tab = _ExploreTab.values[i];
                  return _TabChip(
                    label: switch (tab) {
                      _ExploreTab.destinations => 'Destinations',
                      _ExploreTab.restaurants => 'Restaurants',
                      _ExploreTab.festivals => 'Festivals',
                    },
                    selected: _tab == tab,
                    onTap: () {
                      setState(() => _tab = tab);
                      _ensureLoaded(tab);
                    },
                  );
                },
              ),
            ),
            if (_tab == _ExploreTab.destinations) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 106,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: mockCategories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, i) {
                    final category = mockCategories[i];
                    return CategoryCard(
                      category: category,
                      isSelected: _selectedCategory == category.id,
                      onTap: () {
                        setState(() => _selectedCategory = _selectedCategory == category.id ? null : category.id);
                        _loadDestinations(reset: true);
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: switch (_tab) {
                _ExploreTab.destinations => _buildGrid(
                    items: _destinations,
                    isLoading: _loadingDestinations,
                    error: _destinationsError,
                    hasMore: _destinationsHasMore,
                    onLoadMore: _loadDestinations,
                    onRetry: () => _loadDestinations(reset: true),
                    emptyMessage: _hasFilters
                        ? 'No destinations match your filters — try widening them.'
                        : 'No destinations in this category yet — try another one.',
                    itemBuilder: (context, width, item) => DestinationCard(
                      destination: item,
                      width: width,
                      imageHeight: _gridImageHeight,
                      onTap: () => context.push(RoutePaths.destinationDetails(item.id)),
                    ),
                  ),
                _ExploreTab.restaurants => _buildGrid(
                    items: _restaurants,
                    isLoading: _loadingRestaurants,
                    error: _restaurantsError,
                    hasMore: _restaurantsHasMore,
                    onLoadMore: _loadRestaurants,
                    onRetry: () => _loadRestaurants(reset: true),
                    emptyMessage: _hasFilters ? 'No restaurants match your filters — try widening them.' : 'No restaurants found.',
                    itemBuilder: (context, width, item) => RestaurantCard(
                      restaurant: item,
                      width: width,
                      imageHeight: _gridImageHeight,
                      onTap: () => context.push(RoutePaths.restaurantDetails(item.id)),
                    ),
                  ),
                _ExploreTab.festivals => _buildGrid(
                    items: _festivals,
                    isLoading: _loadingFestivals,
                    error: _festivalsError,
                    hasMore: _festivalsHasMore,
                    onLoadMore: _loadFestivals,
                    onRetry: () => _loadFestivals(reset: true),
                    emptyMessage: _hasFilters ? 'No festivals match your filters — try widening them.' : 'No festivals found.',
                    itemBuilder: (context, width, item) => FestivalCard(
                      festival: item,
                      width: width,
                      imageHeight: _gridImageHeight,
                      onTap: () => context.push(RoutePaths.festivalDetails(item.id)),
                    ),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid<T>({
    required List<T>? items,
    required bool isLoading,
    required Object? error,
    required bool hasMore,
    required Future<void> Function() onLoadMore,
    required VoidCallback onRetry,
    required String emptyMessage,
    required Widget Function(BuildContext, double width, T item) itemBuilder,
  }) {
    if (items == null && isLoading) {
      return LoadingWidget.carousel();
    }
    if (items == null && error != null) {
      return EmptyStateWidget(
        icon: Symbols.error_outline_rounded,
        title: 'Couldn\'t load this',
        message: AppException.from(error).message,
        actionLabel: 'Retry',
        onActionTap: onRetry,
      );
    }
    final list = items ?? const [];
    if (list.isEmpty) {
      return EmptyStateWidget(icon: Symbols.travel_explore_rounded, title: 'Nothing here yet', message: emptyMessage);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - AppSpacing.lg * 2 - AppSpacing.md) / 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.huge),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.lg,
            mainAxisExtent: _gridCellExtent,
          ),
          itemCount: list.length + (hasMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i >= list.length) {
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: AnimatedButton(label: 'Load More', filled: false, isLoading: isLoading, onPressed: isLoading ? null : onLoadMore),
              );
            }
            return itemBuilder(context, cardWidth, list[i]);
          },
        );
      },
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: selected ? Colors.white : AppColors.textPrimary),
        ),
      ),
    );
  }
}

