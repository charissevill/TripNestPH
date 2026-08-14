import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/routes/route_paths.dart';
import '../../core/services/places_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/place_dedup.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/cards/category_card.dart';
import '../../core/widgets/cards/festival_card.dart';
import '../../core/widgets/cards/place_card.dart';
import '../../core/widgets/cards/restaurant_card.dart';
import '../../core/widgets/details/explore_map_view.dart';
import '../../core/widgets/details/place_details_sheet.dart';
import '../../core/widgets/dialogs/active_filter_chips.dart';
import '../../core/widgets/dialogs/search_filter_sheet.dart';
import '../../core/widgets/inputs/search_bar_widget.dart';
import '../../core/widgets/layout/max_width_container.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/mock/mock_categories.dart';
import '../../data/repositories/festival_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../data/repositories/region_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../domain/models/festival.dart';
import '../../domain/models/place.dart';
import '../../domain/models/province.dart';
import '../../domain/models/region.dart';
import '../../domain/models/restaurant.dart';

enum _ExploreTab { destinations, restaurants, festivals }

/// Image height used for every card in the two-column grid, kept in sync
/// with [_gridCellExtent] so card content never overflows its grid cell.
const double _gridImageHeight = 140;
const double _gridCellExtent = _gridImageHeight + 92;
const int _pageSize = 20;

/// Category chip id -> a Places `searchText` phrase — mirrors
/// `search_screen.dart`'s `_categoryKeywords` reasoning: Google has no
/// dedicated Places type for "beach" or "waterfall", so these ride on a
/// free-text query instead of `PlaceCategory`'s `includedTypes` lists.
/// `food`/`festivals` never reach here — `_applyInitialCategory` routes
/// those straight to the Restaurants/Festivals tabs instead.
const Map<String, String> _placesCategoryPhrase = {
  'beaches': 'beaches',
  'mountains': 'mountains and hiking trails',
  'historical': 'historical landmarks',
  'nature': 'waterfalls and nature parks',
};

/// Browse-everything screen: category chips + a destinations / restaurants /
/// festivals tab switch, rendered as a responsive, paginated two-column grid.
/// Destinations is live Google Places only — LGU/admin-curated `tourist_spots`
/// content is deliberately not shown here anymore (it's still readable
/// elsewhere, e.g. a direct link to an existing bookmark/review still works;
/// it's just no longer discoverable by browsing). Restaurants still blends
/// live Places with the business-owner-submitted catalog (not LGU content —
/// see `RestaurantRepository.createFromBusiness`), which still provides the
/// paginated "Load More" tail. Festivals stays 100% curated: Google Places
/// models physical points of interest, not time-bound recurring events, so
/// there's no sensible query to run for it.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    this.initialCategoryId,
    this.placesService,
    this.restaurantRepository,
    this.festivalRepository,
    this.regionRepository,
    this.provinceRepository,
  });

  final String? initialCategoryId;

  // Test-only overrides — production call sites never pass these (same
  // pattern `SearchScreen` already uses): a widget test can inject a
  // `FakeFirebaseFirestore`-backed repository and a fake `PlacesService`
  // caller without touching the real Firestore/Cloud Functions plugins.
  final PlacesService? placesService;
  final RestaurantRepository? restaurantRepository;
  final FestivalRepository? festivalRepository;
  final RegionRepository? regionRepository;
  final ProvinceRepository? provinceRepository;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final RestaurantRepository _restaurantRepository =
      widget.restaurantRepository ?? RestaurantRepository();
  late final FestivalRepository _festivalRepository =
      widget.festivalRepository ?? FestivalRepository();
  late final RegionRepository _regionRepository =
      widget.regionRepository ?? RegionRepository();
  late final ProvinceRepository _provinceRepository =
      widget.provinceRepository ?? ProvinceRepository();
  late final PlacesService _places = widget.placesService ?? PlacesService();

  _ExploreTab _tab = _ExploreTab.destinations;
  String? _selectedCategory;
  bool _mapMode = false;
  Timer? _categoryDebounce;

  String? _regionId;
  String? _provinceId;
  String? _provinceName;
  double? _minRating;
  List<Region> _regions = [];
  List<Province> _provinces = [];
  bool get _hasFilters => _provinceId != null || _minRating != null;

  List<Place>? _destinationPlaces;
  bool _loadingDestinations = false;
  Object? _destinationsError;
  // Bumped by every reset load; a completing request only ever applies its
  // result if it's still the latest one — otherwise a slow request from
  // before a filter/category change would land after, and silently
  // overwrite, the fresher one that superseded it.
  int _destinationsRequestId = 0;

  List<Restaurant>? _restaurants;
  DocumentSnapshot<Map<String, dynamic>>? _restaurantsCursor;
  bool _restaurantsHasMore = true;
  bool _loadingRestaurants = false;
  Object? _restaurantsError;
  List<Place> _liveRestaurantPlaces = [];
  int _restaurantsRequestId = 0;

  List<Festival>? _festivals;
  DocumentSnapshot<Map<String, dynamic>>? _festivalsCursor;
  bool _festivalsHasMore = true;
  bool _loadingFestivals = false;
  Object? _festivalsError;
  int _festivalsRequestId = 0;

  List<Object>? get _restaurantItems =>
      _restaurants == null ? null : [..._liveRestaurantPlaces, ..._restaurants!];

  String _destinationsTextQuery() {
    final phrase = _placesCategoryPhrase[_selectedCategory] ?? 'top tourist attractions';
    return _provinceName != null ? '$phrase in $_provinceName, Philippines' : '$phrase in the Philippines';
  }

  String _restaurantsTextQuery() =>
      _provinceName != null ? 'restaurants in $_provinceName, Philippines' : 'best restaurants in the Philippines';

  /// Drops any live result whose own address doesn't name [areaName] — a
  /// fixed-radius/area text search can resolve into a neighboring city or
  /// province (the exact "Guimaras search returning Iloilo City hotels" leak
  /// found and fixed in `search_screen.dart`) — then drops any live result
  /// that's a near-duplicate of an already-curated name.
  List<Place> _filterLivePlaces(List<Place> places, {required String? areaName, required Set<String> curatedNamesLower}) {
    var filtered = places;
    if (areaName != null) {
      final areaLower = areaName.toLowerCase();
      filtered = filtered.where((p) => p.address.toLowerCase().contains(areaLower)).toList();
    }
    return filtered.where((p) => !isDuplicateOfCurated(p.name, curatedNamesLower)).toList();
  }

  @override
  void initState() {
    super.initState();
    _applyInitialCategory(widget.initialCategoryId);
    _ensureLoaded(_tab);
    _loadGeography();
  }

  @override
  void dispose() {
    _categoryDebounce?.cancel();
    super.dispose();
  }

  /// One bounded read each against the small, fixed `regions`/`provinces`
  /// reference collections — replaces the old per-content-collection
  /// `distinctProvinces()` scan, which read every destination/restaurant/
  /// festival just to dedupe province names.
  Future<void> _loadGeography() async {
    try {
      final results = await Future.wait([
        _regionRepository.getAll(),
        _provinceRepository.getAll(),
      ]);
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
      _destinationPlaces = null;
      _restaurants = null;
      _restaurantsCursor = null;
      _restaurantsHasMore = true;
      _liveRestaurantPlaces = [];
      _festivals = null;
      _festivalsCursor = null;
      _festivalsHasMore = true;
    });
    // Forces a fresh load for the active tab regardless of whether a
    // previous request is still in flight — _ensureLoaded's "only if not
    // already loaded" guard is for lazy tab-switching, not for this
    // "the filters just changed, the old request is now wrong" case.
    switch (_tab) {
      case _ExploreTab.destinations:
        _loadDestinations(reset: true);
      case _ExploreTab.restaurants:
        _loadRestaurants(reset: true);
      case _ExploreTab.festivals:
        _loadFestivals(reset: true);
    }
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
        if (_destinationPlaces == null) _loadDestinations();
      case _ExploreTab.restaurants:
        if (_restaurants == null) _loadRestaurants();
      case _ExploreTab.festivals:
        if (_festivals == null) _loadFestivals();
    }
  }

  /// Destinations is Google Places only — no curated `tourist_spots` tail
  /// (see the class doc comment). One bounded fetch per filter/category
  /// selection; Google's own 20-result cap means there's no further page to
  /// load, so this never re-fires on its own once loaded (there's no "Load
  /// More" for this tab).
  Future<void> _loadDestinations({bool reset = false}) async {
    // A reset always proceeds even if a previous load is still in flight —
    // otherwise a filter/category change applied mid-load would be silently
    // dropped by this guard, and the stale in-flight request's result would
    // land moments later with nothing to correct it.
    if (_loadingDestinations && !reset) return;
    final requestId = ++_destinationsRequestId;
    setState(() {
      _loadingDestinations = true;
      _destinationsError = null;
      if (reset) _destinationPlaces = null;
    });
    try {
      final places = await _places.searchText(
        textQuery: _destinationsTextQuery(),
        maxResultCount: 20,
        rethrowOnError: true,
      );
      final filtered = _provinceName == null
          ? places
          : places
              .where((p) => p.address.toLowerCase().contains(_provinceName!.toLowerCase()))
              .toList();

      if (!mounted || requestId != _destinationsRequestId) return;
      setState(() {
        _destinationPlaces = filtered;
        _loadingDestinations = false;
      });
    } catch (e) {
      if (!mounted || requestId != _destinationsRequestId) return;
      setState(() {
        _destinationsError = e;
        _loadingDestinations = false;
      });
    }
  }

  Future<void> _loadRestaurants({bool reset = false}) async {
    if (_loadingRestaurants && !reset) return;
    final requestId = ++_restaurantsRequestId;
    final needsLiveFetch = reset || _restaurants == null;
    setState(() {
      _loadingRestaurants = true;
      _restaurantsError = null;
      if (reset) {
        _restaurants = null;
        _restaurantsCursor = null;
        _restaurantsHasMore = true;
        _liveRestaurantPlaces = [];
      }
    });
    try {
      final livePlacesFuture = needsLiveFetch
          ? _places.searchText(textQuery: _restaurantsTextQuery(), maxResultCount: 20)
          : Future.value(_liveRestaurantPlaces);

      List<Restaurant> page;
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      bool hasMore;
      if (_hasFilters || _mapMode) {
        page = await _restaurantRepository.filter(
          provinceId: _provinceId,
          minRating: _minRating,
          limit: 150,
        );
        cursor = null;
        hasMore = false;
      } else {
        final result = await _restaurantRepository.getPage(
          pageSize: _pageSize,
          startAfter: _restaurantsCursor,
        );
        page = result.items;
        cursor = result.lastDoc;
        hasMore = result.items.length == _pageSize;
      }

      var livePlaces = await livePlacesFuture;
      final List<Restaurant> allRestaurants = [...(_restaurants ?? []), ...page];
      // Re-run every time, not just on a fresh fetch: a "Load More" tap
      // pages in more curated restaurants, and a live Places result shown
      // earlier can duplicate one of those — re-filtering against the now-
      // fuller curated set (idempotent for names already excluded) catches
      // it instead of only ever checking against the first page.
      livePlaces = _filterLivePlaces(
        livePlaces,
        areaName: _provinceName,
        curatedNamesLower: allRestaurants.map((r) => r.name.toLowerCase()).toSet(),
      );

      if (!mounted || requestId != _restaurantsRequestId) return;
      setState(() {
        _restaurants = allRestaurants;
        _restaurantsCursor = cursor;
        _restaurantsHasMore = hasMore;
        _liveRestaurantPlaces = livePlaces;
        _loadingRestaurants = false;
      });
    } catch (e) {
      if (!mounted || requestId != _restaurantsRequestId) return;
      setState(() {
        _restaurantsError = e;
        _loadingRestaurants = false;
      });
    }
  }

  Future<void> _loadFestivals({bool reset = false}) async {
    if (_loadingFestivals && !reset) return;
    final requestId = ++_festivalsRequestId;
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
      if (_hasFilters || _mapMode) {
        page = await _festivalRepository.filter(
          provinceId: _provinceId,
          minRating: _minRating,
          limit: 150,
        );
        cursor = null;
        hasMore = false;
      } else {
        final result = await _festivalRepository.getPage(
          pageSize: _pageSize,
          startAfter: _festivalsCursor,
        );
        page = result.items;
        cursor = result.lastDoc;
        hasMore = result.items.length == _pageSize;
      }
      if (!mounted || requestId != _festivalsRequestId) return;
      setState(() {
        _festivals = [...(_festivals ?? []), ...page];
        _festivalsCursor = cursor;
        _festivalsHasMore = hasMore;
        _loadingFestivals = false;
      });
    } catch (e) {
      if (!mounted || requestId != _festivalsRequestId) return;
      setState(() {
        _festivalsError = e;
        _loadingFestivals = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sidePadding = MaxWidthContainer.sidePadding(context, maxWidth: 1400);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                sidePadding,
                AppSpacing.sm,
                sidePadding,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Explore', style: theme.textTheme.displayMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Find your next Philippine adventure',
                    style: theme.textTheme.bodyMedium,
                  ),
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
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: sidePadding),
                      itemCount: _ExploreTab.values.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.sm),
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
                ),
                Padding(
                  padding: EdgeInsets.only(right: sidePadding),
                  child: IconButton(
                    icon: Icon(_mapMode ? Symbols.view_list_rounded : Symbols.map_rounded),
                    tooltip: _mapMode ? 'Show as list' : 'Show as map',
                    onPressed: () {
                      setState(() => _mapMode = !_mapMode);
                      _invalidateAllTabsAndReload();
                    },
                  ),
                ),
              ],
            ),
            if (_tab == _ExploreTab.destinations) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 106,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: sidePadding),
                  itemCount: mockCategories.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, i) {
                    final category = mockCategories[i];
                    return CategoryCard(
                      category: category,
                      isSelected: _selectedCategory == category.id,
                      onTap: () {
                        // Food/Festivals have no Places search phrase (see
                        // _placesCategoryPhrase) — they're not Destinations
                        // filters at all, they're a shortcut to the other
                        // two tabs, exactly like _applyInitialCategory
                        // already treats them coming in from a deep link.
                        // Filtering by them here used to silently no-op.
                        if (category.id == 'food' || category.id == 'festivals') {
                          setState(() {
                            _tab = category.id == 'food' ? _ExploreTab.restaurants : _ExploreTab.festivals;
                            _selectedCategory = null;
                          });
                          _ensureLoaded(_tab);
                          return;
                        }
                        setState(
                          () => _selectedCategory =
                              _selectedCategory == category.id
                              ? null
                              : category.id,
                        );
                        // Debounced — each tap fires a billed Places call,
                        // so rapidly tapping through categories should only
                        // query the final selection, not every intermediate
                        // one (same shape as search_screen.dart's own
                        // typing debounce).
                        _categoryDebounce?.cancel();
                        _categoryDebounce = Timer(
                          const Duration(milliseconds: 350),
                          () => _loadDestinations(reset: true),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _mapMode
                  ? switch (_tab) {
                      _ExploreTab.destinations => _buildMap(
                        items: _destinationPlaces,
                        isLoading: _loadingDestinations,
                        error: _destinationsError,
                        onRetry: () => _loadDestinations(reset: true),
                        emptyMessage: _hasFilters
                            ? 'No destinations match your filters — try widening them.'
                            : 'No mapped destinations yet.',
                        markerFor: (p) => !p.hasCoordinates
                            ? null
                            : Marker(
                                markerId: MarkerId('place-${p.id}'),
                                position: LatLng(p.latitude!, p.longitude!),
                                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
                                infoWindow: InfoWindow(
                                  title: p.name,
                                  onTap: () => showPlaceDetailsSheet(context, place: p, placesService: _places),
                                ),
                              ),
                      ),
                      _ExploreTab.restaurants => _buildMap(
                        items: _restaurantItems,
                        isLoading: _loadingRestaurants,
                        error: _restaurantsError,
                        onRetry: () => _loadRestaurants(reset: true),
                        emptyMessage: _hasFilters
                            ? 'No restaurants match your filters — try widening them.'
                            : 'No mapped restaurants yet.',
                        markerFor: (item) => switch (item) {
                          Restaurant r when r.hasCoordinates => Marker(
                            markerId: MarkerId('restaurant-${r.id}'),
                            position: LatLng(r.latitude!, r.longitude!),
                            infoWindow: InfoWindow(
                              title: r.name,
                              onTap: () => context.push(RoutePaths.restaurantDetails(r.id)),
                            ),
                          ),
                          Place p when p.hasCoordinates => Marker(
                            markerId: MarkerId('place-${p.id}'),
                            position: LatLng(p.latitude!, p.longitude!),
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
                            infoWindow: InfoWindow(
                              title: p.name,
                              onTap: () => showPlaceDetailsSheet(context, place: p, placesService: _places),
                            ),
                          ),
                          Object() => null,
                        },
                      ),
                      _ExploreTab.festivals => _buildMap(
                        items: _festivals,
                        isLoading: _loadingFestivals,
                        error: _festivalsError,
                        onRetry: () => _loadFestivals(reset: true),
                        emptyMessage: _hasFilters
                            ? 'No festivals match your filters — try widening them.'
                            : 'No mapped festivals yet.',
                        markerFor: (item) => !item.hasCoordinates
                            ? null
                            : Marker(
                                markerId: MarkerId('festival-${item.id}'),
                                position: LatLng(item.latitude!, item.longitude!),
                                infoWindow: InfoWindow(
                                  title: item.name,
                                  onTap: () => context.push(RoutePaths.festivalDetails(item.id)),
                                ),
                              ),
                      ),
                    }
                  : switch (_tab) {
                      _ExploreTab.destinations => _buildGrid(
                        items: _destinationPlaces,
                        isLoading: _loadingDestinations,
                        error: _destinationsError,
                        // Google's 20-result cap is the whole result set —
                        // there's no further page to load, unlike the
                        // curated-catalog "Load More" the Restaurants tab
                        // still has.
                        hasMore: false,
                        onLoadMore: _loadDestinations,
                        onRetry: () => _loadDestinations(reset: true),
                        onRefresh: () => _loadDestinations(reset: true),
                        emptyMessage: _hasFilters
                            ? 'No destinations match your filters — try widening them.'
                            : 'No destinations in this category yet — try another one.',
                        itemBuilder: (context, width, p) => PlaceCard(
                          place: p,
                          width: width,
                          imageHeight: _gridImageHeight,
                          imageUrl: p.photoNames.isNotEmpty ? _places.photoUrl(p.photoNames.first) : '',
                          onTap: () => showPlaceDetailsSheet(context, place: p, placesService: _places),
                        ),
                      ),
                      _ExploreTab.restaurants => _buildGrid(
                        items: _restaurantItems,
                        isLoading: _loadingRestaurants,
                        error: _restaurantsError,
                        hasMore: _restaurantsHasMore,
                        onLoadMore: _loadRestaurants,
                        onRetry: () => _loadRestaurants(reset: true),
                        onRefresh: () => _loadRestaurants(reset: true),
                        emptyMessage: _hasFilters
                            ? 'No restaurants match your filters — try widening them.'
                            : 'No restaurants found.',
                        itemBuilder: (context, width, item) => switch (item) {
                          Restaurant r => RestaurantCard(
                            restaurant: r,
                            width: width,
                            imageHeight: _gridImageHeight,
                            onTap: () => context.push(RoutePaths.restaurantDetails(r.id)),
                          ),
                          Place p => PlaceCard(
                            place: p,
                            width: width,
                            imageHeight: _gridImageHeight,
                            imageUrl: p.photoNames.isNotEmpty ? _places.photoUrl(p.photoNames.first) : '',
                            onTap: () => showPlaceDetailsSheet(context, place: p, placesService: _places),
                          ),
                          Object() => const SizedBox.shrink(),
                        },
                      ),
                      _ExploreTab.festivals => _buildGrid(
                        items: _festivals,
                        isLoading: _loadingFestivals,
                        error: _festivalsError,
                        hasMore: _festivalsHasMore,
                        onLoadMore: _loadFestivals,
                        onRetry: () => _loadFestivals(reset: true),
                        onRefresh: () => _loadFestivals(reset: true),
                        emptyMessage: _hasFilters
                            ? 'No festivals match your filters — try widening them.'
                            : 'No festivals found.',
                        itemBuilder: (context, width, item) => FestivalCard(
                          festival: item,
                          width: width,
                          imageHeight: _gridImageHeight,
                          onTap: () =>
                              context.push(RoutePaths.festivalDetails(item.id)),
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
    required Future<void> Function() onRefresh,
    required String emptyMessage,
    required Widget Function(BuildContext, double width, T item) itemBuilder,
  }) {
    if (items == null && isLoading) {
      return LoadingWidget.grid();
    }
    if (items == null && error != null) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            EmptyStateWidget(
              icon: Symbols.error_outline_rounded,
              title: 'Couldn\'t load this',
              message: AppException.from(error).message,
              actionLabel: 'Retry',
              onActionTap: onRetry,
            ),
          ],
        ),
      );
    }
    final list = items ?? const [];
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            EmptyStateWidget(
              icon: Symbols.travel_explore_rounded,
              title: 'Nothing here yet',
              message: emptyMessage,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = context.gridColumns;
          final side = MaxWidthContainer.sidePadding(context, maxWidth: 1400);
          final cardWidth =
              (constraints.maxWidth - side * 2 - AppSpacing.md * (columns - 1)) / columns;
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(
              side,
              0,
              side,
              // Taller than AppSpacing.huge alone — this tab also has the
              // floating AI Chat FAB (`_AiChatFab` in `MainShellScreen`)
              // hovering above the bottom nav bar, which the plain nav-bar
              // clearance doesn't account for, letting the last row sit
              // right behind it.
              AppSpacing.huge + AppSpacing.xxxl,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.lg,
              mainAxisExtent: _gridCellExtent,
            ),
            itemCount: list.length + (hasMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i >= list.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: AnimatedButton(
                    label: 'Load More',
                    filled: false,
                    isLoading: isLoading,
                    onPressed: isLoading ? null : onLoadMore,
                  ),
                );
              }
              return itemBuilder(context, cardWidth, list[i]);
            },
          );
        },
      ),
    );
  }

  /// Mirrors [_buildGrid]'s loading/error handling, but renders every
  /// coordinate-bearing item as a pin on one [ExploreMapView] instead of a
  /// paginated grid — [items] here is the map-mode batch loaded by
  /// `_load*`'s `_mapMode` branch (see those methods), not the paginated
  /// list-mode one.
  Widget _buildMap<T>({
    required List<T>? items,
    required bool isLoading,
    required Object? error,
    required VoidCallback onRetry,
    required String emptyMessage,
    required Marker? Function(T item) markerFor,
  }) {
    if (items == null && isLoading) {
      return const Center(child: CircularProgressIndicator());
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
    final markers = (items ?? const []).map(markerFor).whereType<Marker>().toSet();
    return ExploreMapView(markers: markers, emptyMessage: emptyMessage);
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : AppColors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
