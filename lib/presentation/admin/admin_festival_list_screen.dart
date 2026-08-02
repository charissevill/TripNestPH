import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/festival_repository.dart';
import '../../domain/models/admin_user.dart';
import '../../domain/models/festival.dart';

enum _FestivalSort { name, date, province, upcoming }

extension on _FestivalSort {
  String get label {
    switch (this) {
      case _FestivalSort.name:
        return 'Name (A–Z)';
      case _FestivalSort.date:
        return 'Date (Soonest)';
      case _FestivalSort.province:
        return 'Province';
      case _FestivalSort.upcoming:
        return 'Upcoming Status';
    }
  }
}

/// Festival management — shows every festival for admin/lgu, full
/// curatorial control.
class AdminFestivalListScreen extends StatefulWidget {
  const AdminFestivalListScreen({super.key});

  @override
  State<AdminFestivalListScreen> createState() =>
      _AdminFestivalListScreenState();
}

class _AdminFestivalListScreenState extends State<AdminFestivalListScreen> {
  final FestivalRepository _repository = FestivalRepository();
  late Future<List<Festival>> _future;
  String _query = '';
  _FestivalSort _sort = _FestivalSort.name;

  /// Re-fetched live rather than trusted from the caller, same reasoning as
  /// `AdminProvinceListScreen._admin`.
  AdminUser? _admin;

  bool get _isLguScoped => _admin?.role == AdminRole.lgu && _admin?.provinceId != null;

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
    if (mounted) setState(() => _admin = admin);
  }

  void _load() {
    _future = _repository.getAllForAdmin();
  }

  /// Groups + sorts for display. Name/date has no group headers (a single
  /// `''` group); province/upcoming get one header per group, each
  /// internally still alphabetical by name.
  Map<String, List<Festival>> _grouped(List<Festival> festivals) {
    switch (_sort) {
      case _FestivalSort.name:
        return {
          '': [...festivals]..sort((a, b) => a.name.compareTo(b.name)),
        };
      case _FestivalSort.date:
        // Festivals without a structured startDate (not yet migrated off
        // the old free-text date field) sort after every dated one, since
        // there's no reliable way to place them chronologically.
        return {
          '': [...festivals]
            ..sort((a, b) {
              final aDate = a.startDate;
              final bDate = b.startDate;
              if (aDate == null && bDate == null)
                return a.name.compareTo(b.name);
              if (aDate == null) return 1;
              if (bDate == null) return -1;
              return aDate.compareTo(bDate);
            }),
        };
      case _FestivalSort.province:
        final groups = <String, List<Festival>>{};
        for (final f in festivals) {
          groups.putIfAbsent(f.provinceName, () => []).add(f);
        }
        for (final list in groups.values) {
          list.sort((a, b) => a.name.compareTo(b.name));
        }
        final orderedKeys = groups.keys.toList()..sort();
        return {for (final key in orderedKeys) key: groups[key]!};
      case _FestivalSort.upcoming:
        final groups = <String, List<Festival>>{};
        for (final f in festivals) {
          groups
              .putIfAbsent(f.isUpcoming ? 'Upcoming' : 'Not Upcoming', () => [])
              .add(f);
        }
        for (final list in groups.values) {
          list.sort((a, b) => a.name.compareTo(b.name));
        }
        return {
          for (final key in ['Upcoming', 'Not Upcoming'])
            if (groups.containsKey(key)) key: groups[key]!,
        };
    }
  }

  Future<void> _delete(Festival festival) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete this festival?',
      message:
          '"${festival.name}" will be permanently removed and no longer shown to travelers.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await _repository.delete(festival.id);
      setState(_load);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Future<void> _openForm({Festival? existing}) async {
    await context.push(
      RoutePaths.adminFestivalForm,
      extra: {'existing': existing},
    );
    if (mounted) setState(_load);
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Festivals'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Symbols.add_rounded),
      ),
      body: SafeArea(
        child: Column(
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
                  hintText: 'Search festivals...',
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
                      child: DropdownButton<_FestivalSort>(
                        isDense: true,
                        isExpanded: true,
                        value: _sort,
                        items: _FestivalSort.values
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
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<Festival>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return ListView(
                        children: List.generate(
                          6,
                          (_) => LoadingWidget.textTile(),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return ListView(
                        children: [
                          EmptyStateWidget(
                            icon: Symbols.error_outline_rounded,
                            title: 'Couldn\'t load festivals',
                            message: AppException.from(snapshot.error!).message,
                          ),
                        ],
                      );
                    }
                    final allFestivals = snapshot.data ?? const [];
                    if (allFestivals.isEmpty) {
                      return ListView(
                        children: [
                          const EmptyStateWidget(
                            icon: Symbols.celebration_rounded,
                            title: 'No festivals yet',
                            message: 'Tap + to add the first one.',
                          ),
                        ],
                      );
                    }
                    final festivals = allFestivals
                        .where((f) => !_isLguScoped || f.provinceId == _admin!.provinceId)
                        .where(
                          (f) => f.name.toLowerCase().contains(
                            _query.toLowerCase(),
                          ),
                        )
                        .toList();
                    if (festivals.isEmpty) {
                      return ListView(
                        children: const [
                          EmptyStateWidget(
                            icon: Symbols.search_off_rounded,
                            title: 'No matches',
                            message: 'No festivals match your search.',
                          ),
                        ],
                      );
                    }
                    final groups = _grouped(festivals);
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
                          for (final festival in entry.value)
                            ListTile(
                              title: Text(festival.name),
                              subtitle: Text(
                                '${festival.provinceName} · ${festival.dateLabel}',
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
                                        _openForm(existing: festival),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Symbols.delete_outline_rounded,
                                      size: 20,
                                      color: AppColors.error,
                                    ),
                                    onPressed: () => _delete(festival),
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
