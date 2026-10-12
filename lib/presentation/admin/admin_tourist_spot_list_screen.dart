import 'dart:math' as math;

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
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/indicators/rating_widget.dart';
import '../../core/widgets/layout/scroll_aware_search_header.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/mock/mock_categories.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../domain/models/admin_user.dart';
import '../../domain/models/category.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/province.dart';
import 'widgets/admin_page_header.dart';
import 'widgets/admin_search_sort_bar.dart';

/// [mockCategories]'s seed order, so "sort by Category" groups in the same
/// order they appear on Home/Explore instead of alphabetizing category ids.
final List<String> _categoryIdOrder = mockCategories.map((c) => c.id).toList();

const List<String> _islandGroups = ['Luzon', 'Visayas', 'Mindanao'];

/// How the province picker is ordered.
enum _ProvinceSort { nameAscending, nameDescending, region }

const Map<_ProvinceSort, String> _provinceSortLabels = {
  _ProvinceSort.nameAscending: 'Name (A–Z)',
  _ProvinceSort.nameDescending: 'Name (Z–A)',
  _ProvinceSort.region: 'Region',
};

/// Content never runs wider than this — the same cap the Overview dashboard
/// uses, so switching sections in the sidebar doesn't change the page width.
const double _maxContentWidth = 1200;

/// Bottom list padding that keeps the last card clear of the add button.
const double _fabClearance = AppSpacing.huge * 2;

TravelCategory? _categoryOf(String id) =>
    mockCategories.where((c) => c.id == id).firstOrNull;

enum _SpotSort { name, category, rating }

extension on _SpotSort {
  String get label {
    switch (this) {
      case _SpotSort.name:
        return 'Name (A–Z)';
      case _SpotSort.category:
        return 'Category';
      case _SpotSort.rating:
        return 'Rating (High–Low)';
    }
  }
}

enum _SpotAction { edit, remove }

/// One run of spots under an optional heading — sorting by category is the
/// only mode with headings; the others are a single unlabeled group.
class _SpotGroup {
  const _SpotGroup({this.label = '', this.icon, required this.spots});

  final String label;
  final IconData? icon;
  final List<Destination> spots;
}

/// Pick a province, then manage its tourist spots — create, edit or delete.
/// Every write goes through [DestinationRepository]'s admin methods added
/// alongside this screen, matching `firestore.rules`'s
/// `hasAdminRole(['admin', 'lgu'])` permissions on `tourist_spots`.
class AdminTouristSpotListScreen extends StatefulWidget {
  const AdminTouristSpotListScreen({
    super.key,
    this.destinationRepository,
    this.provinceRepository,
    this.adminRepository,
  });

  final DestinationRepository? destinationRepository;
  final ProvinceRepository? provinceRepository;
  final AdminRepository? adminRepository;

  @override
  State<AdminTouristSpotListScreen> createState() =>
      _AdminTouristSpotListScreenState();
}

class _AdminTouristSpotListScreenState
    extends State<AdminTouristSpotListScreen> {
  late final DestinationRepository _destinationRepository =
      widget.destinationRepository ?? DestinationRepository();
  late final ProvinceRepository _provinceRepository =
      widget.provinceRepository ?? ProvinceRepository();

  late Future<List<Province>> _provincesFuture;
  Province? _selectedProvince;
  Future<List<Destination>>? _spotsFuture;
  _SpotSort _sort = _SpotSort.name;

  /// Null = every island group.
  String? _islandGroup;
  _ProvinceSort _provinceSort = _ProvinceSort.nameAscending;

  // Explicit controllers: the province search and the spot search sit in the
  // same place on screen, and without them the second would inherit whatever
  // was typed into the first when a province is picked.
  final TextEditingController _provinceSearch = TextEditingController();
  final TextEditingController _spotSearch = TextEditingController();

  /// Re-fetched live rather than trusted from the caller, same reasoning as
  /// `AdminProvinceListScreen._admin`. An 'lgu' account manages exactly one
  /// province, so the picker below is replaced with that province already
  /// selected instead of letting them browse for a different one —
  /// `firestore.rules`' `canManageProvince` would reject the write anyway,
  /// this just avoids the traveler navigating into a dead end.
  AdminUser? _admin;

  /// False until [_admin] has been looked up, so an 'lgu' account never sees
  /// (or taps into) the full province picker in the moment before its own
  /// province is selected for it.
  bool _adminResolved = false;

  bool get _isLguScoped =>
      _admin?.role == AdminRole.lgu && _admin?.provinceId != null;

  @override
  void initState() {
    super.initState();
    _provincesFuture = _provinceRepository.getAll();
    _loadAdmin();
  }

  @override
  void dispose() {
    _provinceSearch.dispose();
    _spotSearch.dispose();
    super.dispose();
  }

  Future<void> _loadAdmin() async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    AdminUser? admin;
    if (uid != null) {
      try {
        admin = await (widget.adminRepository ?? AdminRepository()).getById(
          uid,
        );
      } catch (_) {
        // Falls back to the unscoped picker; `firestore.rules` still rejects
        // any write this account isn't entitled to.
      }
    }
    if (!mounted) return;
    setState(() {
      _admin = admin;
      _adminResolved = true;
    });
    if (admin?.role == AdminRole.lgu && admin?.provinceId != null) {
      try {
        final provinces = await _provincesFuture;
        if (!mounted) return;
        final own = provinces
            .where((p) => p.id == admin!.provinceId)
            .firstOrNull;
        if (own != null) _pickProvince(own);
      } catch (_) {
        // Surfaced by the province FutureBuilder's error state below.
      }
    }
  }

  /// Switches which province is being managed (null = back to the picker),
  /// starting each one from a clean search.
  void _pickProvince(Province? province) {
    _provinceSearch.clear();
    _spotSearch.clear();
    setState(() {
      _selectedProvince = province;
      _spotsFuture = province == null
          ? null
          : _destinationRepository.getAllForProvinceAdmin(province.id);
    });
  }

  void _reloadSpots() {
    final province = _selectedProvince;
    if (province == null) return;
    setState(() {
      _spotsFuture = _destinationRepository.getAllForProvinceAdmin(
        province.id,
      );
    });
  }

  /// Groups + sorts for display. Sorting by name or rating has no group
  /// headers (a single unlabeled group); sorting by category gets one header
  /// per category, each internally still alphabetical by name.
  List<_SpotGroup> _grouped(List<Destination> spots) {
    switch (_sort) {
      case _SpotSort.name:
        return [
          _SpotGroup(spots: [...spots]..sort((a, b) => a.name.compareTo(b.name))),
        ];
      case _SpotSort.rating:
        return [
          _SpotGroup(
            spots: [...spots]..sort((a, b) => b.rating.compareTo(a.rating)),
          ),
        ];
      case _SpotSort.category:
        final groups = <String, List<Destination>>{};
        for (final s in spots) {
          groups.putIfAbsent(s.categoryId, () => []).add(s);
        }
        for (final list in groups.values) {
          list.sort((a, b) => a.name.compareTo(b.name));
        }
        final known = _categoryIdOrder.where(groups.containsKey);
        final remaining =
            groups.keys.where((k) => !_categoryIdOrder.contains(k)).toList()
              ..sort();
        return [
          for (final key in [...known, ...remaining])
            _SpotGroup(
              label: _categoryOf(key)?.label ?? key,
              icon: _categoryOf(key)?.icon,
              spots: groups[key]!,
            ),
        ];
    }
  }

  Future<void> _delete(Destination destination) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Remove this spot?',
      message:
          '"${destination.name}" will be permanently removed and no longer shown to travelers.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await _destinationRepository.delete(destination.id);
      if (!mounted) return;
      _reloadSpots();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"${destination.name}" removed.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
      }
    }
  }

  Future<void> _openForm({Destination? existing}) async {
    final province = _selectedProvince;
    if (province == null) return;
    await context.push(
      RoutePaths.adminTouristSpotForm,
      extra: {'province': province, 'destination': existing},
    );
    if (mounted) _reloadSpots();
  }

  Future<void> _refresh() async {
    _reloadSpots();
    try {
      await _spotsFuture;
    } catch (_) {
      // Surfaced by the FutureBuilder's error state below; RefreshIndicator
      // just needs this Future to complete either way.
    }
  }

  @override
  Widget build(BuildContext context) {
    final province = _selectedProvince;
    return Scaffold(
      appBar: adminPageHeader(context, title: 'Tourist Spots'),
      floatingActionButton: province == null
          ? null
          : context.isCompact
          ? FloatingActionButton(
              tooltip: 'Add tourist spot',
              onPressed: () => _openForm(),
              child: const Icon(Symbols.add_rounded),
            )
          : FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Symbols.add_rounded),
              label: const Text('Add tourist spot'),
            ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Wider gutters once the desktop sidebar is showing, and the
            // spare width past the cap goes to the right so the content
            // stays lined up under the app bar title (as on the Overview).
            final gutter = context.windowSize == WindowSize.expanded
                ? AppSpacing.xxl
                : AppSpacing.lg;
            final insets = EdgeInsets.only(
              left: gutter,
              right: math.max(
                gutter,
                constraints.maxWidth - _maxContentWidth - gutter,
              ),
            );
            final contentWidth = constraints.maxWidth - insets.horizontal;
            // The search bar (and what goes with it) slides away while
            // scrolling and returns on scroll-up.
            return CollapsibleSearchHeader(
              header: Padding(
                padding: insets,
                child: province == null
                    ? _buildPickerHeader(contentWidth)
                    : _buildSpotsHeader(province, contentWidth),
              ),
              body: province == null
                  ? _buildPickerBody(insets, contentWidth)
                  : _buildSpotsBody(insets, contentWidth),
            );
          },
        ),
      ),
    );
  }

  // ---- Step 1: choose a province ----

  Widget _buildPickerHeader(double contentWidth) {
    // Nothing to search until the picker itself is on screen — and an 'lgu'
    // account never gets one.
    if (!_adminResolved || _isLguScoped) return const SizedBox.shrink();
    final search = _SearchField(
      key: const ValueKey('province-search'),
      controller: _provinceSearch,
      hintText: 'Search provinces...',
      onChanged: () => setState(() {}),
    );
    Widget sortMenu({required bool showLabel}) => AdminSortMenu<_ProvinceSort>(
      value: _provinceSort,
      labels: _provinceSortLabels,
      showLabel: showLabel,
      onChanged: (sort) => setState(() => _provinceSort = sort),
    );
    // Beside the search bar the chips are sized up to match its height.
    final sideBySide = contentWidth >= 820;
    final chips = Wrap(
      spacing: sideBySide ? AppSpacing.sm : AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        _IslandChip(
          label: 'All',
          icon: Symbols.public_rounded,
          selected: _islandGroup == null,
          large: sideBySide,
          onTap: () => setState(() => _islandGroup = null),
        ),
        for (final group in _islandGroups)
          _IslandChip(
            label: group,
            icon: Symbols.location_on_rounded,
            selected: _islandGroup == group,
            large: sideBySide,
            onTap: () => setState(() => _islandGroup = group),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
      child: sideBySide
          ? Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: AppSpacing.md),
                chips,
                const SizedBox(width: AppSpacing.sm),
                sortMenu(showLabel: contentWidth >= 1000),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: AppSpacing.sm),
                    sortMenu(showLabel: contentWidth >= 600),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                chips,
              ],
            ),
    );
  }

  Widget _buildPickerBody(EdgeInsets insets, double contentWidth) {
    return FutureBuilder<List<Province>>(
      future: _provincesFuture,
      builder: (context, snapshot) {
        if (!_adminResolved ||
            snapshot.connectionState != ConnectionState.done) {
          return _skeleton(
            insets,
            (_) => LoadingWidget.textTile(leadingCircle: true),
          );
        }
        if (snapshot.hasError) {
          return EmptyStateWidget(
            icon: Symbols.error_outline_rounded,
            title: 'Couldn\'t load provinces',
            message: AppException.from(snapshot.error!).message,
          );
        }
        if (_isLguScoped) {
          // Only reached when the account's own province isn't in the list;
          // otherwise `_loadAdmin` has already selected it.
          return const EmptyStateWidget(
            icon: Symbols.public_rounded,
            title: 'Province unavailable',
            message:
                'We couldn\'t find the province assigned to this account.',
          );
        }
        final query = _provinceSearch.text.trim().toLowerCase();
        // Copied before sorting — `snapshot.data` isn't ours to reorder.
        final provinces =
            (snapshot.data ?? const <Province>[])
                .where((p) => p.name.toLowerCase().contains(query))
                .where(
                  (p) => _islandGroup == null || p.islandGroup == _islandGroup,
                )
                .toList()
              ..sort((a, b) {
                final names = a.name.compareTo(b.name);
                switch (_provinceSort) {
                  case _ProvinceSort.nameAscending:
                    return names;
                  case _ProvinceSort.nameDescending:
                    return -names;
                  case _ProvinceSort.region:
                    final regions = a.regionName.compareTo(b.regionName);
                    return regions != 0 ? regions : names;
                }
              });
        if (provinces.isEmpty) {
          return const EmptyStateWidget(
            icon: Symbols.search_off_rounded,
            title: 'No matches',
            message: 'No provinces match your search.',
          );
        }
        final columns = contentWidth >= 900
            ? 3
            : contentWidth >= 560
            ? 2
            : 1;
        final rowCount = (provinces.length / columns).ceil();
        return ListView.builder(
          padding: insets.copyWith(bottom: AppSpacing.huge),
          itemCount: rowCount + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Choose a province to manage its tourist spots.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            final start = (index - 1) * columns;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _CardRow(
                columns: columns,
                children: [
                  for (final province in provinces.skip(start).take(columns))
                    _ProvinceCard(
                      province: province,
                      onTap: () => _pickProvince(province),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---- Step 2: that province's tourist spots ----

  Widget _buildSpotsHeader(Province province, double contentWidth) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
      child: Column(
        children: [
          FutureBuilder<List<Destination>>(
            future: _spotsFuture,
            builder: (context, snapshot) => _ProvinceBanner(
              province: province,
              // Unknown while loading (or after a failed load), so the count
              // is left out rather than shown as a misleading zero.
              spotCount: snapshot.connectionState == ConnectionState.done
                  ? snapshot.data?.length
                  : null,
              dense: contentWidth < 520,
              onChange: _isLguScoped ? null : () => _pickProvince(null),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _SearchField(
                  key: const ValueKey('spot-search'),
                  controller: _spotSearch,
                  hintText: 'Search tourist spots...',
                  onChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SortMenu(
                value: _sort,
                showLabel: contentWidth >= 600,
                onChanged: (value) => setState(() => _sort = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpotsBody(EdgeInsets insets, double contentWidth) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Destination>>(
        future: _spotsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _skeleton(insets, (_) => LoadingWidget.listRow());
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                EmptyStateWidget(
                  icon: Symbols.error_outline_rounded,
                  title: 'Couldn\'t load tourist spots',
                  message: AppException.from(snapshot.error!).message,
                ),
              ],
            );
          }
          final allSpots = snapshot.data ?? const <Destination>[];
          if (allSpots.isEmpty) {
            return ListView(
              children: const [
                EmptyStateWidget(
                  icon: Symbols.place_rounded,
                  title: 'No tourist spots yet',
                  message: 'Tap + to add the first one for this province.',
                ),
              ],
            );
          }
          final query = _spotSearch.text.trim().toLowerCase();
          final spots = allSpots
              .where((s) => s.name.toLowerCase().contains(query))
              .toList();
          if (spots.isEmpty) {
            return ListView(
              children: const [
                EmptyStateWidget(
                  icon: Symbols.search_off_rounded,
                  title: 'No matches',
                  message: 'No tourist spots match your search.',
                ),
              ],
            );
          }
          final columns = contentWidth >= 820 ? 2 : 1;
          final cardWidth =
              (contentWidth - AppSpacing.sm * (columns - 1)) / columns;
          // A group heading, or one row of up to [columns] spots.
          final entries = <Object>[];
          for (final group in _grouped(spots)) {
            if (group.label.isNotEmpty) entries.add(group);
            for (var i = 0; i < group.spots.length; i += columns) {
              entries.add(group.spots.skip(i).take(columns).toList());
            }
          }
          return ListView.builder(
            padding: insets.copyWith(bottom: _fabClearance),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              if (entry is _SpotGroup) {
                return _GroupHeader(
                  label: entry.label,
                  icon: entry.icon,
                  count: entry.spots.length,
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _CardRow(
                  columns: columns,
                  children: [
                    for (final spot in entry as List<Destination>)
                      _SpotCard(
                        spot: spot,
                        dense: cardWidth < 400,
                        onEdit: () => _openForm(existing: spot),
                        onDelete: () => _delete(spot),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// [LoadingWidget]'s rows carry their own [AppSpacing.lg] side padding, so
  /// only the difference is added here to line them up with the real cards.
  Widget _skeleton(EdgeInsets insets, Widget Function(int) row) {
    return ListView(
      padding: EdgeInsets.only(
        left: insets.left - AppSpacing.lg,
        right: insets.right - AppSpacing.lg,
      ),
      children: List.generate(6, row),
    );
  }
}

Color _islandColor(BuildContext context, String islandGroup) {
  switch (islandGroup) {
    case 'Luzon':
      return AppColors.adminBlue;
    case 'Visayas':
      return AppColors.adminGreen;
    case 'Mindanao':
      return Theme.of(context).brightness == Brightness.dark
          ? AppColors.adminVioletLight
          : AppColors.adminViolet;
    default:
      return AppColors.textSecondary;
  }
}

/// Lays [children] out [columns] across, every card in the row as tall as
/// its tallest — the last row is padded with blanks so its cards keep the
/// same width as the rows above.
class _CardRow extends StatelessWidget {
  const _CardRow({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (columns == 1) return children.single;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < columns; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: i < children.length
                  ? children[i]
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

/// The bordered, tappable surface every card on this screen sits on.
class _TapCard extends StatelessWidget {
  const _TapCard({required this.onTap, required this.child, this.padding});

  final VoidCallback onTap;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      // A faint tinted lift, so the cards read as raised off the page
      // rather than outlined onto it.
      elevation: 3,
      shadowColor: theme.colorScheme.primary.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppSpacing.md),
          child: child,
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 28, fill: 1),
    );
  }
}

/// An island-group filter pill. [large] matches the search bar's height for
/// when the two share a row.
class _IslandChip extends StatelessWidget {
  const _IslandChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.large,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool large;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final foreground = selected ? Colors.white : theme.colorScheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: large
              ? const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14)
              : const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
          decoration: BoxDecoration(
            color: selected ? primary : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? primary : theme.colorScheme.outline,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: large ? 20 : 16, color: foreground, fill: selected ? 1 : 0),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style:
                    (large
                            ? theme.textTheme.labelLarge
                            : theme.textTheme.labelMedium)
                        ?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    OutlineInputBorder pill(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        border: pill(theme.colorScheme.outline),
        enabledBorder: pill(theme.colorScheme.outline),
        focusedBorder: pill(theme.colorScheme.primary, 1.5),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: AppSpacing.xs),
          child: Icon(Symbols.search_rounded),
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Symbols.close_rounded, size: 20),
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
      ),
      onChanged: (_) => onChanged(),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({
    required this.value,
    required this.onChanged,
    required this.showLabel,
  });

  final _SpotSort value;
  final ValueChanged<_SpotSort> onChanged;

  /// False where there's only room for the icon; the tooltip and the menu's
  /// own checked item still say which sort is active.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<_SpotSort>(
      tooltip: 'Sort by: ${value.label}',
      initialValue: value,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      itemBuilder: (context) => [
        for (final sort in _SpotSort.values)
          PopupMenuItem(value: sort, child: Text(sort.label)),
      ],
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.sort_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            if (showLabel) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                value.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Icon(
                Symbols.expand_more_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProvinceCard extends StatelessWidget {
  const _ProvinceCard({required this.province, required this.onTap});

  final Province province;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _TapCard(
      onTap: onTap,
      child: Row(
        children: [
          _IconTile(
            icon: Symbols.map_rounded,
            color: _islandColor(context, province.islandGroup),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  province.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (province.regionName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    province.regionName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(
            Symbols.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

/// Which province the list below belongs to, how many spots it has, and the
/// way back to the picker.
class _ProvinceBanner extends StatelessWidget {
  const _ProvinceBanner({
    required this.province,
    required this.spotCount,
    required this.dense,
    required this.onChange,
  });

  final Province province;
  final int? spotCount;
  final bool dense;

  /// Null for an account that can't switch provinces.
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final count = spotCount;
    final details = [
      if (province.regionName.isNotEmpty) province.regionName,
      if (province.islandGroup.isNotEmpty) province.islandGroup,
      if (count != null)
        count == 1 ? '1 tourist spot' : '$count tourist spots',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: const Icon(Symbols.place_rounded, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  province.name,
                  style: theme.textTheme.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    details,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (onChange != null) ...[
            const SizedBox(width: AppSpacing.xs),
            if (dense)
              IconButton(
                tooltip: 'Change province',
                onPressed: onChange,
                icon: Icon(Symbols.swap_horiz_rounded, color: primary),
              )
            else
              OutlinedButton.icon(
                onPressed: onChange,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  backgroundColor: theme.colorScheme.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
                icon: const Icon(Symbols.swap_horiz_rounded, size: 20),
                label: const Text('Change province'),
              ),
          ],
        ],
      ),
    );
  }
}

class _SpotCard extends StatelessWidget {
  const _SpotCard({
    required this.spot,
    required this.dense,
    required this.onEdit,
    required this.onDelete,
  });

  final Destination spot;

  /// A narrow card: smaller photo, no description line, and the two actions
  /// folded into one overflow menu so the name keeps most of the width.
  final bool dense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = _categoryOf(spot.categoryId);
    final categoryLabel = category?.label ?? spot.categoryId;
    return _TapCard(
      onTap: onEdit,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          _SpotThumbnail(
            imageUrl: spot.heroImageUrl,
            fallbackIcon: category?.icon ?? Symbols.place_rounded,
            size: dense ? 56 : 72,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  spot.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!dense && spot.shortDescription.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    spot.shortDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (categoryLabel.isNotEmpty)
                      _Pill(
                        icon: category?.icon ?? Symbols.place_rounded,
                        label: categoryLabel,
                        color: theme.colorScheme.primary,
                      ),
                    if (spot.reviewCount > 0)
                      RatingWidget(
                        rating: spot.rating,
                        reviewCount: spot.reviewCount,
                        starSize: 14,
                        textStyle: theme.textTheme.labelSmall,
                      )
                    else
                      // Padded to a pill's height so cards side by side
                      // line up whether or not they have reviews.
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          'No reviews yet',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    if (spot.isFeatured)
                      const _Pill(
                        icon: Symbols.award_star_rounded,
                        label: 'Featured',
                        color: AppColors.accentDark,
                      ),
                    if (spot.isHiddenGem)
                      const _Pill(
                        icon: Symbols.diamond_rounded,
                        label: 'Hidden Gem',
                        color: AppColors.secondary,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (dense)
            PopupMenuButton<_SpotAction>(
              tooltip: 'Actions',
              icon: const Icon(Symbols.more_vert_rounded),
              onSelected: (action) =>
                  action == _SpotAction.edit ? onEdit() : onDelete(),
              itemBuilder: (context) => const [
                PopupMenuItem(value: _SpotAction.edit, child: Text('Edit')),
                PopupMenuItem(value: _SpotAction.remove, child: Text('Remove')),
              ],
            )
          else ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Symbols.edit_rounded, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(
                Symbols.delete_outline_rounded,
                size: 20,
                color: AppColors.error,
              ),
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

/// The spot's hero photo, or its category icon when it has none (or the
/// photo fails to load).
class _SpotThumbnail extends StatelessWidget {
  const _SpotThumbnail({
    required this.imageUrl,
    required this.fallbackIcon,
    required this.size,
  });

  final String imageUrl;
  final IconData fallbackIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.shimmerBase,
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        size: size * 0.4,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox.square(
        dimension: size,
        child: imageUrl.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, _) =>
                    const ColoredBox(color: AppColors.shimmerBase),
                errorWidget: (context, _, _) => fallback,
              ),
      ),
    );
  }
}

/// A small tinted tag. Only the icon takes [color] — the label stays in the
/// regular text color so it's readable on every tint.
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.count, this.icon});

  final String label;
  final int count;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$count',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
