import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/services/places_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/cards/place_card.dart';
import '../../core/widgets/details/place_details_sheet.dart';
import '../../core/widgets/inputs/search_bar_widget.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../domain/models/place.dart';

enum _SortOption { relevance, distance, rating, reviewCount }

class _CategoryOption {
  const _CategoryOption({
    required this.label,
    required this.searchPhrase,
    this.includedTypes,
  });

  final String label;

  /// Phrase used to build a text-search query for this category, e.g.
  /// 'hotels' -> 'hotels in Palawan, Philippines'.
  final String searchPhrase;

  /// Null for categories with no dedicated Places type (e.g. beaches) —
  /// those are only reachable via text search, not `searchNearby`.
  final List<String>? includedTypes;
}

const _categories = [
  _CategoryOption(
    label: 'Attractions',
    searchPhrase: 'tourist attractions',
    includedTypes: PlaceCategory.attractions,
  ),
  _CategoryOption(label: 'Beaches', searchPhrase: 'beaches'),
  _CategoryOption(
    label: 'Hotels',
    searchPhrase: 'hotels',
    includedTypes: PlaceCategory.lodging,
  ),
  _CategoryOption(
    label: 'Dining',
    searchPhrase: 'restaurants and cafes',
    includedTypes: PlaceCategory.dining,
  ),
  _CategoryOption(
    label: 'Shopping',
    searchPhrase: 'shopping malls',
    includedTypes: PlaceCategory.shopping,
  ),
  _CategoryOption(
    label: 'Gas Stations',
    searchPhrase: 'gas stations',
    includedTypes: PlaceCategory.gasStations,
  ),
  _CategoryOption(
    label: 'Pharmacies',
    searchPhrase: 'pharmacies',
    includedTypes: PlaceCategory.pharmacies,
  ),
  _CategoryOption(
    label: 'Hospitals',
    searchPhrase: 'hospitals',
    includedTypes: PlaceCategory.hospitals,
  ),
  _CategoryOption(
    label: 'ATMs',
    searchPhrase: 'ATMs',
    includedTypes: PlaceCategory.atms,
  ),
  _CategoryOption(
    label: 'Transport',
    searchPhrase: 'bus and transport terminals',
    includedTypes: PlaceCategory.transportTerminals,
  ),
];

/// Full browse experience for Places API results: category chips, sort,
/// and a text search — reached via "See All" from any [NearbyPlacesSection],
/// so it always starts already scoped to a coordinate or an area.
class NearbyPlacesScreen extends StatefulWidget {
  const NearbyPlacesScreen({
    super.key,
    required this.title,
    this.includedTypes,
    this.latitude,
    this.longitude,
    this.areaLabel,
  });

  final String title;
  final List<String>? includedTypes;
  final double? latitude;
  final double? longitude;
  final String? areaLabel;

  bool get _isNearbyMode => latitude != null && longitude != null;

  @override
  State<NearbyPlacesScreen> createState() => _NearbyPlacesScreenState();
}

class _NearbyPlacesScreenState extends State<NearbyPlacesScreen> {
  final PlacesService _places = PlacesService();
  final TextEditingController _searchController = TextEditingController();

  late _CategoryOption _category = _categories.firstWhere(
    (c) =>
        widget.includedTypes != null &&
        c.includedTypes != null &&
        c.includedTypes!.first == widget.includedTypes!.first,
    orElse: () => _categories.first,
  );
  _SortOption _sort = _SortOption.relevance;
  String? _searchOverride;
  Timer? _debounce;

  List<Place>? _results;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<Place> results;
      if (_searchOverride != null && _searchOverride!.trim().isNotEmpty) {
        results = await _places.searchText(textQuery: _searchOverride!.trim());
      } else if (widget._isNearbyMode && _category.includedTypes != null) {
        results = await _places.searchNearby(
          latitude: widget.latitude!,
          longitude: widget.longitude!,
          includedTypes: _category.includedTypes!,
        );
      } else if (widget._isNearbyMode) {
        // No dedicated Places type for this category (e.g. beaches) — text
        // search biased toward the known coordinate instead of a plain
        // nearby lookup.
        results = await _places.searchText(
          textQuery: _category.searchPhrase,
          biasLatitude: widget.latitude,
          biasLongitude: widget.longitude,
        );
      } else {
        results = await _places.searchText(
          textQuery:
              '${_category.searchPhrase} in ${widget.areaLabel}, Philippines',
        );
      }
      if (!mounted) return;
      setState(() {
        _results = _sorted(results);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  List<Place> _sorted(List<Place> places) {
    final list = [...places];
    switch (_sort) {
      case _SortOption.relevance:
        break; // already ranked by rankPreference: POPULARITY server-side
      case _SortOption.distance:
        list.sort(
          (a, b) => (a.distanceMeters ?? double.infinity).compareTo(
            b.distanceMeters ?? double.infinity,
          ),
        );
      case _SortOption.rating:
        list.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      case _SortOption.reviewCount:
        list.sort(
          (a, b) => (b.userRatingCount ?? 0).compareTo(a.userRatingCount ?? 0),
        );
    }
    return list;
  }

  void _selectCategory(_CategoryOption category) {
    if (category == _category) return;
    setState(() {
      _category = category;
      _searchOverride = null;
      _searchController.clear();
    });
    _load();
  }

  void _selectSort(_SortOption sort) {
    if (sort == _sort) return;
    setState(() {
      _sort = sort;
      if (_results != null) _results = _sorted(_results!);
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _searchOverride = value.trim().isEmpty ? null : value);
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            if (!widget._isNearbyMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: SearchBarWidget(
                  controller: _searchController,
                  hintText: 'Search places...',
                  onChanged: _onSearchChanged,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: _selectableCategories.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final category = _selectableCategories[i];
                  final selected = category == _category;
                  return ChoiceChip(
                    label: Text(category.label),
                    selected: selected,
                    onSelected: (_) => _selectCategory(category),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Sort: ', style: theme.textTheme.bodySmall),
                  DropdownButton<_SortOption>(
                    value: _sort,
                    underline: const SizedBox.shrink(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _SortOption.relevance,
                        child: Text('Relevance'),
                      ),
                      DropdownMenuItem(
                        value: _SortOption.distance,
                        child: Text('Distance'),
                      ),
                      DropdownMenuItem(
                        value: _SortOption.rating,
                        child: Text('Rating'),
                      ),
                      DropdownMenuItem(
                        value: _SortOption.reviewCount,
                        child: Text('Popularity'),
                      ),
                    ],
                    onChanged: (value) =>
                        value != null ? _selectSort(value) : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: RefreshIndicator(onRefresh: _load, child: _buildResults()),
            ),
          ],
        ),
      ),
    );
  }

  // Every category is selectable in both modes now: nearby-mode categories
  // with no dedicated Places type (e.g. beaches) fall back to a
  // coordinate-biased text search in `_load()` above instead of being
  // hidden from the filter row.
  List<_CategoryOption> get _selectableCategories => _categories;

  Widget _buildResults() {
    if (_loading) return LoadingWidget.grid();
    if (_error != null) {
      return EmptyStateWidget(
        icon: Symbols.error_outline_rounded,
        title: 'Couldn\'t load places',
        message:
            'Something went wrong reaching Google Places — pull to refresh or try again shortly.',
        actionLabel: 'Retry',
        onActionTap: _load,
      );
    }
    final places = _results ?? const [];
    if (places.isEmpty) {
      return const EmptyStateWidget(
        icon: Symbols.location_off_rounded,
        title: 'No places found',
        message: 'Nothing matched this search — try a different category.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth - AppSpacing.lg * 2 - AppSpacing.md) / 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.huge,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.lg,
            mainAxisExtent: 140 + 92,
          ),
          itemCount: places.length,
          itemBuilder: (context, i) {
            final place = places[i];
            final imageUrl = place.photoNames.isNotEmpty
                ? _places.photoUrl(place.photoNames.first)
                : '';
            return PlaceCard(
              place: place,
              imageUrl: imageUrl,
              width: cardWidth,
              imageHeight: 140,
              onTap: () => showPlaceDetailsSheet(
                context,
                place: place,
                placesService: _places,
              ),
            );
          },
        );
      },
    );
  }
}
