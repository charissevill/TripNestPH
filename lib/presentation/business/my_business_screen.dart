import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/ocr_service.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/province_matcher.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/dialogs/discard_changes_scope.dart';
import '../../core/widgets/inputs/hero_image_picker.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/business_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../domain/models/business.dart';
import '../../domain/models/province.dart';
import '../../domain/models/restaurant.dart' show MenuItem;
import '../ai_planner/widgets/map_destination_picker.dart';
import '../../core/widgets/media/image_error_placeholder.dart';

const List<String> _priceRanges = ['₱', '₱₱', '₱₱₱', '₱₱₱₱'];

/// Display-only labels for [_priceRanges] — the stacked peso signs alone
/// (e.g. "₱₱₱") read as unclear at small sizes, easy to mistake for a
/// rendering glitch rather than a deliberate "how expensive" tier. The
/// stored value itself stays just the bare peso signs, unchanged.
const Map<String, String> _priceRangeLabels = {
  '₱': '₱ · Budget',
  '₱₱': '₱₱ · Moderate',
  '₱₱₱': '₱₱₱ · Pricey',
  '₱₱₱₱': '₱₱₱₱ · Fine Dining',
};

/// The [MenuItem]-backed catalog section (name/price/photo per entry)
/// isn't food-specific at all — every category has some equivalent list a
/// traveler would want to see (a cafe's menu, a hotel's room types, a tour
/// operator's packages). Same [MenuItem] model and editor UI throughout;
/// only these labels change per [BusinessCategory].
class _CatalogLabels {
  const _CatalogLabels({
    required this.icon,
    required this.sectionLabel,
    required this.itemLabel,
    required this.emptyHint,
  });

  final IconData icon;
  final String sectionLabel;
  final String itemLabel;
  final String emptyHint;
}

const Map<String, _CatalogLabels> _catalogLabelsByCategory = {
  BusinessCategory.foodAndDining: _CatalogLabels(
    icon: Symbols.restaurant_menu_rounded,
    sectionLabel: 'Menu',
    itemLabel: 'Menu Item',
    emptyHint: 'No menu items yet — add a few so travelers know what to order.',
  ),
  BusinessCategory.accommodation: _CatalogLabels(
    icon: Symbols.bed_rounded,
    sectionLabel: 'Rooms',
    itemLabel: 'Room',
    emptyHint:
        'No room types yet — add a few so travelers know what\'s available.',
  ),
  BusinessCategory.tourOperator: _CatalogLabels(
    icon: Symbols.tour_rounded,
    sectionLabel: 'Packages',
    itemLabel: 'Package',
    emptyHint:
        'No tour packages yet — add a few so travelers know what you offer.',
  ),
  BusinessCategory.shop: _CatalogLabels(
    icon: Symbols.shopping_bag_rounded,
    sectionLabel: 'Products',
    itemLabel: 'Product',
    emptyHint: 'No products yet — add a few so travelers know what you sell.',
  ),
  BusinessCategory.transport: _CatalogLabels(
    icon: Symbols.directions_car_rounded,
    sectionLabel: 'Services',
    itemLabel: 'Service',
    emptyHint: 'No services yet — add a few so travelers know what you offer.',
  ),
  BusinessCategory.other: _CatalogLabels(
    icon: Symbols.inventory_2_rounded,
    sectionLabel: 'Items',
    itemLabel: 'Item',
    emptyHint: 'No items yet — add a few so travelers know what you offer.',
  ),
};

/// A `businessOwner` account's self-service listing. Shows the owner's
/// current listing (any status) with an edit form, or an empty "create
/// yours" state if they haven't listed one yet. Writes go through
/// [BusinessRepository], which matches `firestore.rules`'s owner-scoped
/// permissions exactly — the resubmit-after-rejection flow is a single
/// button, not a separate screen.
class MyBusinessScreen extends StatefulWidget {
  const MyBusinessScreen({
    super.key,
    required this.uid,
    this.showBackButton = true,
  });

  final String uid;

  /// False when this renders as the businessOwner shell tab's own root
  /// (see `SavedOrMyBusinessTab`) — a top-level tab has nothing to pop back
  /// to, same as Home/Explore/etc. never showing a back arrow either. True
  /// (default) for the standalone pushed route reached from Profile.
  final bool showBackButton;

  @override
  State<MyBusinessScreen> createState() => _MyBusinessScreenState();
}

class _MyBusinessScreenState extends State<MyBusinessScreen> {
  final BusinessRepository _repository = BusinessRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<Business>>(
          stream: _repository.streamForOwner(widget.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return LoadingWidget.block(height: 300);
            }
            final businesses = snapshot.data ?? const [];
            final existing = businesses.isEmpty ? null : businesses.first;
            // Keyed by the listing's own id (or a fixed sentinel when
            // there isn't one yet): _BusinessFormState's text controllers
            // are `late final`, seeded once from `widget.existing` at
            // first build — without this key, a live stream update that
            // goes from "no listing yet" to "listing just created" (or
            // between two different listings) reuses the same State object
            // and those controllers silently keep their stale (often
            // empty) text forever, even though `existing` itself updated.
            // A new key forces Flutter to mount a fresh State — and so
            // re-seed every field — whenever the underlying listing
            // identity actually changes.
            return _BusinessForm(
              key: ValueKey(existing?.id ?? 'new'),
              uid: widget.uid,
              existing: existing,
              showBackButton: widget.showBackButton,
            );
          },
        ),
      ),
    );
  }
}

class _BusinessForm extends StatefulWidget {
  const _BusinessForm({
    super.key,
    required this.uid,
    this.existing,
    this.showBackButton = true,
  });

  final String uid;
  final Business? existing;

  /// See [MyBusinessScreen.showBackButton]'s doc comment.
  final bool showBackButton;

  @override
  State<_BusinessForm> createState() => _BusinessFormState();
}

class _BusinessFormState extends State<_BusinessForm> {
  final BusinessRepository _repository = BusinessRepository();
  final RestaurantRepository _restaurantRepository = RestaurantRepository();
  final _formKey = GlobalKey<FormState>();

  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final _descController = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _addressController = TextEditingController(
    text: widget.existing?.address ?? '',
  );
  late final _contactController = TextEditingController(
    text: widget.existing?.contactNumber ?? '',
  );
  late final _websiteController = TextEditingController(
    text: widget.existing?.websiteUrl ?? '',
  );
  late final _cuisineController = TextEditingController(
    text: widget.existing?.cuisine ?? '',
  );
  late final _openingHoursController = TextEditingController(
    text: widget.existing?.openingHours ?? '',
  );
  late String _heroImageUrl = widget.existing?.heroImageUrl ?? '';
  // Lives outside Business (see BusinessPermit's doc comment) — fetched
  // separately in initState below since it's not part of widget.existing.
  String _permitUrl = '';
  late String _priceRange = _priceRanges.contains(widget.existing?.priceRange)
      ? widget.existing!.priceRange
      : _priceRanges.first;

  late String _category =
      widget.existing?.category ?? BusinessCategory.accommodation;
  late final Set<String> _accessibilityTags = {
    ...(widget.existing?.accessibilityTags ?? const []),
  };
  late final List<MenuItem> _menuItems = [
    ...(widget.existing?.menuItems ?? const []),
  ];
  late double? _latitude = widget.existing?.latitude;
  late double? _longitude = widget.existing?.longitude;
  Province? _selectedProvince;
  late Future<List<Province>> _provincesFuture;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _nameController,
      _descController,
      _addressController,
      _contactController,
      _websiteController,
      _cuisineController,
      _openingHoursController,
    ]) {
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
    final existingId = widget.existing?.id;
    if (existingId != null && existingId.isNotEmpty) {
      _repository.getPermit(existingId).then((permit) {
        if (mounted) setState(() => _permitUrl = permit?.permitUrl ?? '');
      });
    }
  }

  /// The Address field's map-pin shortcut — same [MapDestinationPicker]
  /// "search or tap a spot" flow the manual itinerary flow already uses,
  /// rather than a traveler having to type the address out by hand. Also
  /// auto-selects the matching province when one isn't picked yet (see
  /// [matchProvinceByAddress]), best-effort — a resolved address the
  /// province list can't match just leaves that dropdown as it was.
  Future<void> _pickAddressOnMap() async {
    final picked = await Navigator.of(context).push<MapPickedLocation>(
      MaterialPageRoute(
        builder: (context) =>
            const MapDestinationPicker(title: 'Pin Your Business Location'),
      ),
    );
    if (picked == null || !mounted) return;
    _addressController.text = picked.name;
    setState(() {
      _latitude = picked.latitude;
      _longitude = picked.longitude;
      _dirty = true;
    });
    if (_selectedProvince == null) {
      final provinces = await _provincesFuture;
      if (!mounted) return;
      final matched = matchProvinceByAddress(picked.name, provinces);
      if (matched != null) setState(() => _selectedProvince = matched);
    }
  }

  Future<void> _addMenuItem(String itemLabel) async {
    final item = await showDialog<MenuItem>(
      context: context,
      builder: (context) =>
          _AddMenuItemDialog(ownerId: widget.uid, itemLabel: itemLabel),
    );
    if (item == null) return;
    setState(() {
      _menuItems.add(item);
      _dirty = true;
    });
  }

  /// Confirms before removing a catalog entry — an accidental tap on the
  /// row's delete icon otherwise had no way back short of re-adding the
  /// item (photo included) from scratch.
  Future<void> _deleteMenuItem(int index, String itemLabel) async {
    final item = _menuItems[index];
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Remove $itemLabel?',
      message: '"${item.name}" will be removed from your listing.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _menuItems.removeAt(index);
      _dirty = true;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _descController,
      _addressController,
      _contactController,
      _websiteController,
      _cuisineController,
      _openingHoursController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save({bool resubmit = false}) async {
    if (!_formKey.currentState!.validate()) return;
    final province = _selectedProvince;
    if (province == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Province is required.')));
      return;
    }
    if (_heroImageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a photo for your listing.'),
        ),
      );
      return;
    }

    // Only nudge on an actual submission (first-time or resubmit-after-
    // rejection) — an already-approved owner just saving an unrelated edit
    // shouldn't be re-asked about a permit they've already deliberately
    // left out.
    final isSubmission = widget.existing == null || resubmit;
    if (isSubmission && _permitUrl.isEmpty && mounted) {
      final proceed = await showConfirmationDialog(
        context,
        title: 'Submit without a permit photo?',
        message:
            'A Business Permit or DTI Registration photo speeds up approval '
            'since the admin has less to manually verify. You can still '
            'submit without one — an admin may ask for it later.',
        confirmLabel: 'Submit Anyway',
      );
      if (!proceed || !mounted) return;
    }

    setState(() => _saving = true);
    final business = Business(
      id: widget.existing?.id ?? '',
      ownerId: widget.uid,
      name: _nameController.text.trim(),
      category: _category,
      description: _descController.text.trim(),
      provinceId: province.id,
      provinceName: province.name,
      regionId: province.regionId,
      address: _addressController.text.trim(),
      contactNumber: _contactController.text.trim(),
      websiteUrl: _websiteController.text.trim(),
      heroImageUrl: _heroImageUrl,
      cuisine: _category == BusinessCategory.foodAndDining
          ? _cuisineController.text.trim()
          : '',
      priceRange: _priceRange,
      openingHours: _category == BusinessCategory.foodAndDining
          ? _openingHoursController.text.trim()
          : '',
      accessibilityTags: _accessibilityTags.toList(),
      menuItems: _menuItems,
      latitude: _latitude,
      longitude: _longitude,
    );

    try {
      final String id;
      if (widget.existing == null) {
        id = await _repository.create(business);
      } else if (resubmit) {
        id = widget.existing!.id;
        await _repository.resubmit(id, business);
      } else {
        id = widget.existing!.id;
        await _repository.update(id, business);
        // Already approved and linked to a restaurant — keep it in sync
        // with this edit (see the class doc on Business).
        final restaurantId = widget.existing!.restaurantId;
        if (restaurantId.isNotEmpty) {
          await _restaurantRepository.updateFromBusiness(
            restaurantId,
            business,
          );
        }
      }
      // Separate write — see BusinessPermit's doc comment for why permit
      // data lives outside the main doc. permitOcrText is deliberately not
      // set here: extractPermitText (the Cloud Function) is the only thing
      // that's ever allowed to write it, so it always reflects real Vision
      // output and never something the client claims on its own.
      await _repository.setPermitUrl(id, _permitUrl);
      if (_permitUrl.isNotEmpty) {
        unawaited(OcrService().extractText(id).catchError((_) => ''));
      }
      if (mounted) {
        _dirty = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existing == null
                  ? 'Listing submitted for review.'
                  : 'Listing updated.',
            ),
          ),
        );
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

  Future<void> _contactSupport(Business business) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@tripnestph.app',
      query:
          'subject=${Uri.encodeComponent('Suspended listing: ${business.name}')}'
          '&body=${Uri.encodeComponent('Listing: ${business.name} (${business.id})\n\n')}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email support@tripnestph.app for help with this listing.',
          ),
        ),
      );
    }
  }

  Widget _statusBanner(Business business) {
    final theme = Theme.of(context);
    switch (business.status) {
      case 'approved':
        return _Banner(
          color: AppColors.success,
          icon: Symbols.check_circle_rounded,
          text: 'Live — travelers can see this listing on your province page.',
        );
      case 'rejected':
        return _Banner(
          color: AppColors.error,
          icon: Symbols.error_rounded,
          text: business.rejectionReason.isEmpty
              ? 'Rejected. Edit and resubmit below.'
              : 'Rejected: ${business.rejectionReason}\nEdit and resubmit below.',
        );
      case 'suspended':
        return _Banner(
          color: AppColors.error,
          icon: Symbols.block_rounded,
          text: business.rejectionReason.isEmpty
              ? 'Suspended by an admin — contact support if you believe this is a mistake.'
              : 'Suspended: ${business.rejectionReason}\nContact support if you believe this is a mistake.',
        );
      default:
        return _Banner(
          color: AppColors.warning,
          icon: Symbols.hourglass_top_rounded,
          text: 'Pending review.',
          textStyle: theme.textTheme.bodyMedium,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Province>>(
      future: _provincesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return LoadingWidget.block(height: 400);
        }
        final provinces = snapshot.data ?? const [];
        final existing = widget.existing;
        final theme = Theme.of(context);
        final catalog =
            _catalogLabelsByCategory[_category] ??
            _catalogLabelsByCategory[BusinessCategory.other]!;
        return DiscardChangesScope(
          isDirty: _dirty,
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
                // Same bare "large title, no AppBar" convention every other
                // top-level tab uses (Home/Explore/Saved/Profile) — a plain
                // Scaffold AppBar here looked visually inconsistent with the
                // rest of the shell. Only shows a back arrow when reached as
                // a standalone pushed route (see [showBackButton]'s doc
                // comment) — a tab root has nothing to pop back to.
                Row(
                  children: [
                    if (widget.showBackButton) ...[
                      IconButton(
                        icon: const Icon(Symbols.arrow_back_rounded),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text('My Business', style: theme.textTheme.displayMedium),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (existing != null) ...[
                  _statusBanner(existing),
                  if (existing.isSuspended) ...[
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () => _contactSupport(existing),
                      icon: const Icon(Symbols.mail_rounded, size: 18),
                      label: const Text('Contact Support'),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                ],
                Stack(
                  children: [
                    HeroImagePicker(
                      imageUrl: _heroImageUrl,
                      folder: FirestorePaths.storageBusinessGallery,
                      ownerId: widget.uid,
                      onChanged: (url) => setState(() {
                        _heroImageUrl = url;
                        _dirty = true;
                      }),
                    ),
                    if (_heroImageUrl.isEmpty)
                      Positioned(
                        left: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error.withValues(
                                alpha: 0.9,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              'Required',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _SectionCard(
                  icon: Symbols.storefront_rounded,
                  label: 'Basic Information',
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Business Name',
                        prefixIcon: Icon(Symbols.storefront_rounded, size: 20),
                      ),
                      validator: Validators.name,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: BusinessCategory.all
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(BusinessCategory.label(c)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        _category = value ?? _category;
                        _dirty = true;
                      }),
                    ),
                    if (_category == BusinessCategory.foodAndDining) ...[
                      TextFormField(
                        controller: _cuisineController,
                        decoration: const InputDecoration(
                          labelText: 'Cuisine',
                          hintText: 'e.g. Filipino, Seafood',
                          prefixIcon: Icon(
                            Symbols.restaurant_rounded,
                            size: 20,
                          ),
                        ),
                        validator: (v) =>
                            Validators.required(v, label: 'Cuisine'),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _priceRange,
                        decoration: const InputDecoration(
                          labelText: 'Price Range',
                        ),
                        items: _priceRanges
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(_priceRangeLabels[p] ?? p),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          _priceRange = value ?? _priceRange;
                          _dirty = true;
                        }),
                      ),
                      TextFormField(
                        controller: _openingHoursController,
                        decoration: const InputDecoration(
                          labelText: 'Opening Hours',
                          hintText: 'e.g. 10:00 AM – 9:00 PM daily',
                          prefixIcon: Icon(Symbols.schedule_rounded, size: 20),
                        ),
                        validator: (v) =>
                            Validators.required(v, label: 'Opening hours'),
                      ),
                    ],
                    TextFormField(
                      controller: _descController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Symbols.description_rounded, size: 20),
                      ),
                      validator: (v) =>
                          Validators.required(v, label: 'Description') ??
                          Validators.maxLength(v, 3000, label: 'Description'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  icon: catalog.icon,
                  label: catalog.sectionLabel,
                  children: [
                    if (_menuItems.isEmpty)
                      Text(
                        catalog.emptyHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      ...List.generate(_menuItems.length, (i) {
                        final item = _menuItems[i];
                        return _MenuItemRow(
                          item: item,
                          onDelete: () => _deleteMenuItem(i, catalog.itemLabel),
                        );
                      }),
                    OutlinedButton.icon(
                      onPressed: () => _addMenuItem(catalog.itemLabel),
                      icon: const Icon(Symbols.add_rounded, size: 18),
                      label: Text('Add ${catalog.itemLabel}'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  icon: Symbols.location_on_rounded,
                  label: 'Location & Contact',
                  children: [
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
                      onChanged: (value) => setState(() {
                        _selectedProvince = value;
                        _dirty = true;
                      }),
                    ),
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        prefixIcon: const Icon(
                          Symbols.location_on_rounded,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Symbols.map_rounded, size: 20),
                          tooltip: 'Pin on map',
                          onPressed: _pickAddressOnMap,
                        ),
                      ),
                      validator: (v) =>
                          Validators.required(v, label: 'Address'),
                    ),
                    TextFormField(
                      controller: _contactController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number',
                        prefixIcon: Icon(Symbols.call_rounded, size: 20),
                      ),
                      validator: (v) => Validators.phone(v, required: true),
                    ),
                    TextFormField(
                      controller: _websiteController,
                      decoration: const InputDecoration(
                        labelText: 'Website URL',
                        prefixIcon: Icon(Symbols.language_rounded, size: 20),
                      ),
                      validator: Validators.url,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  icon: Symbols.accessible_forward_rounded,
                  label: 'Accessibility',
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: kAccessibilityTagOptions.map((tag) {
                        final selected = _accessibilityTags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: selected,
                          onSelected: (v) => setState(() {
                            v
                                ? _accessibilityTags.add(tag)
                                : _accessibilityTags.remove(tag);
                            _dirty = true;
                          }),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  icon: Symbols.verified_rounded,
                  label: 'Verification',
                  children: [
                    Text(
                      'Optional, but speeds up admin approval.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    HeroImagePicker(
                      imageUrl: _permitUrl,
                      folder: FirestorePaths.storageBusinessPermits,
                      ownerId: widget.uid,
                      label: 'Business Permit / DTI Registration',
                      height: 140,
                      onChanged: (url) => setState(() {
                        _permitUrl = url;
                        _dirty = true;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                AnimatedButton(
                  label: existing == null
                      ? 'Submit for Review'
                      : (existing.isRejected
                            ? 'Edit & Resubmit'
                            : 'Save Changes'),
                  isLoading: _saving,
                  onPressed: () =>
                      _save(resubmit: existing?.isRejected ?? false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One row in the Menu section's editable list — a thumbnail, name, price,
/// and a delete action. Read-only otherwise (see [_AddMenuItemDialog] for
/// how an item is actually added); there's no separate "edit" flow since
/// deleting and re-adding a mispriced item is simpler than a second dialog
/// for a list this short.
class _MenuItemRow extends StatelessWidget {
  const _MenuItemRow({required this.item, required this.onDelete});

  final MenuItem item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: CachedNetworkImage(
              imageUrl: item.imageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) =>
                  const ImageErrorPlaceholder(width: 48, height: 48),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item.price,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.delete_outline_rounded, size: 20),
            color: AppColors.error,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// The "Add Menu Item" dialog — name, price and a required photo (see
/// `_MenuItemTile` on the restaurant details screen, which renders
/// [MenuItem.imageUrl] with no empty-URL fallback of its own). Pops the new
/// [MenuItem] on save, or null if cancelled.
class _AddMenuItemDialog extends StatefulWidget {
  const _AddMenuItemDialog({required this.ownerId, required this.itemLabel});

  final String ownerId;

  /// e.g. "Menu Item", "Room", "Package" — see [_CatalogLabels].
  final String itemLabel;

  @override
  State<_AddMenuItemDialog> createState() => _AddMenuItemDialogState();
}

class _AddMenuItemDialogState extends State<_AddMenuItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String _imageUrl = '';
  String? _imageError;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _save() {
    final formValid = _formKey.currentState!.validate();
    setState(
      () =>
          _imageError = _imageUrl.isEmpty ? 'Add a photo for this item.' : null,
    );
    if (!formValid || _imageUrl.isEmpty) return;
    Navigator.of(context).pop(
      MenuItem(
        name: _nameController.text.trim(),
        price: _priceController.text.trim(),
        imageUrl: _imageUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Scrolls on a short viewport (landscape, keyboard open) instead of overflowing.
      scrollable: true,
      title: Text('Add ${widget.itemLabel}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeroImagePicker(
                imageUrl: _imageUrl,
                folder: FirestorePaths.storageBusinessGallery,
                ownerId: widget.ownerId,
                label: 'Photo',
                height: 120,
                onChanged: (url) => setState(() {
                  _imageUrl = url;
                  _imageError = null;
                }),
              ),
              if (_imageError != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _imageError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '${widget.itemLabel} Name',
                  prefixIcon: const Icon(
                    Symbols.restaurant_menu_rounded,
                    size: 20,
                  ),
                ),
                validator: (v) =>
                    Validators.required(v, label: '${widget.itemLabel} name'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  hintText: 'e.g. ₱150',
                  prefixIcon: Icon(Symbols.payments_rounded, size: 20),
                ),
                validator: (v) => Validators.required(v, label: 'Price'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Add')),
      ],
    );
  }
}

/// A small icon + label heading — the top of every [_SectionCard].
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

/// Groups a set of related fields (Basic Information, Location & Contact,
/// Accessibility, Verification) into one visually distinct, softly
/// elevated card with its own [_SectionHeader] — replaces what used to be
/// one long undifferentiated list of fields, where nothing signaled where
/// one logical group ended and the next began.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.label,
    required this.children,
  });

  final IconData icon;
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(icon: icon, label: label),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.text,
    this.textStyle,
  });

  final Color color;
  final IconData icon;
  final String text;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: (textStyle ?? const TextStyle()).copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
