import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/inputs/gallery_image_picker.dart';
import '../../core/widgets/inputs/hero_image_picker.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/festival_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../domain/models/festival.dart';
import '../../domain/models/province.dart';

/// Create or edit a festival — the admin/lgu "Festivals" module's full
/// curatorial control.
class AdminFestivalFormScreen extends StatefulWidget {
  const AdminFestivalFormScreen({super.key, this.existing});

  final Festival? existing;

  @override
  State<AdminFestivalFormScreen> createState() =>
      _AdminFestivalFormScreenState();
}

class _AdminFestivalFormScreenState extends State<AdminFestivalFormScreen> {
  final FestivalRepository _repository = FestivalRepository();

  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late String _heroImageUrl = widget.existing?.heroImageUrl ?? '';
  // The full `galleryImageUrls` a details screen swipes through is
  // [hero, ...these] (deduped) — kept separate here so the "More Photos"
  // picker below never shows the cover photo a second time.
  late List<String> _additionalGalleryUrls = [
    ...?widget.existing?.galleryImageUrls,
  ]..remove(widget.existing?.heroImageUrl ?? '');
  late final _descController = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  final _newHighlightController = TextEditingController();

  /// Picked via [_pickDate] below. Null means "not picked/changed in this
  /// session" — on save, a null [_startDate] falls back to whatever
  /// structured date (or, for pre-migration records, formatted label) the
  /// festival already had, so opening an old festival for an unrelated edit
  /// never blanks out its date. See [_save] for that fallback chain.
  DateTime? _startDate;
  DateTime? _endDate;

  late List<String> _highlights = [...?widget.existing?.highlights];
  late bool _isUpcoming = widget.existing?.isUpcoming ?? true;
  Province? _selectedProvince;
  late Future<List<Province>> _provincesFuture;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _startDate = widget.existing?.startDate;
    _endDate = widget.existing?.endDate;
    _provincesFuture = ProvinceRepository().getAll().then((provinces) {
      final existingId = widget.existing?.provinceId;
      if (existingId != null) {
        for (final p in provinces) {
          if (p.id == existingId) {
            _selectedProvince = p;
            break;
          }
        }
      }
      return provinces..sort((a, b) => a.name.compareTo(b.name));
    });
  }

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _descController,
      _newHighlightController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// "January 18, 2026" for a single day, "February 1–28, 2026" for a range
  /// within one month, "March 28 – April 4, 2026" across months — matching
  /// the formatting festival cards/details already display.
  String _formatDateLabel(DateTime start, DateTime? end) {
    if (end == null || DateUtils.isSameDay(start, end)) {
      return DateFormat('MMMM d, yyyy').format(start);
    }
    if (start.year == end.year && start.month == end.month) {
      return '${DateFormat('MMMM d').format(start)}–${end.day}, ${end.year}';
    }
    return '${DateFormat('MMMM d').format(start)} – ${DateFormat('MMMM d, yyyy').format(end)}';
  }

  String _formatMonthBadge(DateTime start) =>
      DateFormat('MMM').format(start).toUpperCase();

  /// What the date field shows: the newly-picked range/day, else (for a
  /// festival that hasn't had its date migrated to the picker yet) the
  /// original formatted label, else a prompt to pick one.
  String get _dateDisplayText {
    final start = _startDate;
    if (start != null) return _formatDateLabel(start, _endDate);
    final existingLabel = widget.existing?.dateLabel ?? '';
    return existingLabel.isNotEmpty ? existingLabel : 'Select date';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialStart = _startDate ?? now;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDateRange: DateTimeRange(
        start: initialStart,
        end: _endDate ?? initialStart,
      ),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked.start;
      _endDate = DateUtils.isSameDay(picked.start, picked.end)
          ? null
          : picked.end;
    });
  }

  Future<void> _save() async {
    final province = _selectedProvince;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name is required.')));
      return;
    }
    if (province == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Province is required.')));
      return;
    }
    final startDate = _startDate ?? widget.existing?.startDate;
    final endDate = _startDate != null ? _endDate : widget.existing?.endDate;
    final dateLabel = startDate != null
        ? _formatDateLabel(startDate, endDate)
        : (widget.existing?.dateLabel ?? '');
    final month = startDate != null
        ? _formatMonthBadge(startDate)
        : (widget.existing?.month ?? '');
    if (dateLabel.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Date is required.')));
      return;
    }

    setState(() => _saving = true);
    final festival = Festival(
      id: widget.existing?.id ?? '',
      name: _nameController.text.trim(),
      provinceId: province.id,
      provinceName: province.name,
      regionId: province.regionId,
      heroImageUrl: _heroImageUrl,
      galleryImageUrls: _heroImageUrl.isEmpty
          ? _additionalGalleryUrls
          : [
              _heroImageUrl,
              ..._additionalGalleryUrls.where((u) => u != _heroImageUrl),
            ],
      dateLabel: dateLabel,
      month: month,
      startDate: startDate,
      endDate: endDate,
      description: _descController.text.trim(),
      highlights: _highlights,
      rating: widget.existing?.rating ?? 0,
      reviewCount: widget.existing?.reviewCount ?? 0,
      isUpcoming: _isUpcoming,
      organizer: widget.existing?.organizer ?? '',
      registrationLink: widget.existing?.registrationLink ?? '',
      venue: widget.existing?.venue ?? '',
      facebookUrl: widget.existing?.facebookUrl ?? '',
      latitude: widget.existing?.latitude,
      longitude: widget.existing?.longitude,
    );

    try {
      if (_isEditing) {
        await _repository.update(widget.existing!.id, festival);
      } else {
        await _repository.create(festival);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Festival updated.' : 'Festival created.',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(_isEditing ? 'Edit Festival' : 'New Festival'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<Province>>(
          future: _provincesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return LoadingWidget.block(height: 400);
            }
            final provinces = snapshot.data ?? const [];
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.huge,
              ),
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<Province>(
                  initialValue: _selectedProvince,
                  decoration: const InputDecoration(labelText: 'Province'),
                  isExpanded: true,
                  items: provinces
                      .map(
                        (p) => DropdownMenuItem(value: p, child: Text(p.name)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedProvince = value),
                ),
                const SizedBox(height: AppSpacing.md),
                HeroImagePicker(
                  imageUrl: _heroImageUrl,
                  label: 'Cover Photo',
                  folder: FirestorePaths.storageDestinationPhotos,
                  ownerId:
                      context.read<AuthProvider>().firebaseUser?.uid ?? 'admin',
                  onChanged: (url) => setState(() => _heroImageUrl = url),
                ),
                const SizedBox(height: AppSpacing.md),
                GalleryImagePicker(
                  imageUrls: _additionalGalleryUrls,
                  label:
                      'More Photos (for the swipeable gallery on the details page)',
                  folder: FirestorePaths.storageDestinationPhotos,
                  ownerId:
                      context.read<AuthProvider>().firebaseUser?.uid ?? 'admin',
                  onChanged: (urls) =>
                      setState(() => _additionalGalleryUrls = urls),
                ),
                const SizedBox(height: AppSpacing.md),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Symbols.calendar_month_rounded),
                    ),
                    child: Text(_dateDisplayText),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _descController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Upcoming'),
                  value: _isUpcoming,
                  onChanged: (value) => setState(() => _isUpcoming = value),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Highlights', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                ..._highlights.asMap().entries.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value),
                    trailing: IconButton(
                      icon: const Icon(Symbols.close_rounded, size: 18),
                      onPressed: () => setState(
                        () =>
                            _highlights = [..._highlights]..removeAt(entry.key),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newHighlightController,
                        decoration: const InputDecoration(
                          hintText: 'Add a highlight...',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Symbols.add_circle_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () {
                        final text = _newHighlightController.text.trim();
                        if (text.isEmpty) return;
                        setState(() {
                          _highlights = [..._highlights, text];
                          _newHighlightController.clear();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                AnimatedButton(
                  label: _isEditing ? 'Save Changes' : 'Create',
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
