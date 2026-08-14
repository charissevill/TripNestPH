import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/dialogs/discard_changes_scope.dart';
import '../../core/widgets/inputs/gallery_image_picker.dart';
import '../../core/widgets/inputs/hero_image_picker.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/festival_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../domain/models/admin_user.dart';
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
  final _formKey = GlobalKey<FormState>();

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
  // Same reasoning as AdminTouristSpotFormScreen: this form previously had
  // no way to set coordinates on a brand-new festival at all, silently
  // breaking the map/directions on the details screen for every one an
  // admin created.
  late final _latitudeController = TextEditingController(
    text: widget.existing?.latitude?.toString() ?? '',
  );
  late final _longitudeController = TextEditingController(
    text: widget.existing?.longitude?.toString() ?? '',
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
  bool _dirty = false;

  /// An 'lgu' account only ever manages its own province (see
  /// `AdminUser.provinceId`'s doc comment), so the picker below is locked
  /// to it — mirrors `firestore.rules`' `canManageProvince` server-side.
  AdminUser? _admin;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _startDate = widget.existing?.startDate;
    _endDate = widget.existing?.endDate;
    for (final c in [_nameController, _descController, _latitudeController, _longitudeController]) {
      c.addListener(() => setState(() => _dirty = true));
    }
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
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;
    final admin = await AdminRepository().getById(uid);
    if (!mounted) return;
    setState(() => _admin = admin);
    if (admin?.role == AdminRole.lgu && admin?.provinceId != null && _selectedProvince == null) {
      final provinces = await _provincesFuture;
      final own = provinces.where((p) => p.id == admin!.provinceId).firstOrNull;
      if (own != null) setState(() => _selectedProvince = own);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _descController,
      _latitudeController,
      _longitudeController,
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
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final province = _selectedProvince;
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
      latitude: double.tryParse(_latitudeController.text.trim()),
      longitude: double.tryParse(_longitudeController.text.trim()),
    );

    try {
      if (_isEditing) {
        await _repository.update(widget.existing!.id, festival);
      } else {
        await _repository.create(festival);
      }
      if (mounted) {
        _dirty = false;
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
    return DiscardChangesScope(
      isDirty: _dirty,
      child: Scaffold(
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
              return Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.huge,
                  ),
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Symbols.title_rounded, size: 20),
                      ),
                      validator: Validators.name,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<Province>(
                      initialValue: _selectedProvince,
                      decoration: const InputDecoration(labelText: 'Province'),
                      isExpanded: true,
                      items: provinces
                          .map(
                            (p) =>
                                DropdownMenuItem(value: p, child: Text(p.name)),
                          )
                          .toList(),
                      // An LGU account can't reassign a festival to a
                      // different province — see the field's doc comment.
                      onChanged: _admin?.role == AdminRole.lgu
                          ? null
                          : (value) => setState(() {
                              _selectedProvince = value;
                              _dirty = true;
                            }),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    HeroImagePicker(
                      imageUrl: _heroImageUrl,
                      label: 'Cover Photo',
                      folder: FirestorePaths.storageDestinationPhotos,
                      ownerId:
                          context.read<AuthProvider>().firebaseUser?.uid ??
                          'admin',
                      onChanged: (url) => setState(() {
                        _heroImageUrl = url;
                        _dirty = true;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GalleryImagePicker(
                      imageUrls: _additionalGalleryUrls,
                      label:
                          'More Photos (for the swipeable gallery on the details page)',
                      folder: FirestorePaths.storageDestinationPhotos,
                      ownerId:
                          context.read<AuthProvider>().firebaseUser?.uid ??
                          'admin',
                      onChanged: (urls) => setState(() {
                        _additionalGalleryUrls = urls;
                        _dirty = true;
                      }),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latitudeController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            decoration: const InputDecoration(
                              labelText: 'Latitude (optional)',
                              hintText: 'e.g. 14.5995',
                              prefixIcon: Icon(Symbols.location_on_rounded, size: 20),
                            ),
                            validator: Validators.latitude,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextFormField(
                            controller: _longitudeController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            decoration: const InputDecoration(
                              labelText: 'Longitude (optional)',
                              hintText: 'e.g. 120.9842',
                            ),
                            validator: Validators.longitude,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        'Powers the map and "Get Directions" on the details screen — leave blank and those sections just won\'t show.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _descController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Symbols.description_rounded, size: 20),
                      ),
                      validator: (v) =>
                          Validators.maxLength(v, 3000, label: 'Description'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Upcoming'),
                      value: _isUpcoming,
                      onChanged: (value) => setState(() {
                        _isUpcoming = value;
                        _dirty = true;
                      }),
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
                          onPressed: () => setState(() {
                            _highlights = [..._highlights]..removeAt(entry.key);
                            _dirty = true;
                          }),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newHighlightController,
                            maxLength: 100,
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
                              _dirty = true;
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
