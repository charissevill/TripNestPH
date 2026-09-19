import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/buttons/selectable_chip.dart';
import '../../../core/widgets/inputs/search_bar_widget.dart';
import '../../../core/widgets/states/loading_widget.dart';
import '../../../data/repositories/destination_repository.dart';
import '../../../data/repositories/province_repository.dart';
import '../../../domain/models/destination.dart';
import '../../../domain/models/province.dart';

/// Either a single [Destination] or an entire [Province] — shared by the AI
/// Planner and the manual "Create Your Own Itinerary" form, since both let
/// a traveler pick "a specific spot" or "a whole province" the same way.
enum PickerMode { destination, province }

/// A bottom sheet for picking a real destination or province, backed by
/// curated Firestore data (never free text) — search-as-you-type, with a
/// toggle between "Specific Spot" and "Whole Province" modes. Pops the
/// selected [Destination] or [Province], or null if dismissed.
class DestinationPickerSheet extends StatefulWidget {
  const DestinationPickerSheet({
    super.key,
    required this.currentDestination,
    required this.currentProvince,
  });

  final Destination? currentDestination;
  final Province? currentProvince;

  @override
  State<DestinationPickerSheet> createState() =>
      _DestinationPickerSheetState();
}

class _DestinationPickerSheetState extends State<DestinationPickerSheet> {
  final DestinationRepository _destinationRepository = DestinationRepository();
  final ProvinceRepository _provinceRepository = ProvinceRepository();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  late PickerMode _mode = widget.currentProvince != null
      ? PickerMode.province
      : PickerMode.destination;

  List<Destination>? _destinations;
  Object? _destinationsError;

  List<Province>? _allProvinces;
  Object? _provincesError;
  String _provinceQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDestinations();
    _loadProvinces();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDestinations({String query = ''}) async {
    setState(() => _destinationsError = null);
    try {
      final results = query.trim().isEmpty
          ? await _destinationRepository.getPopular(limit: 50)
          : await _destinationRepository.searchByName(query.trim());
      if (mounted) setState(() => _destinations = results);
    } catch (e) {
      if (mounted) setState(() => _destinationsError = e);
    }
  }

  Future<void> _loadProvinces() async {
    setState(() => _provincesError = null);
    try {
      final results = (await _provinceRepository.getAll())
        ..sort((a, b) => a.name.compareTo(b.name));
      if (mounted) setState(() => _allProvinces = results);
    } catch (e) {
      if (mounted) setState(() => _provincesError = e);
    }
  }

  void _onSearchChanged(String value) {
    if (_mode == PickerMode.province) {
      setState(() => _provinceQuery = value);
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadDestinations(query: value),
    );
  }

  void _switchMode(PickerMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _searchController.clear();
      _provinceQuery = '';
    });
    if (mode == PickerMode.destination) _loadDestinations();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provinces = _allProvinces
        ?.where(
          (p) => p.name.toLowerCase().contains(_provinceQuery.toLowerCase()),
        )
        .toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _mode == PickerMode.destination
                            ? 'Choose a destination'
                            : 'Choose a province',
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        SelectableChip(
                          label: 'Specific Spot',
                          icon: Symbols.place_rounded,
                          selected: _mode == PickerMode.destination,
                          onTap: () => _switchMode(PickerMode.destination),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        SelectableChip(
                          label: 'Whole Province',
                          icon: Symbols.public_rounded,
                          selected: _mode == PickerMode.province,
                          onTap: () => _switchMode(PickerMode.province),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SearchBarWidget(
                      controller: _searchController,
                      hintText: _mode == PickerMode.destination
                          ? 'Search destinations...'
                          : 'Search provinces...',
                      onChanged: _onSearchChanged,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _mode == PickerMode.destination
                    ? _destinationsError != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Text(
                                  AppException.from(
                                    _destinationsError!,
                                  ).message,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : _destinations == null
                          ? ListView(
                              children: List.generate(
                                6,
                                (_) =>
                                    LoadingWidget.textTile(leadingCircle: true),
                              ),
                            )
                          : _destinations!.isEmpty
                          ? const Center(child: Text('No destinations found'))
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                              ),
                              itemCount: _destinations!.length,
                              itemBuilder: (context, i) {
                                final destination = _destinations![i];
                                final selected =
                                    widget.currentDestination?.id ==
                                    destination.id;
                                return ListTile(
                                  onTap: () =>
                                      Navigator.of(context).pop(destination),
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                                    child: Icon(
                                      Symbols.place_rounded,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  title: Text(destination.name),
                                  subtitle: Text(destination.provinceName),
                                  trailing: selected
                                      ? Icon(
                                          Symbols.check_circle_rounded,
                                          color: theme.colorScheme.primary,
                                        )
                                      : null,
                                );
                              },
                            )
                    : _provincesError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                            AppException.from(_provincesError!).message,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : provinces == null
                    ? ListView(
                        children: List.generate(
                          6,
                          (_) => LoadingWidget.textTile(leadingCircle: true),
                        ),
                      )
                    : provinces.isEmpty
                    ? const Center(child: Text('No provinces found'))
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        itemCount: provinces.length,
                        itemBuilder: (context, i) {
                          final province = provinces[i];
                          final selected =
                              widget.currentProvince?.id == province.id;
                          return ListTile(
                            onTap: () => Navigator.of(context).pop(province),
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                              child: Icon(
                                Symbols.public_rounded,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            title: Text(province.name),
                            subtitle: Text(province.regionName),
                            trailing: selected
                                ? Icon(
                                    Symbols.check_circle_rounded,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
