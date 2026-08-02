import 'package:flutter/material.dart';
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
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/province_repository.dart';
import '../../domain/models/province.dart';

/// LGU/admin form for a single province's page content — the in-app answer
/// to Phase 1's "~68 provinces are still content coming soon" gap. Every
/// field here maps directly to what `ProvinceDetailsScreen` renders.
class AdminProvinceEditScreen extends StatefulWidget {
  const AdminProvinceEditScreen({super.key, required this.provinceId});

  final String provinceId;

  @override
  State<AdminProvinceEditScreen> createState() =>
      _AdminProvinceEditScreenState();
}

class _AdminProvinceEditScreenState extends State<AdminProvinceEditScreen> {
  final ProvinceRepository _repository = ProvinceRepository();
  final _formKey = GlobalKey<FormState>();
  late Future<Province?> _future;

  final _overviewController = TextEditingController();
  final _cultureController = TextEditingController();
  final _bestTimeController = TextEditingController();
  final _newTipController = TextEditingController();

  List<String> _travelTips = [];
  String _heroImageUrl = '';
  List<String> _galleryImageUrls = [];
  bool _saving = false;
  bool _loaded = false;
  bool _dirty = false;

  // No longer editable from this form (removed per request), but still
  // read from the existing doc and passed straight back through on save so
  // saving other fields doesn't silently wipe out data set some other way
  // (e.g. seeded content).
  double _budgetMin = 0;
  double _budgetMax = 0;
  List<EmergencyHotline> _hotlines = [];

  @override
  void initState() {
    super.initState();
    _future = _load();
    // Guarded by `_loaded` — `_load()` populates these same controllers
    // with the existing province content on first load, which must not
    // itself be treated as an unsaved edit.
    for (final c in [
      _overviewController,
      _cultureController,
      _bestTimeController,
    ]) {
      c.addListener(() {
        if (_loaded) setState(() => _dirty = true);
      });
    }
  }

  Future<Province?> _load() async {
    final province = await _repository.getById(widget.provinceId);
    if (province != null && !_loaded) {
      _overviewController.text = province.overview;
      _cultureController.text = province.localCulture;
      _bestTimeController.text = province.bestTimeToVisit;
      _budgetMin = province.estimatedDailyBudgetMin;
      _budgetMax = province.estimatedDailyBudgetMax;
      _heroImageUrl = province.heroImageUrl;
      _galleryImageUrls = [...province.galleryImageUrls];
      _travelTips = [...province.travelTips];
      _hotlines = [...province.emergencyHotlines];
      _loaded = true;
    }
    return province;
  }

  @override
  void dispose() {
    _overviewController.dispose();
    _cultureController.dispose();
    _bestTimeController.dispose();
    _newTipController.dispose();
    super.dispose();
  }

  void _addTip() {
    final text = _newTipController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _travelTips = [..._travelTips, text];
      _newTipController.clear();
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _repository.updateContent(
        widget.provinceId,
        overview: _overviewController.text.trim(),
        localCulture: _cultureController.text.trim(),
        bestTimeToVisit: _bestTimeController.text.trim(),
        estimatedDailyBudgetMin: _budgetMin,
        estimatedDailyBudgetMax: _budgetMax,
        travelTips: _travelTips,
        emergencyHotlines: _hotlines,
        heroImageUrl: _heroImageUrl,
        galleryImageUrls: _galleryImageUrls,
      );
      if (mounted) {
        _dirty = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Province content saved.')),
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
    return DiscardChangesScope(
      isDirty: _dirty,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Symbols.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: const Text('Edit Province'),
        ),
        body: SafeArea(
          child: FutureBuilder<Province?>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return LoadingWidget.block(height: 400);
              }
              final province = snapshot.data;
              if (province == null) {
                return const EmptyStateWidget(
                  icon: Symbols.error_outline_rounded,
                  title: 'Province not found',
                  message: 'This province no longer exists.',
                );
              }

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
                    Text(
                      province.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      province.regionName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _overviewController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Overview',
                        alignLabelWithHint: true,
                      ),
                      validator: (v) =>
                          Validators.maxLength(v, 3000, label: 'Overview'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _cultureController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Local Culture',
                        alignLabelWithHint: true,
                      ),
                      validator: (v) =>
                          Validators.maxLength(v, 3000, label: 'Local Culture'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _bestTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Best Time to Visit',
                      ),
                      validator: (v) => Validators.maxLength(
                        v,
                        200,
                        label: 'Best Time to Visit',
                      ),
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
                      imageUrls: _galleryImageUrls,
                      label:
                          'More Photos (for the swipeable gallery on the province page)',
                      folder: FirestorePaths.storageDestinationPhotos,
                      ownerId:
                          context.read<AuthProvider>().firebaseUser?.uid ??
                          'admin',
                      onChanged: (urls) => setState(() {
                        _galleryImageUrls = urls;
                        _dirty = true;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Travel Tips',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
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
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: _addTip,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    AnimatedButton(
                      label: 'Save',
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
