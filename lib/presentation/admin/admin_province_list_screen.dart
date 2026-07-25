import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/mock/mock_regions.dart';
import '../../data/repositories/province_repository.dart';
import '../../domain/models/province.dart';

const List<String> _islandGroupOrder = ['Luzon', 'Visayas', 'Mindanao'];

enum _ProvinceSort { name, islandGroup, contentStatus }

extension on _ProvinceSort {
  String get label {
    switch (this) {
      case _ProvinceSort.name:
        return 'Name (A–Z)';
      case _ProvinceSort.islandGroup:
        return 'Island Group';
      case _ProvinceSort.contentStatus:
        return 'Content Status';
    }
  }
}

/// All 83 provinces (see Phase 1's Region -> Province -> City architecture),
/// with a search box, a "Region" dropdown to narrow down to exactly one
/// region, a sort picker (name / island group / content status — the last
/// one surfaces "content coming soon" provinces first so an LGU/admin can
/// work through the backlog), and a "content coming soon" badge on the ones
/// an LGU account still needs to fill in — tap through to
/// [AdminProvinceEditScreen] for either kind.
///
/// Region selection lives only in the "Region" filter, not as a sort mode —
/// having "Region" appear in both a Sort-by dropdown (grouping) and a Region
/// dropdown (narrowing) was confusing, so filtering is the one place that
/// concept lives now.
class AdminProvinceListScreen extends StatefulWidget {
  const AdminProvinceListScreen({super.key});

  @override
  State<AdminProvinceListScreen> createState() =>
      _AdminProvinceListScreenState();
}

class _AdminProvinceListScreenState extends State<AdminProvinceListScreen> {
  late Future<List<Province>> _future;
  String _query = '';
  _ProvinceSort _sort = _ProvinceSort.name;

  /// Null = every region. Otherwise narrows the list down to exactly one
  /// region (e.g. "Region 1" on its own), rather than only being able to
  /// group all of them together under the Region sort.
  String? _regionFilterId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ProvinceRepository().getAll();
  }

  Future<void> _refresh() async {
    setState(_load);
    try {
      await _future;
    } catch (_) {
      // Surfaced by the FutureBuilder's error state below; RefreshIndicator
      // just needs this Future to complete either way.
    }
  }

  /// Groups + sorts for display. Sorting by name has no group headers (a
  /// single `''` group); the other two modes get one header per group, each
  /// internally still alphabetical by name.
  Map<String, List<Province>> _grouped(List<Province> provinces) {
    switch (_sort) {
      case _ProvinceSort.name:
        return {
          '': [...provinces]..sort((a, b) => a.name.compareTo(b.name)),
        };
      case _ProvinceSort.islandGroup:
        return _groupBy(
          provinces,
          (p) => p.islandGroup,
          order: _islandGroupOrder,
        );
      case _ProvinceSort.contentStatus:
        return _groupBy(
          provinces,
          (p) => p.hasContent ? 'Has Content' : 'Content Coming Soon',
          order: const ['Content Coming Soon', 'Has Content'],
        );
    }
  }

  /// Groups [provinces] by [keyOf], each group internally sorted by name.
  /// Groups are ordered by [order] when given (any keys not listed sort
  /// alphabetically after the listed ones), else alphabetically by key.
  Map<String, List<Province>> _groupBy(
    List<Province> provinces,
    String Function(Province) keyOf, {
    List<String>? order,
  }) {
    final groups = <String, List<Province>>{};
    for (final p in provinces) {
      groups.putIfAbsent(keyOf(p), () => []).add(p);
    }
    for (final list in groups.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    final knownKeys = order ?? const [];
    final remainingKeys =
        groups.keys.where((k) => !knownKeys.contains(k)).toList()..sort();
    final orderedKeys = [
      ...knownKeys.where(groups.containsKey),
      ...remainingKeys,
    ];
    return {for (final k in orderedKeys) k: groups[k]!};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Provinces'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Province>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return ListView(
                  children: List.generate(6, (_) => LoadingWidget.textTile()),
                );
              }
              if (snapshot.hasError) {
                return ListView(
                  children: [
                    EmptyStateWidget(
                      icon: Symbols.error_outline_rounded,
                      title: 'Couldn\'t load provinces',
                      message: AppException.from(snapshot.error!).message,
                    ),
                  ],
                );
              }
              final filtered = (snapshot.data ?? const [])
                  .where(
                    (p) => p.name.toLowerCase().contains(_query.toLowerCase()),
                  )
                  .where(
                    (p) =>
                        _regionFilterId == null ||
                        p.regionId == _regionFilterId,
                  )
                  .toList();
              final groups = _grouped(filtered);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      0,
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search provinces...',
                        prefixIcon: Icon(Symbols.search_rounded),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Symbols.sort_rounded,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Sort by',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textTertiary),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<_ProvinceSort>(
                              isDense: true,
                              isExpanded: true,
                              value: _sort,
                              items: _ProvinceSort.values
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _sort = value ?? _sort),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Symbols.public_rounded,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Region',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textTertiary),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              isDense: true,
                              isExpanded: true,
                              value: _regionFilterId,
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Regions'),
                                ),
                                ...mockRegions.map(
                                  (r) => DropdownMenuItem<String?>(
                                    value: r.id,
                                    child: Text(r.name),
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _regionFilterId = value),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.huge,
                      ),
                      children: [
                        for (final entry in groups.entries) ...[
                          if (entry.key.isNotEmpty)
                            _GroupHeader(label: entry.key),
                          for (final province in entry.value)
                            ListTile(
                              title: Text(province.name),
                              subtitle: Text(province.regionName),
                              trailing: province.hasContent
                                  ? const Icon(
                                      Symbols.check_circle_rounded,
                                      color: AppColors.success,
                                    )
                                  : const Icon(
                                      Symbols.edit_note_rounded,
                                      color: AppColors.textTertiary,
                                    ),
                              onTap: () => context
                                  .push(
                                    RoutePaths.adminProvinceEdit(province.id),
                                  )
                                  .then((_) {
                                    if (mounted) setState(_load);
                                  }),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
