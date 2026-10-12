import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
import '../../core/widgets/inputs/ph_phone_field.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/business_owner_application_repository.dart';
import '../../data/repositories/business_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../domain/models/business.dart';
import '../../domain/models/business_owner_application.dart';
import '../../domain/models/province.dart';
import '../../domain/models/restaurant.dart' show MenuItem;
import '../ai_planner/widgets/map_destination_picker.dart';
import '../../core/widgets/media/image_error_placeholder.dart';
import '../../core/routes/back_navigation.dart';
import '../../core/routes/route_paths.dart';

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

// Ids for the form's collapsible sections — see _BusinessFormState._expanded.
const String _sectionBasic = 'basic';
const String _sectionCatalog = 'catalog';
const String _sectionLocation = 'location';
const String _sectionAccessibility = 'accessibility';
const String _sectionVerification = 'verification';

final RegExp _clockTimePattern = RegExp(
  r'(\d{1,2}):(\d{2})\s*([AP]M)',
  caseSensitive: false,
);

/// Always "9:00 PM", whatever the device's 12/24-hour setting — this is
/// what gets stored and shown to travelers, and what [_parseOpeningHours]
/// reads back.
String _formatClockTime(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
}

/// The opening and closing times in a stored "10:00 AM – 9:00 PM daily",
/// or null when [text] doesn't hold exactly two clock times.
(TimeOfDay, TimeOfDay)? _parseOpeningHours(String text) {
  final matches = _clockTimePattern.allMatches(text).toList();
  if (matches.length != 2) return null;
  TimeOfDay toTime(RegExpMatch m) {
    final isPm = m.group(3)!.toUpperCase() == 'PM';
    return TimeOfDay(
      hour: int.parse(m.group(1)!) % 12 + (isPm ? 12 : 0),
      minute: int.parse(m.group(2)!),
    );
  }

  return (toTime(matches[0]), toTime(matches[1]));
}

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

  /// Started at most once, and only once the owner turns out to have no
  /// listing yet — see [_BusinessForm.prefill].
  Future<BusinessOwnerApplication?>? _applicationFuture;

  /// Best-effort: a failed lookup just means an empty form, same as an
  /// owner who was invited directly and never filed an application.
  Future<BusinessOwnerApplication?> _loadApplication() async {
    try {
      return await BusinessOwnerApplicationRepository()
          .getLatestApprovedForUser(widget.uid);
    } catch (_) {
      return null;
    }
  }

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
            if (existing == null) {
              // Waits for the lookup before mounting the form at all: its
              // fields are seeded once at first build (see below), so a
              // prefill arriving any later would never reach them.
              return FutureBuilder<BusinessOwnerApplication?>(
                future: _applicationFuture ??= _loadApplication(),
                builder: (context, application) {
                  if (application.connectionState != ConnectionState.done) {
                    return LoadingWidget.block(height: 300);
                  }
                  return _BusinessForm(
                    key: const ValueKey('new'),
                    uid: widget.uid,
                    prefill: application.data,
                    showBackButton: widget.showBackButton,
                  );
                },
              );
            }
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
              key: ValueKey(existing.id),
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
    this.prefill,
    this.showBackButton = true,
  });

  final String uid;
  final Business? existing;

  /// The owner's approved application, passed only when there's no
  /// [existing] listing yet — seeds the name, category, address, map pin
  /// and permit photo they already gave on it. Everything stays editable.
  final BusinessOwnerApplication? prefill;

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
    text: widget.existing?.name ?? widget.prefill?.businessName ?? '',
  );
  late final _descController = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _addressController = TextEditingController(
    text: widget.existing?.address ?? widget.prefill?.address ?? '',
  );
  // Just the digits after +63 — see PhPhoneField.
  late final _contactController = TextEditingController(
    text: PhPhoneField.nationalDigits(widget.existing?.contactNumber ?? ''),
  );
  late final _websiteController = TextEditingController(
    text: widget.existing?.websiteUrl ?? '',
  );
  late final _cuisineController = TextEditingController(
    text: widget.existing?.cuisine ?? '',
  );
  /// Opening/closing time pickers, read back out of the stored string when
  /// it's one this form wrote. Older free text ("Open 24 hours") leaves
  /// both null, and an untouched pair keeps that original string on save.
  late TimeOfDay? _openingTime = _parseOpeningHours(
    widget.existing?.openingHours ?? '',
  )?.$1;
  late TimeOfDay? _closingTime = _parseOpeningHours(
    widget.existing?.openingHours ?? '',
  )?.$2;
  late String _heroImageUrl = widget.existing?.heroImageUrl ?? '';
  // Lives outside Business (see BusinessPermit's doc comment) — fetched
  // separately in initState below since it's not part of widget.existing.
  // A first listing starts from the permit photo already on the owner's
  // approved application instead.
  late String _permitUrl = widget.prefill?.permitUrl ?? '';
  // True while [_permitUrl] is still the photo an admin already checked on
  // that application — the Verification section then says so instead of
  // asking for it again. Cleared once the owner picks a different photo.
  late bool _permitFromApplication = _permitUrl.isNotEmpty;
  late String _priceRange = _priceRanges.contains(widget.existing?.priceRange)
      ? widget.existing!.priceRange
      : _priceRanges.first;

  late String _category =
      widget.existing?.category ??
      (BusinessCategory.all.contains(widget.prefill?.category)
          ? widget.prefill!.category
          : BusinessCategory.accommodation);
  late final Set<String> _accessibilityTags = {
    ...(widget.existing?.accessibilityTags ?? const []),
  };
  late final List<MenuItem> _menuItems = [
    ...(widget.existing?.menuItems ?? const []),
  ];
  late double? _latitude =
      widget.existing?.latitude ?? widget.prefill?.latitude;
  late double? _longitude =
      widget.existing?.longitude ?? widget.prefill?.longitude;
  Province? _selectedProvince;
  late Future<List<Province>> _provincesFuture;
  bool _saving = false;
  bool _dirty = false;

  /// Which [_SectionCard]s are open — the rest show just their header and
  /// a one-line summary, so the form isn't one long scroll.
  final Set<String> _expanded = {_sectionBasic};

  void _toggleSection(String id) {
    setState(() {
      if (!_expanded.remove(id)) _expanded.add(id);
    });
  }

  /// Opens the sections that hold required fields, so whatever a failed
  /// save is complaining about is actually on screen.
  void _revealRequiredFields() {
    setState(() => _expanded.addAll({_sectionBasic, _sectionLocation}));
  }

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
      // Same best-effort match the map-pin shortcut does below — the
      // application's address is itself a map pin's resolved address.
      final prefillAddress = widget.prefill?.address ?? '';
      if (_selectedProvince == null && prefillAddress.isNotEmpty) {
        _selectedProvince = matchProvinceByAddress(prefillAddress, provinces);
      }
      return provinces..sort((a, b) => a.name.compareTo(b.name));
    });
    final existingId = widget.existing?.id;
    if (existingId != null && existingId.isNotEmpty) {
      _repository.getPermit(existingId).then((permit) async {
        var url = permit?.permitUrl ?? '';
        var fromApplication = false;
        // A listing saved without one falls back to the permit photo on
        // the owner's approved application — stored here on the next save.
        if (url.isEmpty) {
          try {
            final application = await BusinessOwnerApplicationRepository()
                .getLatestApprovedForUser(widget.uid);
            url = application?.permitUrl ?? '';
            fromApplication = url.isNotEmpty;
          } catch (_) {}
        }
        if (mounted) {
          setState(() {
            _permitUrl = url;
            _permitFromApplication = fromApplication;
          });
        }
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

  Future<void> _save({bool resubmit = false}) async {
    if (!_formKey.currentState!.validate()) {
      _revealRequiredFields();
      return;
    }
    final province = _selectedProvince;
    if (province == null) {
      _revealRequiredFields();
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
    final opening = _openingTime;
    final closing = _closingTime;
    final openingHours = opening != null && closing != null
        ? '${_formatClockTime(opening)} – ${_formatClockTime(closing)} daily'
        : (widget.existing?.openingHours ?? '');
    if (_category == BusinessCategory.foodAndDining &&
        (openingHours.isEmpty || (opening == null) != (closing == null))) {
      _revealRequiredFields();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select both an opening and a closing time.'),
        ),
      );
      return;
    }

    // Only nudge on a resubmit-after-rejection — the one save that still
    // goes back through an admin's review. A first listing goes live on its
    // own (see BusinessRepository.create), and an already-approved owner
    // just saving an unrelated edit shouldn't be re-asked about a permit
    // they've already deliberately left out.
    if (resubmit && _permitUrl.isEmpty && mounted) {
      final proceed = await showConfirmationDialog(
        context,
        title: 'Submit without a permit photo?',
        message:
            'A Business Permit photo speeds up approval '
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
      contactNumber: PhPhoneField.toStored(_contactController.text),
      websiteUrl: _websiteController.text.trim(),
      heroImageUrl: _heroImageUrl,
      cuisine: _category == BusinessCategory.foodAndDining
          ? _cuisineController.text.trim()
          : '',
      priceRange: _priceRange,
      openingHours: _category == BusinessCategory.foodAndDining
          ? openingHours
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
        await _mirrorToRestaurant(id, business);
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
        } else if (widget.existing!.isApproved) {
          // Live but never mirrored — its category just became Food &
          // Dining, or the mirror failed right after it was created.
          await _mirrorToRestaurant(id, business);
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
                  ? 'Listing published — travelers can see it now.'
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

  /// Gives a live Food & Dining listing its `restaurants` doc (what puts it
  /// in Explore/Search — see the class doc on Business) and links the two.
  /// No-op for every other category.
  Future<void> _mirrorToRestaurant(String id, Business business) async {
    if (!business.isFoodAndDining) return;
    final restaurantId = await _restaurantRepository.createFromBusiness(
      business,
      businessId: id,
    );
    await _repository.setRestaurantId(id, restaurantId);
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
          text:
              'Pending review — your listing\'s details and photos are being '
              'checked before travelers can see it.',
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
                        onPressed: () => context.popOrGo(RoutePaths.adminHome),
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
                if (existing == null && widget.prefill != null) ...[
                  const _Banner(
                    color: AppColors.primary,
                    icon: Symbols.auto_awesome_rounded,
                    text:
                        'We filled in the details from your approved application. '
                        'Check them, add the rest, then publish — your business '
                        'is already verified, so it goes live right away.',
                  ),
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
                  summary: _nameController.text.trim().isEmpty
                      ? 'Name, category and description'
                      : '${_nameController.text.trim()} · ${BusinessCategory.label(_category)}',
                  expanded: _expanded.contains(_sectionBasic),
                  onToggle: () => _toggleSection(_sectionBasic),
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
                      if (_openingTime == null &&
                          _closingTime == null &&
                          (existing?.openingHours.isNotEmpty ?? false))
                        Text(
                          'Current hours: ${existing!.openingHours}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
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
                                  prefixIcon: Icon(
                                    Symbols.schedule_rounded,
                                    size: 20,
                                  ),
                                ),
                                child: Text(
                                  _openingTime == null
                                      ? 'Select time'
                                      : _formatClockTime(_openingTime!),
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
                                  prefixIcon: Icon(
                                    Symbols.schedule_rounded,
                                    size: 20,
                                  ),
                                ),
                                child: Text(
                                  _closingTime == null
                                      ? 'Select time'
                                      : _formatClockTime(_closingTime!),
                                ),
                              ),
                            ),
                          ),
                        ],
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
                  summary: _menuItems.isEmpty
                      ? 'None added yet'
                      : '${_menuItems.length} added',
                  expanded: _expanded.contains(_sectionCatalog),
                  onToggle: () => _toggleSection(_sectionCatalog),
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
                  summary: _addressController.text.trim().isEmpty
                      ? 'Province, address and contact number'
                      : _addressController.text.trim(),
                  expanded: _expanded.contains(_sectionLocation),
                  onToggle: () => _toggleSection(_sectionLocation),
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
                    PhPhoneField(controller: _contactController, required: true),
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
                  summary: _accessibilityTags.isEmpty
                      ? 'None selected'
                      : '${_accessibilityTags.length} selected',
                  expanded: _expanded.contains(_sectionAccessibility),
                  onToggle: () => _toggleSection(_sectionAccessibility),
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
                  summary: _permitUrl.isEmpty
                      ? 'No permit photo yet'
                      : (_permitFromApplication
                            ? 'Permit on file from your application'
                            : 'Permit photo added'),
                  expanded: _expanded.contains(_sectionVerification),
                  onToggle: () => _toggleSection(_sectionVerification),
                  children: [
                    Text(
                      _permitFromApplication
                          ? 'Already verified with your application — replace '
                                'it only if your permit has changed.'
                          : 'Optional — kept on file in case an admin needs to '
                                'verify this listing.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    HeroImagePicker(
                      imageUrl: _permitUrl,
                      folder: FirestorePaths.storageBusinessPermits,
                      ownerId: widget.uid,
                      label: 'Business Permit',
                      height: 140,
                      scanDocument: true,
                      onChanged: (url) => setState(() {
                        _permitUrl = url;
                        _permitFromApplication = false;
                        _dirty = true;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                AnimatedButton(
                  label: existing == null
                      ? 'Publish Listing'
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
///
/// Collapsible: tapping the header toggles [expanded], and a collapsed
/// card shows [summary] in place of its fields. Those fields stay mounted
/// (just offstage) either way, so the surrounding `Form` still validates
/// and keeps the state of a section the owner has closed.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.label,
    required this.summary,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final IconData icon;
  final String label;
  final String summary;
  final bool expanded;
  final VoidCallback onToggle;
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
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(icon: icon, label: label),
                      if (!expanded) ...[
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  expanded
                      ? Symbols.expand_less_rounded
                      : Symbols.expand_more_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: Offstage(
              offstage: !expanded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final child in children) ...[
                    const SizedBox(height: AppSpacing.md),
                    child,
                  ],
                ],
              ),
            ),
          ),
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
