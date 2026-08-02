import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/dialogs/discard_changes_scope.dart';
import '../../core/widgets/inputs/gallery_image_picker.dart';
import '../../core/widgets/inputs/hero_image_picker.dart';
import '../../data/mock/mock_categories.dart';
import '../../data/repositories/destination_repository.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/province.dart';

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Create or edit a single tourist spot for [province] — used for both
/// flows so there's one form to keep in sync with [Destination]'s fields.
/// [existing] is null for "create", populated for "edit".
class AdminTouristSpotFormScreen extends StatefulWidget {
  const AdminTouristSpotFormScreen({
    super.key,
    required this.province,
    this.existing,
  });

  final Province province;
  final Destination? existing;

  @override
  State<AdminTouristSpotFormScreen> createState() =>
      _AdminTouristSpotFormScreenState();
}

class _AdminTouristSpotFormScreenState
    extends State<AdminTouristSpotFormScreen> {
  final DestinationRepository _repository = DestinationRepository();
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
  late final _shortDescController = TextEditingController(
    text: widget.existing?.shortDescription ?? '',
  );
  late final _longDescController = TextEditingController(
    text: widget.existing?.longDescription ?? '',
  );
  // Numbers-only field now (see the `Has Entrance Fee` switch below), so an
  // old free-text value like "₱75 per person" is reduced to just its digits
  // ("75") rather than shown as-is and immediately rejected by the field's
  // digits-only input formatter.
  late final _entranceFeeController = TextEditingController(
    text: widget.existing?.entranceFee.replaceAll(RegExp(r'[^0-9.]'), '') ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.existing?.phoneNumber ?? '',
  );
  late final _websiteController = TextEditingController(
    text: widget.existing?.websiteUrl ?? '',
  );
  late final _facebookController = TextEditingController(
    text: widget.existing?.facebookUrl ?? '',
  );
  final _newHighlightController = TextEditingController();
  final _newTipController = TextEditingController();

  /// Whether there's a fee at all — the text field for the amount/details
  /// only shows once this is on. Guessed from the existing free-text value
  /// for an already-seeded spot (anything not starting with "free" counts
  /// as having a fee); defaults to off (Free) for a brand-new spot.
  late bool _hasEntranceFee =
      widget.existing != null &&
      widget.existing!.entranceFee.trim().isNotEmpty &&
      !widget.existing!.entranceFee.trim().toLowerCase().startsWith('free');

  /// Opening/closing time pickers. Left null on load even when editing —
  /// the old free-text [Destination.openingHours] (e.g. "Fort Santiago:
  /// 8:00 AM – 7:00 PM daily") isn't reliably parseable back into a time —
  /// so an untouched pair falls back to the original string on save
  /// instead of guessing. See [_save].
  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;

  /// Same fallback-on-untouched reasoning as the time pickers above, for
  /// the same reason the old free-text [Destination.bestTimeToVisit] isn't
  /// reliably parseable back into a month.
  int? _bestTimeStartMonth;
  int? _bestTimeEndMonth;

  late String _categoryId =
      widget.existing?.categoryId ?? mockCategories.first.id;
  late List<String> _highlights = [...?widget.existing?.highlights];
  late List<String> _travelTips = [...?widget.existing?.travelTips];
  late bool _isFeatured = widget.existing?.isFeatured ?? false;
  late bool _isHiddenGem = widget.existing?.isHiddenGem ?? false;
  bool _saving = false;
  bool _dirty = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _nameController,
      _shortDescController,
      _longDescController,
      _entranceFeeController,
      _phoneController,
      _websiteController,
      _facebookController,
    ]) {
      c.addListener(() => setState(() => _dirty = true));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _shortDescController,
      _longDescController,
      _entranceFeeController,
      _phoneController,
      _websiteController,
      _facebookController,
      _newHighlightController,
      _newTipController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTime({required bool isOpening}) async {
    final initial =
        (isOpening ? _openingTime : _closingTime) ?? TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isOpening) {
        _openingTime = picked;
      } else {
        _closingTime = picked;
      }
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final openingHours = _openingTime != null && _closingTime != null
        ? '${_openingTime!.format(context)} – ${_closingTime!.format(context)} daily'
        : (widget.existing?.openingHours ?? '');
    final bestTimeToVisit =
        _bestTimeStartMonth != null && _bestTimeEndMonth != null
        ? (_bestTimeStartMonth == _bestTimeEndMonth
              ? _monthNames[_bestTimeStartMonth! - 1]
              : '${_monthNames[_bestTimeStartMonth! - 1]} to ${_monthNames[_bestTimeEndMonth! - 1]}')
        : (widget.existing?.bestTimeToVisit ?? '');

    setState(() => _saving = true);
    final destination = Destination(
      id: widget.existing?.id ?? '',
      name: _nameController.text.trim(),
      provinceId: widget.province.id,
      provinceName: widget.province.name,
      regionId: widget.province.regionId,
      categoryId: _categoryId,
      heroImageUrl: _heroImageUrl,
      galleryImageUrls: _heroImageUrl.isEmpty
          ? _additionalGalleryUrls
          : [
              _heroImageUrl,
              ..._additionalGalleryUrls.where((u) => u != _heroImageUrl),
            ],
      rating: widget.existing?.rating ?? 0,
      reviewCount: widget.existing?.reviewCount ?? 0,
      shortDescription: _shortDescController.text.trim(),
      longDescription: _longDescController.text.trim(),
      entranceFee:
          _hasEntranceFee && _entranceFeeController.text.trim().isNotEmpty
          ? '₱${_entranceFeeController.text.trim()}'
          : (_hasEntranceFee ? '' : 'Free'),
      bestTimeToVisit: bestTimeToVisit,
      travelTips: _travelTips,
      highlights: _highlights,
      isFeatured: _isFeatured,
      isHiddenGem: _isHiddenGem,
      latitude: widget.existing?.latitude,
      longitude: widget.existing?.longitude,
      phoneNumber: _phoneController.text.trim(),
      websiteUrl: _websiteController.text.trim(),
      facebookUrl: _facebookController.text.trim(),
      openingHours: openingHours,
    );

    try {
      if (_isEditing) {
        await _repository.update(widget.existing!.id, destination);
      } else {
        await _repository.create(destination);
      }
      if (mounted) {
        _dirty = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Tourist spot updated.' : 'Tourist spot created.',
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
          title: Text(_isEditing ? 'Edit Tourist Spot' : 'New Tourist Spot'),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.huge,
              ),
              children: [
                Text(
                  widget.province.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: Validators.name,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: mockCategories
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.label)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _categoryId = value ?? _categoryId;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                HeroImagePicker(
                  imageUrl: _heroImageUrl,
                  label: 'Cover Photo',
                  folder: FirestorePaths.storageDestinationPhotos,
                  ownerId:
                      context.read<AuthProvider>().firebaseUser?.uid ?? 'admin',
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
                      context.read<AuthProvider>().firebaseUser?.uid ?? 'admin',
                  onChanged: (urls) => setState(() {
                    _additionalGalleryUrls = urls;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _shortDescController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Short Description',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      Validators.maxLength(v, 300, label: 'Short Description'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _longDescController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Long Description',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      Validators.maxLength(v, 5000, label: 'Long Description'),
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Has Entrance Fee'),
                  value: _hasEntranceFee,
                  onChanged: (value) => setState(() {
                    _hasEntranceFee = value;
                    _dirty = true;
                  }),
                ),
                if (_hasEntranceFee) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _entranceFeeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Entrance Fee Amount (₱)',
                      hintText: 'e.g. 75',
                      prefixText: '₱ ',
                    ),
                    validator: (v) => Validators.amount(v, required: true, maxAmount: 100000),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                if (_openingTime == null &&
                    _closingTime == null &&
                    (widget.existing?.openingHours.isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      'Current: ${widget.existing!.openingHours}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _pickTime(isOpening: true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Opens',
                            prefixIcon: Icon(Symbols.schedule_rounded),
                          ),
                          child: Text(
                            _openingTime?.format(context) ?? 'Select time',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _pickTime(isOpening: false),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Closes',
                            prefixIcon: Icon(Symbols.schedule_rounded),
                          ),
                          child: Text(
                            _closingTime?.format(context) ?? 'Select time',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (_bestTimeStartMonth == null &&
                    _bestTimeEndMonth == null &&
                    (widget.existing?.bestTimeToVisit.isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      'Current: ${widget.existing!.bestTimeToVisit}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _bestTimeStartMonth,
                        decoration: const InputDecoration(
                          labelText: 'Best Time From',
                        ),
                        items: [
                          for (var m = 1; m <= 12; m++)
                            DropdownMenuItem(
                              value: m,
                              child: Text(_monthNames[m - 1]),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _bestTimeStartMonth = value;
                          _dirty = true;
                        }),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _bestTimeEndMonth,
                        decoration: const InputDecoration(
                          labelText: 'Best Time To',
                        ),
                        items: [
                          for (var m = 1; m <= 12; m++)
                            DropdownMenuItem(
                              value: m,
                              child: Text(_monthNames[m - 1]),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _bestTimeEndMonth = value;
                          _dirty = true;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  validator: Validators.phone,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _websiteController,
                  decoration: const InputDecoration(labelText: 'Website URL'),
                  validator: Validators.url,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _facebookController,
                  decoration: const InputDecoration(labelText: 'Facebook URL'),
                  validator: Validators.url,
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Featured'),
                  value: _isFeatured,
                  onChanged: (value) => setState(() {
                    _isFeatured = value;
                    _dirty = true;
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hidden Gem'),
                  value: _isHiddenGem,
                  onChanged: (value) => setState(() {
                    _isHiddenGem = value;
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
                const SizedBox(height: AppSpacing.lg),
                Text('Travel Tips', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                ..._travelTips.asMap().entries.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value),
                    trailing: IconButton(
                      icon: const Icon(Symbols.close_rounded, size: 18),
                      onPressed: () => setState(() {
                        _travelTips = [..._travelTips]..removeAt(entry.key);
                        _dirty = true;
                      }),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newTipController,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          hintText: 'Add a travel tip...',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Symbols.add_circle_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () {
                        final text = _newTipController.text.trim();
                        if (text.isEmpty) return;
                        setState(() {
                          _travelTips = [..._travelTips, text];
                          _newTipController.clear();
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
          ),
        ),
      ),
    );
  }
}
