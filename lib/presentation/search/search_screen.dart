import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/routes/route_paths.dart';
import '../../core/services/search_history_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/dialogs/active_filter_chips.dart';
import '../../core/widgets/dialogs/search_filter_sheet.dart';
import '../../core/widgets/indicators/rating_widget.dart';
import '../../core/widgets/inputs/search_bar_widget.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/festival_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../data/repositories/region_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../domain/models/province.dart';
import '../../domain/models/region.dart';

enum _ResultType { destination, restaurant, festival }

class _SearchResult {
  const _SearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.rating,
    required this.provinceId,
  });

  final _ResultType type;
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final double rating;
  final String provinceId;
}

/// A dedicated full-screen search experience: debounced, live search across
/// destinations, restaurants and festivals in Firestore, plus recent/
/// popular suggestions when the field is empty.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.autoOpenFilter = false});

  /// True when reached via a "filter" shortcut (e.g. Home's filter icon)
  /// rather than a plain search tap — opens the filter sheet automatically
  /// once province data is loaded, instead of landing on a blank search.
  final bool autoOpenFilter;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final DestinationRepository _destinationRepository = DestinationRepository();
  final RestaurantRepository _restaurantRepository = RestaurantRepository();
  final FestivalRepository _festivalRepository = FestivalRepository();
  final RegionRepository _regionRepository = RegionRepository();
  final ProvinceRepository _provinceRepository = ProvinceRepository();
  final SearchHistoryService _searchHistory = SearchHistoryService();

  Timer? _debounce;
  String _query = '';
  List<_SearchResult> _results = [];
  bool _loading = false;

  String? _regionId;
  String? _provinceId;
  double? _minRating;
  List<Region> _regions = [];
  List<Province> _provinces = [];
  bool get _hasFilters => _provinceId != null || _minRating != null;

  /// The traveler's own past search queries — real per-device history, not
  /// the four hardcoded strings this used to show every user.
  List<String> _recentSearches = [];

  /// Real top-reviewed destination names (`DestinationRepository.getPopular`),
  /// in place of the four made-up category phrases this used to show.
  List<String> _popularDestinations = [];

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
        _destinationRepository.getPopular(limit: 4),
      ]);
      if (!mounted) return;
      setState(() {
        _recentSearches = results[0] as List<String>;
        _popularDestinations = (results[1] as List)
            .map((d) => d.name as String)
            .toList();
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
    if (value.trim().isEmpty) {
      if (_hasFilters) {
        _runFilterOnly();
      } else {
        setState(() => _results = []);
      }
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _runSearch(value),
    );
  }

  List<_SearchResult> _toResults(
    List destinations,
    List restaurants,
    List festivals,
  ) {
    return [
      ...destinations.map(
        (d) => _SearchResult(
          type: _ResultType.destination,
          id: d.id,
          title: d.name,
          subtitle: d.provinceName,
          imageUrl: d.heroImageUrl,
          rating: d.rating,
          provinceId: d.provinceId,
        ),
      ),
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
    setState(() => _loading = true);
    unawaited(
      _searchHistory.record(query).then((updated) {
        if (mounted) setState(() => _recentSearches = updated);
      }),
    );
    try {
      final destinationsFuture = _destinationRepository.searchByName(query);
      final restaurantsFuture = _restaurantRepository.searchByName(query);
      final festivalsFuture = _festivalRepository.searchByName(query);
      final destinations = await destinationsFuture;
      final restaurants = await restaurantsFuture;
      final festivals = await festivalsFuture;
      if (!mounted) return;
      var results = _toResults(destinations, restaurants, festivals);
      // Firestore's prefix-search doesn't compose with extra filters, so
      // province/rating are applied client-side on top of the text match.
      if (_provinceId != null)
        results = results.where((r) => r.provinceId == _provinceId).toList();
      if (_minRating != null)
        results = results.where((r) => r.rating >= _minRating!).toList();
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _loading = false;
      });
    }
  }

  Future<void> _runFilterOnly() async {
    setState(() => _loading = true);
    try {
      final destinations = await _destinationRepository.filter(
        provinceId: _provinceId,
        minRating: _minRating,
      );
      final restaurants = await _restaurantRepository.filter(
        provinceId: _provinceId,
        minRating: _minRating,
      );
      final festivals = await _festivalRepository.filter(
        provinceId: _provinceId,
        minRating: _minRating,
      );
      if (!mounted) return;
      setState(() {
        _results = _toResults(destinations, restaurants, festivals);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
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
      case _ResultType.destination:
        context.push(RoutePaths.destinationDetails(result.id));
      case _ResultType.restaurant:
        context.push(RoutePaths.restaurantDetails(result.id));
      case _ResultType.festival:
        context.push(RoutePaths.festivalDetails(result.id));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
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
                      popularDestinations: _popularDestinations,
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
                      child: _results.isEmpty
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
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.sm,
                              ),
                              itemCount: _results.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, i) {
                                final r = _results[i];
                                return _SearchResultTile(
                                  result: r,
                                  onTap: () => _openResult(r),
                                );
                              },
                            ),
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
    required this.popularDestinations,
    required this.onClearRecent,
    required this.onTapSuggestion,
  });

  final List<String> recentSearches;
  final List<String> popularDestinations;
  final VoidCallback onClearRecent;
  final ValueChanged<String> onTapSuggestion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
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
        if (popularDestinations.isNotEmpty) ...[
          Text(
            'Popular Destinations',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: popularDestinations
                .map(
                  (s) => _SuggestionChip(
                    label: s,
                    icon: Symbols.trending_up_rounded,
                    onTap: () => onTapSuggestion(s),
                  ),
                )
                .toList(),
          ),
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

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.result, required this.onTap});

  final _SearchResult result;
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
              child: CachedNetworkImage(
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
                  Text(
                    result.title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.subtitle,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  RatingWidget(rating: result.rating, starSize: 14),
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
