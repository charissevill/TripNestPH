import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/routes/route_paths.dart';
import '../../core/services/places_service.dart';
import '../../core/services/search_history_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/place_dedup.dart';
import '../../core/widgets/dialogs/active_filter_chips.dart';
import '../../core/widgets/dialogs/search_filter_sheet.dart';
import '../../core/widgets/details/place_details_sheet.dart';
import '../../core/widgets/indicators/rating_widget.dart';
import '../../core/widgets/inputs/search_bar_widget.dart';
import '../../core/widgets/layout/max_width_container.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/festival_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../data/repositories/region_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/search_trend_repository.dart';
import '../../domain/models/place.dart';
import '../../domain/models/province.dart';
import '../../domain/models/region.dart';

enum _ResultType { restaurant, festival, place }

/// Standard Wagner–Fischer edit-distance, used as a typo-tolerant fallback
/// once an exact substring match fails (see `_closestByEditDistance`) —
/// province/region lists are small enough (~80/~17) that an O(n·m) compare
/// against each candidate is negligible.
int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var previousRow = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final currentRow = List<int>.filled(b.length + 1, 0);
    currentRow[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final insertCost = currentRow[j] + 1;
      final deleteCost = previousRow[j + 1] + 1;
      final replaceCost = previousRow[j] + (a[i] == b[j] ? 0 : 1);
      currentRow[j + 1] = [
        insertCost,
        deleteCost,
        replaceCost,
      ].reduce((x, y) => x < y ? x : y);
    }
    previousRow = currentRow;
  }
  return previousRow[b.length];
}

class _SearchResult {
  const _SearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.rating,
    required this.provinceId,
    this.place,
  });

  final _ResultType type;
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final double rating;
  final String provinceId;

  /// Only set for [_ResultType.place] — a live Places result has no
  /// Firestore id to look back up later, so the full result travels with
  /// the tile instead (used to open [showPlaceDetailsSheet] on tap).
  final Place? place;
}

/// A dedicated full-screen search experience: debounced, live search across
/// restaurants and festivals in Firestore (LGU-curated tourist spots are
/// deliberately not part of this catalog search — see the class doc on
/// `ExploreScreen`), plus recent/trending suggestions when the field is
/// empty. Also blends in live Google Places results for real places outside
/// that curated catalog (see `_runSearch`), rendered in a trailing "More
/// places" section — this is now the primary way a traveler finds a real
/// tourist spot/attraction via Search.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.autoOpenFilter = false,
    this.restaurantRepository,
    this.festivalRepository,
    this.regionRepository,
    this.provinceRepository,
    this.placesService,
    this.searchTrendRepository,
  });

  /// True when reached via a "filter" shortcut (e.g. Home's filter icon)
  /// rather than a plain search tap — opens the filter sheet automatically
  /// once province data is loaded, instead of landing on a blank search.
  final bool autoOpenFilter;

  // Test-only overrides — production call sites never pass these (matches
  // the same optional-override pattern `AiRepository`/the data repositories
  // already use), letting a widget test inject fakes without a real Firestore/
  // Cloud Functions plugin. `regionRepository`/`provinceRepository` matter
  // even for tests that don't care about geography: their default
  // constructors touch `FirebaseFirestore.instance` eagerly, which throws
  // synchronously with no Firebase app registered (as in `flutter_test`).
  final RestaurantRepository? restaurantRepository;
  final FestivalRepository? festivalRepository;
  final RegionRepository? regionRepository;
  final ProvinceRepository? provinceRepository;
  final PlacesService? placesService;
  final SearchTrendRepository? searchTrendRepository;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  late final RestaurantRepository _restaurantRepository =
      widget.restaurantRepository ?? RestaurantRepository();
  late final FestivalRepository _festivalRepository =
      widget.festivalRepository ?? FestivalRepository();
  late final PlacesService _places = widget.placesService ?? PlacesService();
  late final RegionRepository _regionRepository =
      widget.regionRepository ?? RegionRepository();
  late final ProvinceRepository _provinceRepository =
      widget.provinceRepository ?? ProvinceRepository();
  late final SearchTrendRepository _searchTrendRepository =
      widget.searchTrendRepository ?? SearchTrendRepository();
  final SearchHistoryService _searchHistory = SearchHistoryService();

  Timer? _debounce;
  // A longer, separate debounce for recording Recent/Trending searches —
  // decoupled from the search debounce so pausing mid-typing doesn't record
  // an incomplete prefix as its own history/trend entry (see _recordSearch).
  Timer? _recordDebounce;
  String _query = '';
  List<_SearchResult> _results = [];
  bool _loading = false;
  // Shared by _runSearch and _runFilterOnly, both of which can be triggered
  // independently (typing vs. applying a filter) and race against each
  // other over the network — only the result of whichever call is still
  // the latest by the time it completes is ever applied, regardless of
  // which one's response actually arrives last.
  int _searchRequestId = 0;

  /// Set when the typed query matches a province name (e.g. "Cebu") —
  /// neither the curated destination/restaurant/festival search nor the
  /// live Places fallback ever surface this, since both are scoped to
  /// specific named attractions/businesses, not whole provinces. Matched
  /// client-side against the already-loaded `_provinces` (no extra query),
  /// and rendered as its own tile above the regular results linking
  /// straight to that province's guide page.
  Province? _provinceMatch;

  /// Same idea as [_provinceMatch] but for a whole region (e.g. "Visayas")
  /// — a region has no details page of its own in this app, so the useful
  /// result is the list of provinces inside it (rendered as one
  /// [_ProvinceMatchTile] per province, same as a direct province match).
  Region? _regionMatch;

  String? _regionId;
  String? _provinceId;
  double? _minRating;
  List<Region> _regions = [];
  List<Province> _provinces = [];
  bool get _hasFilters => _provinceId != null || _minRating != null;

  /// The traveler's own past search queries — real per-device history, not
  /// the four hardcoded strings this used to show every user.
  List<String> _recentSearches = [];

  /// The most-searched terms across every traveler (`SearchTrendRepository`).
  List<String> _trendingSearches = [];

  @override
  void initState() {
    super.initState();
    _loadGeography();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    try {
      final results = await Future.wait([
        _searchHistory.getRecent(),
        _searchTrendRepository.getTopTrending(limit: 4),
      ]);
      if (!mounted) return;
      setState(() {
        _recentSearches = results[0];
        _trendingSearches = results[1];
      });
    } catch (_) {
      // Non-critical — the suggestions view just shows fewer/no chips.
    }
  }

  Future<void> _clearRecentSearches() async {
    await _searchHistory.clear();
    if (mounted) setState(() => _recentSearches = []);
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
      if (widget.autoOpenFilter && mounted) _openFilterSheet();
    } catch (_) {
      // Non-critical — the filter sheet just shows fewer options.
    }
  }

  void _onChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _recordDebounce?.cancel();
    if (value.trim().isEmpty) {
      if (_hasFilters) {
        _runFilterOnly();
      } else {
        setState(() {
          _results = [];
          _provinceMatch = null;
          _regionMatch = null;
        });
      }
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _runSearch(value),
    );
    // Recorded only after a longer pause than the search itself — pausing
    // mid-word ("Pala" for 350ms before continuing to "Palawan") used to
    // record the incomplete prefix as its own Recent/Trending entry,
    // separate from the finished query.
    _recordDebounce = Timer(
      const Duration(milliseconds: 900),
      () => _recordSearch(value),
    );
  }

  void _recordSearch(String query) {
    unawaited(
      _searchHistory.record(query).then((updated) {
        if (mounted) setState(() => _recentSearches = updated);
      }),
    );
    unawaited(_searchTrendRepository.record(query));
  }

  /// First province whose name contains the query — provinces are few
  /// enough (~80) that a client-side scan of the already-loaded list is
  /// cheaper and simpler than a dedicated Firestore query for this. Falls
  /// back to a typo-tolerant closest match (see `_closestByEditDistance`)
  /// only when nothing contains the query outright, so a correctly-typed
  /// query is never second-guessed by a fuzzy result.
  Province? _matchingProvince(String trimmedQuery) {
    final normalized = trimmedQuery.toLowerCase();
    if (normalized.isEmpty) return null;
    for (final p in _provinces) {
      if (p.name.toLowerCase().contains(normalized)) return p;
    }
    return _closestByEditDistance(normalized, _provinces, (p) => p.name);
  }

  /// Same contains-then-fuzzy matching as [_matchingProvince], but for
  /// regions — which have no details page of their own here, so the
  /// useful result is "which provinces are in this region" (resolved at
  /// render time in `_buildResultsList` from `_regionMatch`).
  Region? _matchingRegion(String trimmedQuery) {
    final normalized = trimmedQuery.toLowerCase();
    if (normalized.isEmpty) return null;
    for (final r in _regions) {
      if (r.name.toLowerCase().contains(normalized)) return r;
    }
    return _closestByEditDistance(normalized, _regions, (r) => r.name);
  }

  /// Picks the candidate whose name is closest (by edit distance) to the
  /// query, but only if it's within a small budget scaled to the query's
  /// own length — so a short query like "Abra" (4 chars) still tolerates
  /// one typo without matching some unrelated, wildly-different name.
  T? _closestByEditDistance<T>(
    String normalizedQuery,
    List<T> candidates,
    String Function(T) nameOf,
  ) {
    T? closest;
    var bestDistance = 1 << 30;
    for (final candidate in candidates) {
      final distance = _levenshtein(
        normalizedQuery,
        nameOf(candidate).toLowerCase(),
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        closest = candidate;
      }
    }
    final maxDistance = (normalizedQuery.length * 0.3).ceil().clamp(1, 3);
    return (closest != null && bestDistance <= maxDistance) ? closest : null;
  }

  List<_SearchResult> _toResults(List restaurants, List festivals) {
    return [
      ...restaurants.map(
        (r) => _SearchResult(
          type: _ResultType.restaurant,
          id: r.id,
          title: r.name,
          subtitle: '${r.cuisine} · ${r.provinceName}',
          imageUrl: r.heroImageUrl,
          rating: r.rating,
          provinceId: r.provinceId,
        ),
      ),
      ...festivals.map(
        (f) => _SearchResult(
          type: _ResultType.festival,
          id: f.id,
          title: f.name,
          subtitle: f.provinceName,
          imageUrl: f.heroImageUrl,
          rating: f.rating,
          provinceId: f.provinceId,
        ),
      ),
    ];
  }

  Future<void> _runSearch(String query) async {
    final requestId = ++_searchRequestId;
    setState(() => _loading = true);
    try {
      final trimmed = query.trim();
      final restaurantsFuture = _restaurantRepository.searchByName(query);
      final festivalsFuture = _festivalRepository.searchByName(query);
      // A billed live API call, unlike the free Firestore prefix search
      // above — skip it for very short prefixes so every keystroke doesn't
      // fire one. `searchText` never throws (see `PlacesService`), so this
      // is safe to await alongside the try/catch below. Scoped to the
      // active province filter (when set) the same way the curated results
      // below already are — otherwise "More places" stayed nationwide even
      // while every other section had narrowed to one province.
      final placesFuture = trimmed.length >= 3
          ? _places.searchText(
              textQuery: _provinceName != null ? '$trimmed, $_provinceName, Philippines' : '$trimmed, Philippines',
              maxResultCount: 10,
            )
          : Future.value(<Place>[]);
      final restaurants = await restaurantsFuture;
      final festivals = await festivalsFuture;
      final places = await placesFuture;

      // A bare place name — a barangay, town, city or province anywhere in
      // the Philippines — resolves to just that area itself as a single
      // result (never a rich list of businesses); the exact same Places
      // Text Search limitation _matchingProvince/_matchingRegion above
      // already work around for known province/region names. Google tags
      // every administrative/geographic area with the generic `political`
      // type regardless of its granularity (barangay, city, province, ...),
      // which lets this catch all of them without having to enumerate every
      // specific type string. Whichever granularity it is, follow up with a
      // real nearby-places search centered on that area's own coordinates,
      // so the traveler still finds actual restaurants/attractions instead
      // of just "here's the area you typed". A whole region
      // (`administrative_area_level_1`) or the country itself is
      // deliberately excluded — too large an area for one fixed-radius
      // search to cover meaningfully, and _matchingRegion above already
      // surfaces a region's provinces instead.
      const excludedAreaTypes = {'administrative_area_level_1', 'country'};
      Place? areaMatch;
      for (final p in places) {
        if (p.types.contains('political') &&
            !p.types.any(excludedAreaTypes.contains) &&
            p.latitude != null &&
            p.longitude != null) {
          areaMatch = p;
          break;
        }
      }
      // A province spans far more ground than a single city/town, so it
      // needs a wider search radius to turn up anything at all.
      final isProvinceLevelArea =
          areaMatch?.types.contains('administrative_area_level_2') ?? false;
      final nearbyAreaPlacesRaw = areaMatch != null
          ? await _places.searchNearby(
              latitude: areaMatch.latitude!,
              longitude: areaMatch.longitude!,
              includedTypes: [
                ...PlaceCategory.attractions,
                ...PlaceCategory.dining,
                ...PlaceCategory.lodging,
              ],
              radiusMeters: isProvinceLevelArea ? 15000 : 5000,
              maxResultCount: 10,
            )
          : const <Place>[];
      // A fixed-radius search around a small or narrow area (e.g. Guimaras,
      // an island a few km across a strait from Iloilo City) easily leaks
      // into a neighboring city/province that happens to fall within that
      // radius — a hotel addressed in "Iloilo City" is not a real answer to
      // someone searching "Guimaras". Keep only results whose own address
      // actually names the area searched for.
      final areaNameLower = areaMatch?.name.toLowerCase();
      final nearbyAreaPlaces = areaNameLower == null
          ? const <Place>[]
          : nearbyAreaPlacesRaw
              .where((p) => p.address.toLowerCase().contains(areaNameLower))
              .toList();
      final seenPlaceIds = <String>{};
      final allLivePlaces = [
        for (final p in [...places, ...nearbyAreaPlaces])
          if (seenPlaceIds.add(p.id)) p,
      ];
      if (!mounted || requestId != _searchRequestId) return;
      var curatedResults = _toResults(restaurants, festivals);
      // Firestore's prefix-search doesn't compose with extra filters, so
      // province/rating are applied client-side on top of the text match.
      // Live Places results are exempt — provinceId/rating are Firestore-
      // catalog concepts that don't map cleanly onto them.
      if (_provinceId != null) {
        curatedResults = curatedResults
            .where((r) => r.provinceId == _provinceId)
            .toList();
      }
      if (_minRating != null) {
        curatedResults = curatedResults
            .where((r) => r.rating >= _minRating!)
            .toList();
      }

      // A live place that's also one of the curated results above (e.g. a
      // restaurant the app already has saved) shouldn't show twice — the
      // curated entry wins, since it links to a real in-app details page.
      final curatedNames = curatedResults
          .map((r) => r.title.toLowerCase())
          .toSet();
      final placeResults = allLivePlaces
          .where((p) => !isDuplicateOfCurated(p.name, curatedNames))
          .map(_placeToResult)
          .toList();

      setState(() {
        _results = [...curatedResults, ...placeResults];
        _provinceMatch = _matchingProvince(trimmed);
        _regionMatch = _matchingRegion(trimmed);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _results = [];
        _provinceMatch = null;
        _regionMatch = null;
        _loading = false;
      });
    }
  }

  _SearchResult _placeToResult(Place place) {
    return _SearchResult(
      type: _ResultType.place,
      id: place.id,
      title: place.name,
      subtitle: place.address.isNotEmpty ? place.address : place.categoryLabel,
      imageUrl: place.photoNames.isNotEmpty
          ? _places.photoUrl(place.photoNames.first)
          : '',
      rating: place.rating ?? 0,
      provinceId: '',
      place: place,
    );
  }

  Future<void> _runFilterOnly() async {
    final requestId = ++_searchRequestId;
    setState(() => _loading = true);
    try {
      final restaurants = await _restaurantRepository.filter(
        provinceId: _provinceId,
        minRating: _minRating,
      );
      final festivals = await _festivalRepository.filter(
        provinceId: _provinceId,
        minRating: _minRating,
      );
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _results = _toResults(restaurants, festivals);
        // A province/region match only ever makes sense for a typed query
        // — this path runs with an empty query (filter-only browsing), so
        // any tile left over from a previous non-empty search must clear.
        _provinceMatch = null;
        _regionMatch = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _results = [];
        _provinceMatch = null;
        _regionMatch = null;
        _loading = false;
      });
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
      onApply: (regionId, provinceId, r) {
        setState(() {
          _regionId = regionId;
          _provinceId = provinceId;
          _minRating = r;
        });
      },
    );
    if (applied != true) return;
    _rerunAfterFilterChange();
  }

  String? get _provinceName {
    final matches = _provinces.where((p) => p.id == _provinceId);
    return matches.isEmpty ? null : matches.first.name;
  }

  void _removeProvinceFilter() {
    setState(() {
      _regionId = null;
      _provinceId = null;
    });
    _rerunAfterFilterChange();
  }

  void _removeMinRatingFilter() {
    setState(() => _minRating = null);
    _rerunAfterFilterChange();
  }

  void _clearFilters() {
    setState(() {
      _regionId = null;
      _provinceId = null;
      _minRating = null;
    });
    _rerunAfterFilterChange();
  }

  void _rerunAfterFilterChange() {
    if (_query.trim().isNotEmpty) {
      _runSearch(_query);
    } else if (_hasFilters) {
      _runFilterOnly();
    } else {
      setState(() => _results = []);
    }
  }

  Future<void> _refresh() async {
    if (_query.trim().isNotEmpty) {
      await _runSearch(_query);
    } else if (_hasFilters) {
      await _runFilterOnly();
    }
  }

  void _openResult(_SearchResult result) {
    switch (result.type) {
      case _ResultType.restaurant:
        context.push(RoutePaths.restaurantDetails(result.id));
      case _ResultType.festival:
        context.push(RoutePaths.festivalDetails(result.id));
      case _ResultType.place:
        // No Firestore id to route to — the live Places result itself
        // travels with the tile (see `_SearchResult.place`).
        showPlaceDetailsSheet(
          context,
          place: result.place!,
          placesService: _places,
        );
    }
  }

  /// Curated (Firestore) results first, then — if any — a trailing "More
  /// places" section for live Places results, visually separated so it
  /// reads as "beyond what this app has saved" rather than blending in
  /// unlabeled. A plain `ListView` with pre-built children, not
  /// `ListView.separated`'s single flat item count, since the two sections
  /// need their own header/spacing between them.
  Widget _buildResultsList() {
    final curated = _results.where((r) => r.type != _ResultType.place).toList();
    final liveResults = _results
        .where((r) => r.type == _ResultType.place)
        .toList();
    final provinceMatch = _provinceMatch;
    final regionMatch = _regionMatch;
    final regionProvinces = regionMatch == null
        ? const <Province>[]
        : _provinces.where((p) => p.regionId == regionMatch.id).toList();

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: MaxWidthContainer.sidePadding(context, maxWidth: 800),
        vertical: AppSpacing.sm,
      ),
      children: [
        if (provinceMatch != null) ...[
          _ProvinceMatchTile(
            province: provinceMatch,
            onTap: () =>
                context.push(RoutePaths.provinceDetails(provinceMatch.id)),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (regionProvinces.isNotEmpty) ...[
          Text(
            'Provinces in ${regionMatch!.name}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final p in regionProvinces) ...[
            _ProvinceMatchTile(
              province: p,
              onTap: () => context.push(RoutePaths.provinceDetails(p.id)),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
        for (final r in curated) ...[
          _SearchResultTile(result: r, onTap: () => _openResult(r)),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (liveResults.isNotEmpty) ...[
          if (curated.isNotEmpty) const SizedBox(height: AppSpacing.md),
          Text('More places', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          for (final r in liveResults) ...[
            _SearchResultTile(result: r, onTap: () => _openResult(r)),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recordDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                MaxWidthContainer.sidePadding(context, maxWidth: 800),
                AppSpacing.sm,
                MaxWidthContainer.sidePadding(context, maxWidth: 800),
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.pop(),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: const Padding(
                      padding: EdgeInsets.all(AppSpacing.xs),
                      child: Icon(Symbols.arrow_back_rounded),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: SearchBarWidget(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onChanged,
                      onFilterTap: _openFilterSheet,
                      hintText: 'Search destinations, food, festivals...',
                    ),
                  ),
                ],
              ),
            ),
            if (_hasFilters)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  MaxWidthContainer.sidePadding(context, maxWidth: 800),
                  0,
                  MaxWidthContainer.sidePadding(context, maxWidth: 800),
                  AppSpacing.sm,
                ),
                child: ActiveFilterChips(
                  provinceName: _provinceName,
                  minRating: _minRating,
                  onRemoveProvince: _removeProvinceFilter,
                  onRemoveMinRating: _removeMinRatingFilter,
                  onClearAll: _clearFilters,
                ),
              ),
            Expanded(
              child: _query.trim().isEmpty && !_hasFilters
                  ? _SuggestionsView(
                      recentSearches: _recentSearches,
                      trendingSearches: _trendingSearches,
                      onClearRecent: _clearRecentSearches,
                      onTapSuggestion: (value) {
                        _controller.text = value;
                        _onChanged(value);
                      },
                    )
                  : _loading && _results.isEmpty
                  ? ListView(
                      children: List.generate(
                        6,
                        (_) => LoadingWidget.listRow(),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child:
                          _results.isEmpty &&
                              _provinceMatch == null &&
                              _regionMatch == null
                          ? ListView(
                              children: [
                                EmptyStateWidget(
                                  icon: Symbols.search_off_rounded,
                                  title: 'No results for "$_query"',
                                  message:
                                      'Try a different keyword, or browse by category from Explore instead.',
                                  actionLabel: 'Go to Explore',
                                  onActionTap: () =>
                                      context.go(RoutePaths.explore),
                                ),
                              ],
                            )
                          : _buildResultsList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionsView extends StatelessWidget {
  const _SuggestionsView({
    required this.recentSearches,
    required this.trendingSearches,
    required this.onClearRecent,
    required this.onTapSuggestion,
  });

  final List<String> recentSearches;

  /// Real search-volume terms across every traveler (`SearchTrendRepository`).
  final List<String> trendingSearches;
  final VoidCallback onClearRecent;
  final ValueChanged<String> onTapSuggestion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: MaxWidthContainer.sidePadding(context, maxWidth: 800),
        vertical: AppSpacing.md,
      ),
      children: [
        if (recentSearches.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Searches',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(onPressed: onClearRecent, child: const Text('Clear')),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: recentSearches
                .map(
                  (s) => _SuggestionChip(
                    label: s,
                    icon: Symbols.history_rounded,
                    onTap: () => onTapSuggestion(s),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
        if (trendingSearches.isNotEmpty) ...[
          Text(
            'Trending Searches',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: trendingSearches
                .map(
                  (s) => _SuggestionChip(
                    label: s,
                    icon: Symbols.local_fire_department_rounded,
                    onTap: () => onTapSuggestion(s),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ],
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown above the regular results when the typed query matches a whole
/// province (e.g. "Cebu") — neither the curated destination/restaurant/
/// festival search nor the live Places fallback ever surface a province
/// itself, since both are scoped to specific named places, not the region
/// as a whole. Styled distinctly (tinted background, "Province Guide"
/// label) so it reads as a different kind of result, not just another tile.
class _ProvinceMatchTile extends StatelessWidget {
  const _ProvinceMatchTile({required this.province, required this.onTap});

  final Province province;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: province.heroImageUrl.isEmpty
                  ? Container(
                      width: 64,
                      height: 64,
                      color: AppColors.background,
                      alignment: Alignment.center,
                      child: const Icon(
                        Symbols.map_rounded,
                        color: AppColors.textTertiary,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: province.heroImageUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Province Guide',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    province.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    province.regionName,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Symbols.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.result, required this.onTap});

  final _SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLivePlace = result.type == _ResultType.place;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: result.imageUrl.isEmpty
                  ? Container(
                      width: 64,
                      height: 64,
                      color: AppColors.background,
                      alignment: Alignment.center,
                      child: const Icon(
                        Symbols.location_on_rounded,
                        color: AppColors.textTertiary,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: result.imageUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Signals "live web result" vs. an in-app catalog
                      // listing — the traveler should be able to tell these
                      // apart at a glance, not just discover it on tap.
                      if (isLivePlace) ...[
                        const Icon(
                          Symbols.public_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          result.title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.subtitle,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Live Places results have no in-app review list to back
                  // up a star rating (unlike curated restaurants/festivals,
                  // which do) — showing one would imply reviews the
                  // traveler can't actually read here.
                  if (!isLivePlace && result.rating > 0) ...[
                    const SizedBox(height: 4),
                    RatingWidget(rating: result.rating, starSize: 14),
                  ],
                ],
              ),
            ),
            const Icon(
              Symbols.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
