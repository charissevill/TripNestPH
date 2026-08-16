import 'package:flutter/material.dart';

import '../../../domain/models/province.dart';
import '../../../domain/models/region.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/listing_filters.dart';

const List<double> kRatingFilterOptions = [3, 4, 4.5];

/// Opens [SearchFilterSheet] and returns `true` if the traveler tapped
/// Apply (never on Cancel/dismiss) — the shared region/province + minimum-
/// rating/budget/distance filter used by both the Search and Explore screens.
Future<bool?> showSearchFilterSheet(
  BuildContext context, {
  required List<Region> regions,
  required List<Province> provinces,
  required String? regionId,
  required String? provinceId,
  required double? minRating,
  PriceTier? priceTier,
  double? maxDistanceKm,
  required void Function(
    String? regionId,
    String? provinceId,
    double? minRating,
    PriceTier? priceTier,
    double? maxDistanceKm,
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
      onApply: onApply,
    ),
  );
}

/// Region → Province drill-down plus minimum-rating/budget/distance
/// filters, shared across destinations, restaurants and festivals. Only
/// [provinceId] is actually applied to content queries — region is a
/// browsing aid to narrow the province list, not a filter dimension of its
/// own. Budget has no meaningful reading on festivals (no per-listing price
/// data), so it's simply ignored wherever a screen applies it to that tab.
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
    required this.onApply,
  });

  final List<Region> regions;
  final List<Province> provinces;
  final String? regionId;
  final String? provinceId;
  final double? minRating;
  final PriceTier? priceTier;
  final double? maxDistanceKm;
  final void Function(
    String? regionId,
    String? provinceId,
    double? minRating,
    PriceTier? priceTier,
    double? maxDistanceKm,
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

  void _selectRegion(String regionId, bool selected) {
    setState(() {
      _regionId = selected ? regionId : null;
      // The previously selected province may not belong to the newly
      // picked region — always clear it rather than leave a mismatched
      // filter applied invisibly.
      _provinceId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provincesInRegion = _regionId == null
        ? const <Province>[]
        : (widget.provinces.where((p) => p.regionId == _regionId).toList()..sort((a, b) => a.name.compareTo(b.name)));

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
                        const SizedBox(height: AppSpacing.lg),
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
                        if (_regionId != null) ...[
                          const SizedBox(height: AppSpacing.xl),
                          Text('Province', style: theme.textTheme.titleSmall),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: provincesInRegion.map((province) {
                              final selected = _provinceId == province.id;
                              return ChoiceChip(
                                label: Text(province.name),
                                selected: selected,
                                onSelected: (v) => setState(() => _provinceId = v ? province.id : null),
                              );
                            }).toList(),
                          ),
                        ],
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
                        }),
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          widget.onApply(_regionId, _provinceId, _minRating, _priceTier, _maxDistanceKm);
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
