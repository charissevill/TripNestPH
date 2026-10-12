import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/layout/scroll_aware_search_header.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/mock/mock_regions.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/festival_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../domain/models/admin_user.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/festival.dart';
import '../../domain/models/province.dart';
import 'widgets/admin_page_header.dart';

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
/// work through the backlog), and a status badge telling the ones with
/// content apart from the ones an LGU account still needs to fill in — tap
/// through to [AdminProvinceEditScreen] for either kind.
///
/// Region selection lives only in the "Region" filter, not as a sort mode —
/// having "Region" appear in both a Sort-by dropdown (grouping) and a Region
/// dropdown (narrowing) was confusing, so filtering is the one place that
/// concept lives now.
///
/// This screen only loads and scopes the list; [AdminProvinceListView] is
/// what lays it out.
class AdminProvinceListScreen extends StatefulWidget {
  const AdminProvinceListScreen({super.key});

  @override
  State<AdminProvinceListScreen> createState() =>
      _AdminProvinceListScreenState();
}

class _AdminProvinceListScreenState extends State<AdminProvinceListScreen> {
  late Future<List<Province>> _future;

  /// Re-fetched live (not trusted from the caller) the same way
  /// `AdminHomeScreen` re-checks its own role — an 'lgu' account only ever
  /// sees/manages the one province staged for it, enforced again server-side
  /// by `firestore.rules`' `canManageProvince`.
  AdminUser? _admin;

  bool get _isLguScoped => _admin?.role == AdminRole.lgu && _admin?.provinceId != null;

  /// What the LGU account's own province holds — only loaded for one.
  Future<List<Destination>>? _spots;
  Future<List<Festival>>? _festivals;

  @override
  void initState() {
    super.initState();
    _load();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;
    final admin = await AdminRepository().getById(uid);
    if (!mounted) return;
    setState(() {
      _admin = admin;
      final provinceId = admin?.provinceId;
      if (admin?.role == AdminRole.lgu && provinceId != null) {
        _spots = DestinationRepository().getAllForProvinceAdmin(provinceId);
        _festivals = FestivalRepository()
            .getAllForAdmin()
            .then((festivals) => festivals.where((f) => f.provinceId == provinceId).toList());
      }
    });
  }

  /// Same `go`-on-desktop / `push`-elsewhere split as `AdminHomeScreen`'s
  /// own module tiles.
  void _openSection(String path) {
    if (context.windowSize == WindowSize.expanded) {
      context.go(path);
    } else {
      context.push(path);
    }
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

  @override
  Widget build(BuildContext context) {
    return AdminPortalTheme(
      child: Builder(builder: _buildScaffold),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: adminPageHeader(context, title: _isLguScoped ? 'My Province' : 'Provinces'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Province>>(
            future: _future,
            builder: (context, snapshot) {
              // A reload (pull-to-refresh, coming back from the edit screen)
              // keeps showing the list it already has, so the search text,
              // filter and page aren't thrown away while it refetches.
              if (!snapshot.hasData &&
                  snapshot.connectionState != ConnectionState.done) {
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
              return AdminProvinceListView(
                provinces: (snapshot.data ?? const [])
                    .where((p) => !_isLguScoped || p.id == _admin!.provinceId)
                    .toList(),
                singleProvince: _isLguScoped,
                spots: _spots,
                festivals: _festivals,
                onOpenTouristSpots: () => _openSection(RoutePaths.adminTouristSpots),
                onOpenFestivals: () => _openSection(RoutePaths.adminFestivals),
                onOpen: (province) => context
                    .push(RoutePaths.adminProvinceEdit(province.id))
                    .then((_) {
                      if (mounted) setState(_load);
                    }),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The Provinces list itself: search + region filter on top, then either a
/// paginated table (thumbnail, name, region, status) once there's room for
/// its columns, or — on a phone-width screen — the same rows as one
/// scrolling list with the region tucked under each name.
class AdminProvinceListView extends StatefulWidget {
  const AdminProvinceListView({
    super.key,
    required this.provinces,
    required this.onOpen,
    this.singleProvince = false,
    this.spots,
    this.festivals,
    this.onOpenTouristSpots,
    this.onOpenFestivals,
  });

  final List<Province> provinces;
  final ValueChanged<Province> onOpen;

  /// An 'lgu' account's view: [provinces] is only ever its own one, so the
  /// search, region filter, sort and pager — all there to find a province
  /// among many — are left out.
  final bool singleProvince;

  /// Only used by the [singleProvince] view: that province's own content.
  final Future<List<Destination>>? spots;
  final Future<List<Festival>>? festivals;
  final VoidCallback? onOpenTouristSpots;
  final VoidCallback? onOpenFestivals;

  @override
  State<AdminProvinceListView> createState() => _AdminProvinceListViewState();
}

class _AdminProvinceListViewState extends State<AdminProvinceListView> {
  /// Below this the Region and Status columns no longer fit beside the name.
  static const double _tableMinWidth = 720;
  static const double _rowHeight = 72;

  /// The table normally shows exactly as many rows as fit, so paging replaces
  /// scrolling. A window too short for even this many gets a fixed page that
  /// scrolls instead of a page of one or two rows.
  static const int _minFittedRows = 4;
  static const int _fallbackPageSize = 10;

  String _query = '';
  _ProvinceSort _sort = _ProvinceSort.name;

  /// Null = every region. Otherwise narrows the list down to exactly one
  /// region (e.g. "Region 1" on its own), rather than only being able to
  /// group all of them together under the Region sort.
  String? _regionFilterId;

  /// Zero-based; clamped at build time, since a filter can shrink the list
  /// out from under it.
  int _page = 0;

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

  String get _regionLabel {
    if (_regionFilterId == null) return 'All Regions';
    for (final region in mockRegions) {
      if (region.id == _regionFilterId) return region.name;
    }
    return 'All Regions';
  }

  Widget _searchField() {
    return TextField(
      decoration: const InputDecoration(
        hintText: 'Search provinces...',
        prefixIcon: Icon(Symbols.search_rounded),
      ),
      onChanged: (value) => setState(() {
        _query = value;
        _page = 0;
      }),
    );
  }

  Widget _regionMenu() {
    return _PillMenu<String>(
      icon: Symbols.location_on_rounded,
      label: _regionLabel,
      tooltip: 'Filter by region',
      // A popup item with a null value reads as "dismissed", so "All
      // Regions" travels as an empty id instead.
      items: [
        const PopupMenuItem(value: '', child: Text('All Regions')),
        for (final region in mockRegions)
          PopupMenuItem(value: region.id, child: Text(region.name)),
      ],
      onSelected: (value) => setState(() {
        _regionFilterId = value.isEmpty ? null : value;
        _page = 0;
      }),
    );
  }

  List<PopupMenuEntry<_ProvinceSort>> get _sortItems => [
        for (final sort in _ProvinceSort.values)
          PopupMenuItem(value: sort, child: Text(sort.label)),
      ];

  void _setSort(_ProvinceSort sort) => setState(() {
        _sort = sort;
        _page = 0;
      });

  @override
  Widget build(BuildContext context) {
    if (widget.singleProvince && widget.provinces.length == 1) {
      final province = widget.provinces.single;
      return _MyProvinceView(
        province: province,
        onEdit: () => widget.onOpen(province),
        spots: widget.spots,
        festivals: widget.festivals,
        onOpenTouristSpots: widget.onOpenTouristSpots,
        onOpenFestivals: widget.onOpenFestivals,
      );
    }
    final query = _query.toLowerCase();
    final filtered = widget.provinces
        .where((p) => p.name.toLowerCase().contains(query))
        .where((p) => _regionFilterId == null || p.regionId == _regionFilterId)
        .toList();
    final groups = _grouped(filtered);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _tableMinWidth) {
          return _buildTable(context, groups);
        }
        return _buildList(context, groups);
      },
    );
  }

  Widget _buildTable(BuildContext context, Map<String, List<Province>> groups) {
    final theme = Theme.of(context);
    final rows = [for (final group in groups.values) ...group];
    final headerStyle = theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w500,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.singleProvince
                ? 'The province your account manages.'
                : 'Manage and view all provinces in the Philippines.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (!widget.singleProvince) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: _searchField()),
                const SizedBox(width: AppSpacing.md),
                SizedBox(width: 220, child: _regionMenu()),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: theme.dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.adminViolet.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ColoredBox(
                    color: _violetOf(context).withValues(alpha: 0.05),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxs),
                      child: Row(
                        children: [
                          Expanded(
                            flex: _ProvinceRow.nameFlex,
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: widget.singleProvince
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                      child: Text('Name', style: headerStyle),
                                    )
                                  : PopupMenuButton<_ProvinceSort>(
                                tooltip: 'Sort by',
                                initialValue: _sort,
                                onSelected: _setSort,
                                itemBuilder: (context) => _sortItems,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Symbols.sort_rounded, size: 20, color: AppColors.textSecondary),
                                      const SizedBox(width: AppSpacing.sm),
                                      Flexible(
                                        child: Text(_sort.label, style: headerStyle, overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: _ProvinceRow.regionFlex,
                            child: Text('Region', style: headerStyle),
                          ),
                          SizedBox(
                            width: _ProvinceRow.statusWidth + _ProvinceRow.chevronWidth,
                            child: Text('Status', style: headerStyle),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 1, color: theme.dividerColor),
                  Expanded(
                    child: rows.isEmpty
                        ? const SingleChildScrollView(
                            physics: AlwaysScrollableScrollPhysics(),
                            child: _NoProvinces(),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final fitted = (constraints.maxHeight / _rowHeight).floor();
                              final pageSize = fitted >= _minFittedRows ? fitted : _fallbackPageSize;
                              final pageCount = (rows.length / pageSize).ceil();
                              final page = _page.clamp(0, pageCount - 1);
                              final start = page * pageSize;
                              final end = (start + pageSize).clamp(0, rows.length);
                              return Column(
                                children: [
                                  Expanded(
                                    child: ListView.separated(
                                      // Still pulls to refresh when every row fits.
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      itemCount: end - start,
                                      separatorBuilder: (context, index) =>
                                          Divider(height: 1, color: theme.dividerColor),
                                      itemBuilder: (context, index) {
                                        final province = rows[start + index];
                                        return _ProvinceRow(
                                          province: province,
                                          // The row's own divider is part of its slot.
                                          height: _rowHeight - 1,
                                          wide: true,
                                          onTap: () => widget.onOpen(province),
                                        );
                                      },
                                    ),
                                  ),
                                  if (!widget.singleProvince) ...[
                                  Divider(height: 1, color: theme.dividerColor),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg,
                                      vertical: AppSpacing.sm,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Showing ${start + 1}–$end of ${rows.length} '
                                            '${rows.length == 1 ? 'province' : 'provinces'}',
                                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        _Pager(
                                          page: page,
                                          pageCount: pageCount,
                                          onChanged: (value) => setState(() => _page = value),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ],
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, Map<String, List<Province>> groups) {
    if (widget.singleProvince) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.sm, AppSpacing.xs, AppSpacing.huge),
        children: [
          if (widget.provinces.isEmpty) const _NoProvinces(),
          for (final province in widget.provinces)
            _ProvinceRow(province: province, wide: false, onTap: () => widget.onOpen(province)),
        ],
      );
    }
    // Search, sort and region filter slide away while scrolling and return
    // on scroll-up.
    return CollapsibleSearchHeader(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
        child: Column(
          children: [
            _searchField(),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: _regionMenu()),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _PillMenu<_ProvinceSort>(
                    icon: Symbols.sort_rounded,
                    label: _sort.label,
                    tooltip: 'Sort by',
                    items: _sortItems,
                    onSelected: _setSort,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 0, AppSpacing.xs, AppSpacing.huge),
        children: [
          if (groups.values.every((group) => group.isEmpty)) const _NoProvinces(),
          for (final entry in groups.entries) ...[
            if (entry.key.isNotEmpty) _GroupHeader(label: entry.key),
            for (final province in entry.value)
              _ProvinceRow(
                province: province,
                wide: false,
                onTap: () => widget.onOpen(province),
              ),
          ],
        ],
      ),
    );
  }
}

/// The Admin Portal's violet, a lighter step of it on a dark surface where
/// the full-strength one doesn't have the contrast to read as text.
Color _violetOf(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark ? AppColors.adminVioletLight : AppColors.adminViolet;
}

class _NoProvinces extends StatelessWidget {
  const _NoProvinces();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      icon: Symbols.search_off_rounded,
      title: 'No provinces found',
      message: 'Try a different name or region.',
    );
  }
}

/// A rounded, outlined button that opens a menu — the "All Regions" filter
/// beside the search box, and the sort picker on a phone-width screen.
class _PillMenu<T> extends StatelessWidget {
  const _PillMenu({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.items,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<T>(
      tooltip: tooltip,
      onSelected: onSelected,
      itemBuilder: (context) => items,
      // Seventeen regions would otherwise run the menu off a short window.
      constraints: const BoxConstraints(maxHeight: 420),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: _violetOf(context)),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Symbols.keyboard_arrow_down_rounded, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// One province: thumbnail and name, then — in the table ([wide]) — its
/// region and status in their own columns. The phone-width list folds the
/// region under the name and shrinks the status to its icon.
class _ProvinceRow extends StatelessWidget {
  const _ProvinceRow({
    required this.province,
    required this.wide,
    required this.onTap,
    this.height,
  });

  static const int nameFlex = 5;
  static const int regionFlex = 4;
  static const double statusWidth = 150;
  static const double chevronWidth = 32;

  final Province province;
  final bool wide;
  final VoidCallback onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = Text(
      province.name,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final region = Text(
      province.regionName,
      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    const chevron = Icon(Symbols.chevron_right_rounded, color: AppColors.textSecondary);

    return InkWell(
      onTap: onTap,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(
          horizontal: wide ? AppSpacing.xl : AppSpacing.sm,
          vertical: wide ? 0 : AppSpacing.xs,
        ),
        child: Row(
          children: [
            if (wide) ...[
              Expanded(
                flex: nameFlex,
                child: Row(
                  children: [
                    _ProvinceThumbnail(province: province),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: name),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ),
              ),
              Expanded(
                flex: regionFlex,
                child: Row(
                  children: [
                    Icon(Symbols.location_on_rounded, size: 20, color: _violetOf(context)),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: region),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ),
              ),
              SizedBox(
                width: statusWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _StatusBadge(hasContent: province.hasContent),
                ),
              ),
              const SizedBox(
                width: chevronWidth,
                child: Align(alignment: AlignmentDirectional.centerEnd, child: chevron),
              ),
            ] else ...[
              _ProvinceThumbnail(province: province),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [name, const SizedBox(height: 2), region],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _StatusBadge(hasContent: province.hasContent, compact: true),
              chevron,
            ],
          ],
        ),
      ),
    );
  }
}

class _ProvinceThumbnail extends StatelessWidget {
  const _ProvinceThumbnail({required this.province});

  static const double _size = 48;

  final Province province;

  @override
  Widget build(BuildContext context) {
    // No photo yet (or one that won't load) is the norm for a province still
    // waiting on its content, so that gets a deliberate tile, not a gap.
    final placeholder = ColoredBox(
      color: _violetOf(context).withValues(alpha: 0.12),
      child: Center(
        child: Icon(Symbols.landscape_rounded, size: 24, color: _violetOf(context)),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(
        width: _size,
        height: _size,
        child: province.heroImageUrl.isEmpty
            ? placeholder
            : CachedNetworkImage(
                imageUrl: province.heroImageUrl,
                fit: BoxFit.cover,
                // Decoded at thumbnail size rather than the hero's full one.
                memCacheWidth: 144,
                placeholder: (context, url) => placeholder,
                errorWidget: (context, url, error) => placeholder,
              ),
      ),
    );
  }
}

/// "Active" for a province travelers can already read, "Coming soon" for
/// one that's still taxonomy-only (`Province.hasContent`). Always an icon
/// plus — outside [compact] — its label, never color alone.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.hasContent, this.compact = false});

  final bool hasContent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = hasContent ? 'Active' : 'Coming soon';
    final color = hasContent ? AppColors.secondaryDark : AppColors.textSecondary;
    final icon = Icon(
      hasContent ? Symbols.check_circle_rounded : Symbols.edit_note_rounded,
      size: 20,
      fill: hasContent ? 1 : 0,
      color: hasContent ? AppColors.success : AppColors.textTertiary,
    );
    if (compact) return Tooltip(message: label, child: icon);
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 6, AppSpacing.sm, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Previous / numbered pages / next. Long runs collapse to the first and
/// last page around the current one ("1 2 3 4 5 … 12").
class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.pageCount, required this.onChanged});

  /// Zero-based.
  final int page;
  final int pageCount;
  final ValueChanged<int> onChanged;

  /// One-based page numbers to show, null for an elided run.
  List<int?> get _items {
    final current = page + 1;
    if (pageCount <= 7) return [for (var i = 1; i <= pageCount; i++) i];
    if (current <= 4) return [1, 2, 3, 4, 5, null, pageCount];
    if (current >= pageCount - 3) {
      return [1, null, for (var i = pageCount - 4; i <= pageCount; i++) i];
    }
    return [1, null, current - 1, current, current + 1, null, pageCount];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final violet = _violetOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous page',
          visualDensity: VisualDensity.compact,
          onPressed: page > 0 ? () => onChanged(page - 1) : null,
          icon: const Icon(Symbols.chevron_left_rounded),
        ),
        for (final item in _items)
          if (item == null)
            SizedBox(
              width: 32,
              child: Text(
                '…',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: item == page + 1 ? violet : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: item == page + 1 ? null : () => onChanged(item - 1),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                    alignment: Alignment.center,
                    child: Text(
                      '$item',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: item == page + 1 ? Colors.white : AppColors.textSecondary,
                        fontWeight: item == page + 1 ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        IconButton(
          tooltip: 'Next page',
          visualDensity: VisualDensity.compact,
          onPressed: page < pageCount - 1 ? () => onChanged(page + 1) : null,
          icon: const Icon(Symbols.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, AppSpacing.sm, AppSpacing.xs),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// An 'lgu' account's Provinces screen: its one province as a cover card
/// with the edit action, then that province's tourist spots and upcoming
/// festivals — instead of a one-row table.
class _MyProvinceView extends StatelessWidget {
  const _MyProvinceView({
    required this.province,
    required this.onEdit,
    this.spots,
    this.festivals,
    this.onOpenTouristSpots,
    this.onOpenFestivals,
  });

  /// Below this the shortcut cards and festival tiles stack in one column.
  static const double _wideMinWidth = 720;

  final Province province;
  final VoidCallback onEdit;
  final Future<List<Destination>>? spots;
  final Future<List<Festival>>? festivals;
  final VoidCallback? onOpenTouristSpots;
  final VoidCallback? onOpenFestivals;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideMinWidth;
        final gutter = wide ? AppSpacing.xl : AppSpacing.md;
        final spotCount = _ProvinceShortcutCard(
          icon: Symbols.place_rounded,
          color: AppColors.adminBlue,
          label: 'Tourist spots',
          items: spots,
          onTap: onOpenTouristSpots,
        );
        final festivalCount = _ProvinceShortcutCard(
          icon: Symbols.celebration_rounded,
          color: AppColors.adminPink,
          label: 'Festivals',
          items: festivals,
          onTap: onOpenFestivals,
        );

        return ListView(
          // Still pulls to refresh when everything fits.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(gutter, AppSpacing.xs, gutter, AppSpacing.huge),
          children: [
            _ProvinceCover(province: province, onEdit: onEdit, wide: wide),
            const SizedBox(height: AppSpacing.lg),
            if (wide)
              Row(
                children: [
                  Expanded(child: spotCount),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: festivalCount),
                ],
              )
            else ...[
              spotCount,
              const SizedBox(height: AppSpacing.sm),
              festivalCount,
            ],
            const SizedBox(height: AppSpacing.xl),
            _ProvinceSectionHeader(title: 'Tourist spots', onViewAll: onOpenTouristSpots),
            const SizedBox(height: AppSpacing.sm),
            _ProvinceSpotStrip(spots: spots, onTap: onOpenTouristSpots),
            const SizedBox(height: AppSpacing.xl),
            _ProvinceSectionHeader(title: 'Upcoming festivals', onViewAll: onOpenFestivals),
            const SizedBox(height: AppSpacing.sm),
            _ProvinceUpcomingFestivals(festivals: festivals, columns: wide ? 2 : 1, onTap: onOpenFestivals),
          ],
        );
      },
    );
  }
}

/// A section's title with a "View all" link to the screen that manages it.
class _ProvinceSectionHeader extends StatelessWidget {
  const _ProvinceSectionHeader({required this.title, required this.onViewAll});

  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onViewAll != null) TextButton(onPressed: onViewAll, child: const Text('View all')),
      ],
    );
  }
}

/// A line of text standing in for a section that has nothing to show.
class _ProvinceSectionNote extends StatelessWidget {
  const _ProvinceSectionNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

/// The province's tourist spots as a sideways-scrolling strip of photo cards.
class _ProvinceSpotStrip extends StatelessWidget {
  const _ProvinceSpotStrip({required this.spots, required this.onTap});

  static const double _height = 190;
  static const double _cardWidth = 250;

  final Future<List<Destination>>? spots;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Destination>>(
      future: spots,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _ProvinceSectionNote('Couldn\'t load tourist spots.');
        if (!snapshot.hasData) return LoadingWidget.block(height: _height);
        final items = [...snapshot.data!]..sort((a, b) => a.name.compareTo(b.name));
        if (items.isEmpty) return const _ProvinceSectionNote('No tourist spots yet.');
        return SizedBox(
          height: _height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) => SizedBox(
              width: _cardWidth,
              child: _ProvincePhotoCard(imageUrl: items[index].heroImageUrl, title: items[index].name, onTap: onTap),
            ),
          ),
        );
      },
    );
  }
}

/// A photo with a title across its foot; a tinted stand-in when there's no
/// photo (or it fails to load).
class _ProvincePhotoCard extends StatelessWidget {
  const _ProvincePhotoCard({required this.imageUrl, required this.title, required this.onTap});

  final String imageUrl;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = ColoredBox(
      color: _violetOf(context).withValues(alpha: 0.18),
      child: Center(child: Icon(Symbols.landscape_rounded, size: 40, color: _violetOf(context))),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isEmpty)
            tint
          else
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              // Decoded near card size rather than the photo's full one.
              memCacheWidth: 500,
              placeholder: (context, url) => tint,
              errorWidget: (context, url, error) => tint,
            ),
          // Keeps the white title readable over any photo.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.sm,
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: onTap),
          ),
        ],
      ),
    );
  }
}

/// The province's next few festivals, soonest first.
class _ProvinceUpcomingFestivals extends StatelessWidget {
  const _ProvinceUpcomingFestivals({required this.festivals, required this.columns, required this.onTap});

  static const int _limit = 4;

  final Future<List<Festival>>? festivals;
  final int columns;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Festival>>(
      future: festivals,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _ProvinceSectionNote('Couldn\'t load festivals.');
        if (!snapshot.hasData) return LoadingWidget.block(height: 88);
        final now = DateTime.now();
        DateTime? startOf(Festival f) => f.startDate ?? f.endDate;
        final upcoming = snapshot.data!.where((f) => (f.endDate ?? f.startDate)?.isAfter(now) ?? false).toList()
          ..sort((a, b) => startOf(a)!.compareTo(startOf(b)!));
        if (upcoming.isEmpty) return const _ProvinceSectionNote('No upcoming festivals.');
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - AppSpacing.lg * (columns - 1)) / columns;
            return Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                for (final festival in upcoming.take(_limit))
                  SizedBox(
                    width: width,
                    child: _ProvinceFestivalTile(festival: festival, onTap: onTap),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// One festival: thumbnail, name, when and where.
class _ProvinceFestivalTile extends StatelessWidget {
  const _ProvinceFestivalTile({required this.festival, required this.onTap});

  final Festival festival;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = ColoredBox(
      color: AppColors.adminPink.withValues(alpha: 0.12),
      child: const Center(child: Icon(Symbols.celebration_rounded, color: AppColors.adminPink)),
    );
    return Material(
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: festival.heroImageUrl.isEmpty
                      ? placeholder
                      : CachedNetworkImage(
                          imageUrl: festival.heroImageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 160,
                          placeholder: (context, url) => placeholder,
                          errorWidget: (context, url, error) => placeholder,
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      festival.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      festival.venue.isEmpty ? festival.dateLabel : '${festival.dateLabel} · ${festival.venue}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The province's cover photo (or a tinted stand-in until it has one) under
/// its name, region and status, with the edit action.
class _ProvinceCover extends StatelessWidget {
  const _ProvinceCover({required this.province, required this.onEdit, required this.wide});

  final Province province;
  final VoidCallback onEdit;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhoto = province.heroImageUrl.isNotEmpty;
    const tint = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.adminBlue, AppColors.adminTeal],
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Stack(
        children: [
          Positioned.fill(
            child: hasPhoto
                ? CachedNetworkImage(
                    imageUrl: province.heroImageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => tint,
                    errorWidget: (context, url, error) => tint,
                  )
                : tint,
          ),
          if (!hasPhoto)
            Positioned(
              right: -24,
              top: -32,
              child: Icon(Symbols.landscape_rounded, size: 240, color: Colors.white.withValues(alpha: 0.16)),
            ),
          // Keeps the white text readable over any photo.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.05), Colors.black.withValues(alpha: 0.55)],
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: wide ? 240 : 200),
            child: Padding(
              padding: EdgeInsets.all(wide ? AppSpacing.xl : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: _StatusBadge(hasContent: province.hasContent),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: AppSpacing.lg,
                      runSpacing: AppSpacing.md,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              province.name,
                              style: (wide ? theme.textTheme.headlineMedium : theme.textTheme.headlineSmall)?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              province.islandGroup.isEmpty
                                  ? province.regionName
                                  : '${province.regionName} · ${province.islandGroup}',
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                            ),
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: onEdit,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.adminViolet,
                          ),
                          icon: const Icon(Symbols.edit_rounded, size: 20),
                          label: const Text('Edit province details'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How many tourist spots or festivals the province has, opening that
/// section on tap.
class _ProvinceShortcutCard extends StatelessWidget {
  const _ProvinceShortcutCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.items,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final Future<List<Object>>? items;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FutureBuilder<List<Object>>(
                      future: items,
                      builder: (context, snapshot) => Text(
                        snapshot.hasData ? '${snapshot.data!.length}' : '–',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Symbols.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
