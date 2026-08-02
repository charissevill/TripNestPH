import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../data/mock/mock_categories.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/province.dart';

/// One parsed CSV data row, either a ready-to-create [Destination] or a
/// validation failure with a human-readable reason — never both, so the
/// preview list can render either state from a single object.
class _ParsedRow {
  _ParsedRow({required this.rowNumber, this.destination, this.error});

  final int rowNumber;
  final Destination? destination;
  final String? error;
  bool get isValid => destination != null;
}

/// Admin-only: create many `tourist_spots` at once from a CSV instead of
/// one at a time via `AdminTouristSpotFormScreen` — the direct fix for the
/// "~68 provinces still content coming soon" backlog those forms alone
/// haven't been able to close quickly. Every row is validated (real
/// provinceId, real categoryId, required fields) and previewed before any
/// write happens; only valid rows are ever sent, one at a time, through
/// the exact same `DestinationRepository.create()` every other admin
/// create-flow already uses — no new/bespoke write path.
class AdminBulkImportScreen extends StatefulWidget {
  const AdminBulkImportScreen({super.key});

  @override
  State<AdminBulkImportScreen> createState() => _AdminBulkImportScreenState();
}

class _AdminBulkImportScreenState extends State<AdminBulkImportScreen> {
  final DestinationRepository _repository = DestinationRepository();
  final ProvinceRepository _provinceRepository = ProvinceRepository();

  List<Province> _provinces = [];
  List<_ParsedRow> _rows = [];
  String? _fileName;
  bool _loadingProvinces = true;
  bool _importing = false;
  int _importedCount = 0;
  List<String> _importErrors = [];

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  Future<void> _loadProvinces() async {
    try {
      final provinces = await _provinceRepository.getAll();
      if (!mounted) return;
      setState(() {
        _provinces = provinces;
        _loadingProvinces = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingProvinces = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    _parseCsv(utf8.decode(bytes), result.files.first.name);
  }

  void _parseCsv(String content, String fileName) {
    final table = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(content);
    if (table.isEmpty) {
      setState(() {
        _fileName = fileName;
        _rows = [];
        _importedCount = 0;
        _importErrors = [];
      });
      return;
    }
    final header = table.first.map((c) => c.toString().trim()).toList();
    final rows = <_ParsedRow>[];
    for (var i = 1; i < table.length; i++) {
      final raw = table[i];
      if (raw.every((c) => c.toString().trim().isEmpty)) continue;
      final map = <String, String>{};
      for (var c = 0; c < header.length && c < raw.length; c++) {
        map[header[c]] = raw[c].toString().trim();
      }
      // 1-based, matching the row number a spreadsheet app would show
      // (i is 0-based starting after the header, so +2).
      rows.add(_parseRow(i + 2, map));
    }
    setState(() {
      _fileName = fileName;
      _rows = rows;
      _importedCount = 0;
      _importErrors = [];
    });
  }

  _ParsedRow _parseRow(int rowNumber, Map<String, String> map) {
    final name = map['name'] ?? '';
    if (name.isEmpty)
      return _ParsedRow(rowNumber: rowNumber, error: 'Missing name');

    final provinceId = map['provinceId'] ?? '';
    final matchingProvinces = _provinces.where((p) => p.id == provinceId);
    if (matchingProvinces.isEmpty) {
      return _ParsedRow(
        rowNumber: rowNumber,
        error: 'Unknown provinceId "$provinceId"',
      );
    }
    final province = matchingProvinces.first;

    final categoryId = map['categoryId'] ?? '';
    if (!mockCategories.any((c) => c.id == categoryId)) {
      return _ParsedRow(
        rowNumber: rowNumber,
        error:
            'Unknown categoryId "$categoryId" (must be one of: ${mockCategories.map((c) => c.id).join(', ')})',
      );
    }

    final shortDescription = map['shortDescription'] ?? '';
    if (shortDescription.isEmpty) {
      return _ParsedRow(
        rowNumber: rowNumber,
        error: 'Missing shortDescription',
      );
    }

    double? parseDouble(String? v) =>
        (v == null || v.isEmpty) ? null : double.tryParse(v);
    bool parseBool(String? v) => v?.toLowerCase() == 'true' || v == '1';

    return _ParsedRow(
      rowNumber: rowNumber,
      destination: Destination(
        id: '',
        name: name,
        provinceId: provinceId,
        provinceName: province.name,
        regionId: province.regionId,
        categoryId: categoryId,
        heroImageUrl: map['heroImageUrl'] ?? '',
        galleryImageUrls: const [],
        rating: 0,
        reviewCount: 0,
        shortDescription: shortDescription,
        longDescription: map['longDescription'] ?? '',
        entranceFee: (map['entranceFee'] ?? '').isEmpty
            ? 'Free'
            : map['entranceFee']!,
        bestTimeToVisit: map['bestTimeToVisit'] ?? '',
        travelTips: const [],
        highlights: const [],
        isFeatured: parseBool(map['isFeatured']),
        isHiddenGem: parseBool(map['isHiddenGem']),
        latitude: parseDouble(map['latitude']),
        longitude: parseDouble(map['longitude']),
        phoneNumber: map['phoneNumber'] ?? '',
        websiteUrl: map['websiteUrl'] ?? '',
        facebookUrl: map['facebookUrl'] ?? '',
        openingHours: map['openingHours'] ?? '',
      ),
    );
  }

  Future<void> _import() async {
    final validRows = _rows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) return;
    final confirmed = await showConfirmationDialog(
      context,
      title:
          'Import ${validRows.length} tourist spot${validRows.length == 1 ? '' : 's'}?',
      message:
          'This creates ${validRows.length} new published tourist spot(s) right away. There\'s no bulk undo — '
          'removing one afterward means deleting it individually from the Tourist Spots list.',
      confirmLabel: 'Import',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _importing = true;
      _importedCount = 0;
      _importErrors = [];
    });
    var imported = 0;
    final errors = <String>[];
    for (final row in validRows) {
      try {
        await _repository.create(row.destination!);
        imported++;
        if (mounted) setState(() => _importedCount = imported);
      } catch (e) {
        errors.add(
          'Row ${row.rowNumber} (${row.destination!.name}): ${AppException.from(e).message}',
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _importing = false;
      _importErrors = errors;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final validCount = _rows.where((r) => r.isValid).length;
    final invalidCount = _rows.length - validCount;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Bulk Import Tourist Spots'),
      ),
      body: SafeArea(
        child: _loadingProvinces
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.huge,
                ),
                children: [
                  Text(
                    'Upload a CSV to create many tourist spots at once instead of one at a time. '
                    'Required columns: name, provinceId, categoryId, shortDescription. Optional: longDescription, '
                    'heroImageUrl, entranceFee, bestTimeToVisit, latitude, longitude, phoneNumber, websiteUrl, '
                    'facebookUrl, openingHours, isFeatured, isHiddenGem.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Valid categoryId values: ${mockCategories.map((c) => c.id).join(', ')}.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: _importing ? null : _pickFile,
                    icon: const Icon(Symbols.upload_file_rounded),
                    label: Text(
                      _fileName == null
                          ? 'Choose CSV File'
                          : 'Change File ($_fileName)',
                    ),
                  ),
                  if (_rows.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        const Icon(
                          Symbols.check_circle_rounded,
                          color: AppColors.success,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text('$validCount valid'),
                        if (invalidCount > 0) ...[
                          const SizedBox(width: AppSpacing.md),
                          const Icon(
                            Symbols.error_rounded,
                            color: AppColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text('$invalidCount invalid'),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ..._rows.map(
                      (row) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          row.isValid
                              ? Symbols.check_circle_rounded
                              : Symbols.error_rounded,
                          color: row.isValid
                              ? AppColors.success
                              : AppColors.error,
                        ),
                        title: Text(
                          row.isValid
                              ? row.destination!.name
                              : 'Row ${row.rowNumber}',
                        ),
                        subtitle: Text(
                          row.isValid
                              ? '${row.destination!.provinceName} · ${row.destination!.categoryId}'
                              : row.error!,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (validCount > 0)
                      FilledButton(
                        onPressed: _importing ? null : _import,
                        child: _importing
                            ? Text('Importing $_importedCount/$validCount...')
                            : Text(
                                'Import $validCount Tourist Spot${validCount == 1 ? '' : 's'}',
                              ),
                      ),
                    if (_importErrors.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Import errors:',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                      ..._importErrors.map(
                        (e) => Text(
                          e,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                    if (!_importing &&
                        _importedCount > 0 &&
                        _importErrors.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Text(
                          '$_importedCount tourist spot${_importedCount == 1 ? '' : 's'} imported successfully.',
                          style: const TextStyle(color: AppColors.success),
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}
