import 'package:flutter/material.dart';

import '../../../domain/models/business.dart';
import '../../../domain/models/province.dart';
import '../../../domain/models/region.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/listing_filters.dart';

const List<double> kRatingFilterOptions = [3, 4, 4.5];

/// Opens [SearchFilterSheet] and returns `true` if the traveler tapped
/// Apply (never on Cancel/dismiss) — the shared region/province + minimum-
/// rating/budget/distance/accessibility filter used by both the Search and
/// Explore screens.
Future<bool?> showSearchFilterSheet(
  BuildContext context, {
  required List<Region> regions,
  required List<Province> provinces,
  required String? regionId,
  required String? provinceId,
  required double? minRating,
  PriceTier? priceTier,
  double? maxDistanceKm,
  String? accessibilityTag,
  PlaceTypeFilter? placeTypeFilter,
  // Explore already separates attractions/restaurants/festivals via its own
  // tabs — showing this too would be a second, disconnected control for the
  // same thing (Explore doesn't wire the picked value into anything). Search
  // has no such tabs, so it's the one place this actually does something.
  bool showCategoryFilter = true,
  required void Function(
    String? regionId,
    String? provinceId,
    double? minRating,
    PriceTier? priceTier,
    double? maxDistanceKm,
    String? accessibilityTag,
    PlaceTypeFilter? placeTypeFilter,
  )
  onApply,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => SearchFilterSheet(
      regions: regions,
      provinces: provinces,
      regionId: regionId,
      provinceId: provinceId,
      minRating: minRating,
      priceTier: priceTier,
      maxDistanceKm: maxDistanceKm,
      accessibilityTag: accessibilityTag,
      placeTypeFilter: placeTypeFilter,
      showCategoryFilter: showCategoryFilter,
      onApply: onApply,
    ),
  );
}

/// Region + Province filters, shared across destinations, restaurants and
/// festivals. The Province list is always selectable — picking a Region
/// first just narrows it down to that region's provinces, it's not a
/// required step. Only [provinceId] is actually applied to content queries;
/// [regionId] is purely a browsing aid. Budget/accessibility have no
/// meaningful reading on destinations or festivals (no per-listing price/
/// accessibility data), so they're simply ignored wherever a screen applies
/// them to those tabs.
class SearchFilterSheet extends StatefulWidget {
  const SearchFilterSheet({
    super.key,
    required this.regions,
    required this.provinces,
    required this.regionId,
    required this.provinceId,
    required this.minRating,
    this.priceTier,
    this.maxDistanceKm,
    this.accessibilityTag,
    this.placeTypeFilter,
    this.showCategoryFilter = true,
    required this.onApply,
  });

  final List<Region> regions;
  final List<Province> provinces;
  final String? regionId;
  final String? provinceId;
  final double? minRating;
  final PriceTier? priceTier;
  final double? maxDistanceKm;
  final String? accessibilityTag;
  final PlaceTypeFilter? placeTypeFilter;
  final bool showCategoryFilter;
  final void Function(
    String? regionId,
    String? provinceId,
    double? minRating,
    PriceTier? priceTier,
    double? maxDistanceKm,
    String? accessibilityTag,
    PlaceTypeFilter? placeTypeFilter,
  )
  onApply;

  @override
  State<SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<SearchFilterSheet> {
  late String? _regionId = widget.regionId;
  late String? _provinceId = widget.provinceId;
  late double? _minRating = widget.minRating;
  late PriceTier? _priceTier = widget.priceTier;
  late double? _maxDistanceKm = widget.maxDistanceKm;
  late String? _accessibilityTag = widget.accessibilityTag;
  late PlaceTypeFilter? _placeTypeFilter = widget.placeTypeFilter;

  void _selectRegion(String regionId, bool selected) {
    setState(() {
      _regionId = selected ? regionId : null;
      // A province already picked from a different region no longer
      // matches this narrower list — clear it rather than leave a
      // mismatched filter applied invisibly. A province picked with no
      // region active is never cleared by this, since it can't mismatch.
      if (_provinceId != null) {
        final stillValid = widget.provinces.any(
          (p) => p.id == _provinceId && (!selected || p.regionId == regionId),
        );
        if (!stillValid) _provinceId = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectableProvinces = (_regionId == null
        ? widget.provinces.toList()
        : widget.provinces.where((p) => p.regionId == _regionId).toList())
      ..sort((a, b) => a.name.compareTo(b.name));

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          // The number of regions/provinces (and their Wrap-ed chip rows) is
          // unbounded, so on a short device the sheet's content can be
          // taller than the screen — cap it and let the middle section
          // scroll instead of overflowing, while Reset/Apply stay pinned.
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(AppRadius.pill)),
                  ),
                ),
                Text('Filter Results', style: theme.textTheme.headlineSmall),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.showCategoryFilter) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Text('Category', style: theme.textTheme.titleSmall),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: PlaceTypeFilter.values.map((type) {
                              final selected = _placeTypeFilter == type;
                              return ChoiceChip(
                                label: Text(type.label),
                                selected: selected,
                                onSelected: (v) => setState(() => _placeTypeFilter = v ? type : null),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        Text('Region', style: theme.textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.sm),
                        if (widget.regions.isEmpty)
                          Text('Loading regions...', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary))
                        else
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: widget.regions.map((region) {
                              final selected = _regionId == region.id;
                              return ChoiceChip(
                                label: Text(region.name),
                                selected: selected,
                                onSelected: (v) => _selectRegion(region.id, v),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: AppSpacing.xl),
                        Text('Province', style: theme.textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: selectableProvinces.map((province) {
                            final selected = _provinceId == province.id;
                            return ChoiceChip(
                              label: Text(province.name),
                              selected: selected,
                              onSelected: (v) => setState(() => _provinceId = v ? province.id : null),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text('Minimum Rating', style: theme.textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          children: kRatingFilterOptions.map((r) {
                            final selected = _minRating == r;
                            return ChoiceChip(
                              label: Text('${r.toStringAsFixed(1)}+ ★'),
                              selected: selected,
                              onSelected: (v) => setState(() => _minRating = v ? r : null),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text('Budget', style: theme.textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          children: PriceTier.values.map((tier) {
                            final selected = _priceTier == tier;
                            return ChoiceChip(
                              label: Text(tier.label),
                              selected: selected,
                              onSelected: (v) => setState(() => _priceTier = v ? tier : null),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text('Distance', style: theme.textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          children: kDistanceFilterOptionsKm.map((km) {
                            final selected = _maxDistanceKm == km;
                            return ChoiceChip(
                              label: Text('Within ${km.toStringAsFixed(0)} km'),
                              selected: selected,
                              onSelected: (v) => setState(() => _maxDistanceKm = v ? km : null),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text('Accessibility', style: theme.textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: kAccessibilityTagOptions.map((tag) {
                            final selected = _accessibilityTag == tag;
                            return ChoiceChip(
                              label: Text(tag),
                              selected: selected,
                              onSelected: (v) => setState(() => _accessibilityTag = v ? tag : null),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _regionId = null;
                          _provinceId = null;
                          _minRating = null;
                          _priceTier = null;
                          _maxDistanceKm = null;
                          _accessibilityTag = null;
                          _placeTypeFilter = null;
                        }),
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          widget.onApply(_regionId, _provinceId, _minRating, _priceTier, _maxDistanceKm, _accessibilityTag, _placeTypeFilter);
                          Navigator.of(context).pop(true);
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
