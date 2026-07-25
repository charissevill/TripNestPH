import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/mock/mock_categories.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/province.dart';

/// [mockCategories]'s seed order, so "sort by Category" groups in the same
/// order they appear on Home/Explore instead of alphabetizing category ids.
final List<String> _categoryIdOrder = mockCategories.map((c) => c.id).toList();

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

/// Pick a province, then manage its tourist spots — create, edit or delete.
/// Every write goes through [DestinationRepository]'s admin methods added
/// alongside this screen, matching `firestore.rules`'s
/// `hasAdminRole(['admin', 'lgu'])` permissions on `tourist_spots`.
class AdminTouristSpotListScreen extends StatefulWidget {
  const AdminTouristSpotListScreen({super.key});

  @override
  State<AdminTouristSpotListScreen> createState() =>
      _AdminTouristSpotListScreenState();
}

class _AdminTouristSpotListScreenState
    extends State<AdminTouristSpotListScreen> {
  final DestinationRepository _destinationRepository = DestinationRepository();
  final ProvinceRepository _provinceRepository = ProvinceRepository();

  late Future<List<Province>> _provincesFuture;
  Province? _selectedProvince;
  Future<List<Destination>>? _spotsFuture;
  String _query = '';
  _SpotSort _sort = _SpotSort.name;

  /// Locates the province field's on-screen bottom edge so the suggestions
  /// list below it never claims more height than what's actually left above
  /// the keyboard — a fixed height there overflowed once the keyboard opened.
  final GlobalKey _provinceFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _provincesFuture = _provinceRepository.getAll();
  }

  void _selectProvince(Province? province) {
    setState(() {
      _selectedProvince = province;
      _spotsFuture = province == null
          ? null
          : _destinationRepository.getAllForProvinceAdmin(province.id);
    });
  }

  /// Groups + sorts for display. Sorting by name or rating has no group
  /// headers (a single `''` group); sorting by category gets one header per
  /// category, each internally still alphabetical by name.
  Map<String, List<Destination>> _grouped(List<Destination> spots) {
    switch (_sort) {
      case _SpotSort.name:
        return {
          '': [...spots]..sort((a, b) => a.name.compareTo(b.name)),
        };
      case _SpotSort.rating:
        return {
          '': [...spots]..sort((a, b) => b.rating.compareTo(a.rating)),
        };
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
        final orderedKeys = [...known, ...remaining];
        return {
          for (final key in orderedKeys)
            (mockCategories.where((c) => c.id == key).firstOrNull?.label ??
                    key):
                groups[key]!,
        };
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
      _selectProvince(_selectedProvince);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Future<void> _openForm({Destination? existing}) async {
    final province = _selectedProvince;
    if (province == null) return;
    await context.push(
      RoutePaths.adminTouristSpotForm,
      extra: {'province': province, 'destination': existing},
    );
    if (mounted) _selectProvince(province);
  }

  Future<void> _refresh() async {
    final province = _selectedProvince;
    if (province == null) return;
    _selectProvince(province);
    try {
      await _spotsFuture;
    } catch (_) {
      // Surfaced by the FutureBuilder's error state below; RefreshIndicator
      // just needs this Future to complete either way.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Tourist Spots'),
      ),
      floatingActionButton: _selectedProvince == null
          ? null
          : FloatingActionButton(
              onPressed: () => _openForm(),
              child: const Icon(Symbols.add_rounded),
            ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: FutureBuilder<List<Province>>(
                future: _provincesFuture,
                builder: (context, snapshot) {
                  final provinces = (snapshot.data ?? const [])
                    ..sort((a, b) => a.name.compareTo(b.name));
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return Autocomplete<Province>(
                        displayStringForOption: (p) => p.name,
                        initialValue: TextEditingValue(
                          text: _selectedProvince?.name ?? '',
                        ),
                        optionsBuilder: (textEditingValue) {
                          final query = textEditingValue.text.toLowerCase();
                          if (query.isEmpty) return provinces;
                          return provinces.where(
                            (p) => p.name.toLowerCase().contains(query),
                          );
                        },
                        onSelected: _selectProvince,
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                              return TextField(
                                key: _provinceFieldKey,
                                controller: controller,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Province',
                                  hintText: 'Type to search provinces...',
                                  prefixIcon: Icon(Symbols.public_rounded),
                                ),
                              );
                            },
                        optionsViewBuilder: (context, onSelected, options) {
                          final fieldBox =
                              _provinceFieldKey.currentContext
                                      ?.findRenderObject()
                                  as RenderBox?;
                          final fieldBottom = fieldBox == null
                              ? 0.0
                              : fieldBox
                                    .localToGlobal(
                                      Offset(0, fieldBox.size.height),
                                    )
                                    .dy;
                          final keyboardHeight = MediaQuery.of(
                            context,
                          ).viewInsets.bottom;
                          final screenHeight = MediaQuery.of(
                            context,
                          ).size.height;
                          final availableHeight =
                              screenHeight -
                              keyboardHeight -
                              fieldBottom -
                              AppSpacing.sm;
                          final maxHeight = availableHeight.clamp(0.0, 280.0);
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: constraints.maxWidth,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: maxHeight,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, i) {
                                      final option = options.elementAt(i);
                                      return ListTile(
                                        title: Text(option.name),
                                        subtitle: Text(option.regionName),
                                        onTap: () => onSelected(option),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            if (_selectedProvince != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  0,
                ),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search tourist spots...',
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<_SpotSort>(
                          isDense: true,
                          isExpanded: true,
                          value: _sort,
                          items: _SpotSort.values
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
            ],
            Expanded(
              child: _selectedProvince == null
                  ? const EmptyStateWidget(
                      icon: Symbols.public_rounded,
                      title: 'Pick a province',
                      message:
                          'Choose a province above to manage its tourist spots.',
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: FutureBuilder<List<Destination>>(
                        future: _spotsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return ListView(
                              children: List.generate(
                                6,
                                (_) => LoadingWidget.textTile(),
                              ),
                            );
                          }
                          final allSpots = snapshot.data ?? const [];
                          if (allSpots.isEmpty) {
                            return ListView(
                              children: const [
                                EmptyStateWidget(
                                  icon: Symbols.place_rounded,
                                  title: 'No tourist spots yet',
                                  message:
                                      'Tap + to add the first one for this province.',
                                ),
                              ],
                            );
                          }
                          final spots = allSpots
                              .where(
                                (s) => s.name.toLowerCase().contains(
                                  _query.toLowerCase(),
                                ),
                              )
                              .toList();
                          if (spots.isEmpty) {
                            return ListView(
                              children: const [
                                EmptyStateWidget(
                                  icon: Symbols.search_off_rounded,
                                  title: 'No matches',
                                  message:
                                      'No tourist spots match your search.',
                                ),
                              ],
                            );
                          }
                          final groups = _grouped(spots);
                          return ListView(
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
                                for (final spot in entry.value)
                                  ListTile(
                                    title: Text(spot.name),
                                    subtitle: Text(
                                      mockCategories
                                              .where(
                                                (c) => c.id == spot.categoryId,
                                              )
                                              .firstOrNull
                                              ?.label ??
                                          spot.categoryId,
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Symbols.edit_rounded,
                                            size: 20,
                                          ),
                                          onPressed: () =>
                                              _openForm(existing: spot),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Symbols.delete_outline_rounded,
                                            size: 20,
                                            color: AppColors.error,
                                          ),
                                          onPressed: () => _delete(spot),
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
            ),
          ],
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
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
