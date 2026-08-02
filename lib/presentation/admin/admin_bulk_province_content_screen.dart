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
import '../../data/repositories/province_repository.dart';
import '../../domain/models/province.dart';

/// One parsed CSV data row — either a real, existing [Province] matched by
/// id plus the new content to write onto it, or a validation failure with a
/// human-readable reason.
class _ParsedRow {
  _ParsedRow({
    required this.rowNumber,
    this.province,
    this.content,
    this.error,
  });

  final int rowNumber;
  final Province? province;
  final _ParsedContent? content;
  final String? error;
  bool get isValid => province != null && content != null;
}

class _ParsedContent {
  const _ParsedContent({
    required this.overview,
    required this.localCulture,
    required this.bestTimeToVisit,
    required this.estimatedDailyBudgetMin,
    required this.estimatedDailyBudgetMax,
    required this.travelTips,
  });

  final String overview;
  final String localCulture;
  final String bestTimeToVisit;
  final double estimatedDailyBudgetMin;
  final double estimatedDailyBudgetMax;
  final List<String> travelTips;
}

/// Admin-only: fill in the "content coming soon" overview/culture/best-
/// time-to-visit/budget fields for many provinces at once from a CSV,
/// instead of opening `AdminProvinceEditScreen` one province at a time.
/// Unlike the tourist-spots bulk import, provinces already exist as rows
/// (the fixed 83-doc taxonomy) — this only ever *updates* an existing
/// province matched by id, through the exact same
/// `ProvinceRepository.updateContent()` the manual edit form already uses
/// (which also flips `hasContent` to true, clearing "content coming soon").
/// A row's hero image, gallery and emergency hotlines are preserved
/// unchanged from whatever the province already has — this tool is only
/// ever for the text/budget fields a CSV can reasonably carry.
class AdminBulkProvinceContentScreen extends StatefulWidget {
  const AdminBulkProvinceContentScreen({super.key, this.provinceRepository});

  // Test-only override — production call sites never pass this.
  final ProvinceRepository? provinceRepository;

  @override
  State<AdminBulkProvinceContentScreen> createState() =>
      _AdminBulkProvinceContentScreenState();
}

class _AdminBulkProvinceContentScreenState
    extends State<AdminBulkProvinceContentScreen> {
  late final ProvinceRepository _repository =
      widget.provinceRepository ?? ProvinceRepository();

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
      final provinces = await _repository.getAll();
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
    final provinceId = map['provinceId'] ?? '';
    final matchingProvinces = _provinces.where((p) => p.id == provinceId);
    if (matchingProvinces.isEmpty) {
      return _ParsedRow(
        rowNumber: rowNumber,
        error: 'Unknown provinceId "$provinceId"',
      );
    }
    final province = matchingProvinces.first;

    final overview = map['overview'] ?? '';
    if (overview.isEmpty) {
      return _ParsedRow(rowNumber: rowNumber, error: 'Missing overview');
    }

    double parseBudget(String? v) =>
        (v == null || v.isEmpty) ? 0 : (double.tryParse(v) ?? 0);
    List<String> parseTips(String? v) => (v == null || v.isEmpty)
        ? const []
        : v.split(';').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

    return _ParsedRow(
      rowNumber: rowNumber,
      province: province,
      content: _ParsedContent(
        overview: overview,
        localCulture: map['localCulture'] ?? '',
        bestTimeToVisit: map['bestTimeToVisit'] ?? '',
        estimatedDailyBudgetMin: parseBudget(map['estimatedDailyBudgetMin']),
        estimatedDailyBudgetMax: parseBudget(map['estimatedDailyBudgetMax']),
        travelTips: parseTips(map['travelTips']),
      ),
    );
  }

  Future<void> _import() async {
    final validRows = _rows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) return;
    final confirmed = await showConfirmationDialog(
      context,
      title:
          'Update ${validRows.length} province${validRows.length == 1 ? '' : 's'}?',
      message:
          'This overwrites the overview, local culture, best time to visit and budget guide for '
          '${validRows.length} province(s) right away. Travel tips, hero image and gallery are left as-is '
          'unless a row also carries new travel tips.',
      confirmLabel: 'Update',
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
      final province = row.province!;
      final content = row.content!;
      try {
        await _repository.updateContent(
          province.id,
          overview: content.overview,
          localCulture: content.localCulture,
          bestTimeToVisit: content.bestTimeToVisit,
          estimatedDailyBudgetMin: content.estimatedDailyBudgetMin,
          estimatedDailyBudgetMax: content.estimatedDailyBudgetMax,
          travelTips: content.travelTips,
          emergencyHotlines: province.emergencyHotlines,
          heroImageUrl: province.heroImageUrl,
          galleryImageUrls: province.galleryImageUrls,
        );
        imported++;
        if (mounted) setState(() => _importedCount = imported);
      } catch (e) {
        errors.add(
          'Row ${row.rowNumber} (${province.name}): ${AppException.from(e).message}',
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
        title: const Text('Bulk Fill Province Content'),
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
                    'Upload a CSV to fill in overview, local culture, best time to visit and budget guidance for '
                    'many provinces at once, instead of one at a time. Required columns: provinceId, overview. '
                    'Optional: localCulture, bestTimeToVisit, estimatedDailyBudgetMin, estimatedDailyBudgetMax, '
                    'travelTips (separate multiple tips with a semicolon).',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'provinceId must match an existing province exactly — check the Provinces list for the '
                    'correct id. Hero image, gallery and emergency hotlines are never touched by this tool.',
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
                              ? row.province!.name
                              : 'Row ${row.rowNumber}',
                        ),
                        subtitle: Text(
                          row.isValid ? row.content!.overview : row.error!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (validCount > 0)
                      FilledButton(
                        onPressed: _importing ? null : _import,
                        child: _importing
                            ? Text('Updating $_importedCount/$validCount...')
                            : Text(
                                'Update $validCount Province${validCount == 1 ? '' : 's'}',
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
                          '$_importedCount province${_importedCount == 1 ? '' : 's'} updated successfully.',
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
