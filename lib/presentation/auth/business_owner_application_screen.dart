import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/services/ocr_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/inputs/hero_image_picker.dart';
import '../../core/widgets/layout/max_width_container.dart';
import '../../data/repositories/business_owner_application_repository.dart';
import '../../domain/models/business.dart';
import '../../domain/models/business_owner_application.dart';
import '../ai_planner/widgets/map_destination_picker.dart';
import 'widgets/auth_text_field.dart';

/// Reached right after a successful registration when "Business Owner" was
/// picked on the sign-up form's role toggle (see `RegisterScreen._submit`)
/// — a lightweight request for `businessOwner` access, reviewed by an admin
/// (`AdminBusinessOwnerApplicationsScreen`), not instant self-service. See
/// `BusinessOwnerApplication`'s doc comment for why.
///
/// Beyond the basics, the applicant has to prove the business is real before
/// an admin ever looks at it: its location as a pin dropped on a map, a
/// Business Permit photo (OCR'd for the reviewer once
/// submitted), and a photo of the front of a valid ID (only the name on it
/// is read). All three are required.
class BusinessOwnerApplicationScreen extends StatefulWidget {
  const BusinessOwnerApplicationScreen({super.key});

  @override
  State<BusinessOwnerApplicationScreen> createState() => _BusinessOwnerApplicationScreenState();
}

class _BusinessOwnerApplicationScreenState extends State<BusinessOwnerApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  // Read-only — only ever filled from the map picker (see _pickLocationOnMap).
  final _addressController = TextEditingController();
  final _repository = BusinessOwnerApplicationRepository();
  final _ocrService = OcrService();
  // What was read off the permit and the ID once each is uploaded (see
  // _readPermit/_readId) — pre-filled, then the applicant's to correct.
  final _permitBusinessNameController = TextEditingController();
  final _permitOwnerController = TextEditingController();
  final _permitAddressController = TextEditingController();
  final _permitNoController = TextEditingController();
  final _permitLguController = TextEditingController();
  // Read-only — only ever filled from the date picker (see _pickValidUntil).
  final _permitValidUntilController = TextEditingController();
  final _idNameController = TextEditingController();
  DateTime? _permitValidUntil;
  bool _readingPermit = false;
  bool _readingId = false;
  String _category = BusinessCategory.accommodation;
  double? _latitude;
  double? _longitude;
  String _permitUrl = '';
  String _idUrl = '';
  bool _busy = false;
  String? _errorMessage;
  bool _submitted = false;

  @override
  void dispose() {
    _addressController.dispose();
    _permitBusinessNameController.dispose();
    _permitOwnerController.dispose();
    _permitAddressController.dispose();
    _permitNoController.dispose();
    _permitLguController.dispose();
    _permitValidUntilController.dispose();
    _idNameController.dispose();
    super.dispose();
  }

  void _setValidUntil(DateTime? date) {
    _permitValidUntil = date;
    _permitValidUntilController.text = date == null ? '' : DateFormat('MMMM d, yyyy').format(date);
  }

  /// Reads a just-uploaded permit photo and pre-fills the editable fields
  /// under it. Best-effort: a photo nothing could be read from just leaves
  /// them blank for the applicant to type in.
  Future<void> _readPermit(String url) async {
    setState(() {
      _permitUrl = url;
      _readingPermit = true;
    });
    var fields = const PermitFields();
    try {
      fields = (await _ocrService.readApplicationDocs(permitUrl: url)).permitFields;
    } catch (_) {
      // Falls through with nothing read.
    }
    // A different photo was picked while this one was being read — that
    // newer read owns the fields now.
    if (!mounted || _permitUrl != url) return;
    _permitBusinessNameController.text = fields.businessName;
    _permitOwnerController.text = fields.ownerName;
    _permitAddressController.text = fields.address;
    _permitNoController.text = fields.permitNo;
    _permitLguController.text = fields.issuingLgu;
    setState(() {
      _setValidUntil(fields.validUntil);
      _readingPermit = false;
    });
  }

  /// Same as [_readPermit], for the name on the valid ID.
  Future<void> _readId(String url) async {
    setState(() {
      _idUrl = url;
      _readingId = true;
    });
    var name = '';
    try {
      name = (await _ocrService.readApplicationDocs(idUrl: url)).idName;
    } catch (_) {
      // Falls through with nothing read.
    }
    if (!mounted || _idUrl != url) return;
    _idNameController.text = name;
    setState(() => _readingId = false);
  }

  Future<void> _pickValidUntil() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _permitValidUntil ?? DateTime(now.year, 12, 31),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: 'Permit valid until',
    );
    if (picked == null || !mounted) return;
    setState(() => _setValidUntil(picked));
  }

  bool get _hasUnsentInput =>
      !_submitted &&
      (_permitUrl.isNotEmpty ||
          _idUrl.isNotEmpty ||
          _addressController.text.trim().isNotEmpty);

  /// Same [MapDestinationPicker] "search or tap a spot" flow My Business's
  /// own Address field uses — the pin's coordinates are what the reviewing
  /// admin actually checks, the resolved name is just its readable label.
  Future<void> _pickLocationOnMap() async {
    final picked = await Navigator.of(context).push<MapPickedLocation>(
      MaterialPageRoute(
        builder: (context) => const MapDestinationPicker(title: 'Pin Your Business Location'),
      ),
    );
    if (picked == null || !mounted) return;
    _addressController.text = picked.name;
    setState(() {
      _latitude = picked.latitude;
      _longitude = picked.longitude;
    });
  }

  /// Shared by the AppBar arrow and device back. This screen replaced
  /// Register (see the AppBar comment below), so device back used to close
  /// the app outright; now both skip ahead to Verify Email, asking first if
  /// there's a half-filled application that would be thrown away.
  Future<void> _leave() async {
    if (_hasUnsentInput) {
      final confirmed = await showConfirmationDialog(
        context,
        title: 'Discard changes?',
        message: 'You have unsaved changes that will be lost.',
        confirmLabel: 'Discard',
        isDestructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    context.go(RoutePaths.verifyEmail);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthProvider>().firebaseUser;
    if (user == null) return;
    final latitude = _latitude;
    final longitude = _longitude;
    // The two photo fields aren't FormFields, so the form's own validate()
    // above can't catch them being empty.
    if (latitude == null || longitude == null || _permitUrl.isEmpty || _idUrl.isEmpty) {
      setState(() {
        // Permit first — the location field only appears once it's scanned.
        _errorMessage = _permitUrl.isEmpty
            ? 'Add a photo of your Business Permit.'
            : latitude == null || longitude == null
                ? 'Pin your business location on the map.'
                : 'Add a photo of the front of a valid ID.';
      });
      return;
    }
    // Submitting now would send the fields below blank, before the applicant
    // has seen (or could correct) what was read.
    if (_readingPermit || _readingId) {
      setState(() => _errorMessage = 'Still reading your documents — try again in a moment.');
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final id = await _repository.submit(
        userId: user.uid,
        applicantName: user.displayName ?? '',
        applicantEmail: user.email ?? '',
        // No separately-typed name: the application's business name *is* the
        // one on the permit, as read and then confirmed by the applicant.
        businessName: _permitBusinessNameController.text.trim(),
        category: _category,
        address: _addressController.text.trim(),
        latitude: latitude,
        longitude: longitude,
        permitUrl: _permitUrl,
        idUrl: _idUrl,
        confirmedPermitFields: PermitFields(
          businessName: _permitBusinessNameController.text.trim(),
          ownerName: _permitOwnerController.text.trim(),
          address: _permitAddressController.text.trim(),
          permitNo: _permitNoController.text.trim(),
          validUntil: _permitValidUntil,
          issuingLgu: _permitLguController.text.trim(),
        ),
        confirmedIdName: _idNameController.text.trim(),
      );
      // The untouched reading, stored server-side next to what the applicant
      // confirmed above so the admin can compare the two — best-effort, never
      // worth failing an already-saved application over.
      unawaited(OcrService().extractApplicationText(id).catchError((_) => ''));
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = AppException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
      appBar: AppBar(
        // Reached via context.go from Register (replacing that route, not
        // pushed on top of it), so there's nothing behind this screen to
        // pop back to — this acts as a "skip application, continue as
        // traveler" action instead, landing exactly where the "Just
        // Exploring" choice on Register would have.
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: _leave,
        ),
        title: const Text('Business Owner Application'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: MaxWidthContainer(
            maxWidth: 480,
            child: _submitted ? _buildConfirmation(theme) : _buildForm(theme),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? '';
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scan your business permit and a valid ID — we\'ll read the details for you to check. '
            'An admin will review this and, once approved, you\'ll see an invite to accept on your Profile screen.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final category in BusinessCategory.all)
                DropdownMenuItem(value: category, child: Text(BusinessCategory.label(category))),
            ],
            onChanged: (value) => setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: AppSpacing.xl),
          HeroImagePicker(
            imageUrl: _permitUrl,
            folder: FirestorePaths.storageBusinessApplicationDocs,
            ownerId: uid,
            label: 'Business Permit',
            height: 140,
            scanDocument: true,
            onChanged: _readPermit,
          ),
          if (_readingPermit)
            const _ReadingNotice(label: 'Reading your permit…')
          else if (_permitUrl.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'This is what we read from your permit. Check each one and fix anything that\'s wrong or missing.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            AuthTextField(
              // Required, unlike the rest: this doubles as the application's
              // own business name (see _submit), which firestore.rules caps
              // at 100.
              label: 'Business name',
              controller: _permitBusinessNameController,
              icon: Symbols.storefront_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  Validators.required(v, label: 'Business name') ?? Validators.maxLength(v, 100, label: 'Business name'),
            ),
            const SizedBox(height: AppSpacing.md),
            AuthTextField(
              label: 'Owner name on permit',
              controller: _permitOwnerController,
              icon: Symbols.person_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.maxLength(v, 120, label: 'Owner name on permit'),
            ),
            const SizedBox(height: AppSpacing.md),
            AuthTextField(
              label: 'Address on permit',
              controller: _permitAddressController,
              icon: Symbols.home_pin_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.maxLength(v, 300, label: 'Address on permit'),
            ),
            const SizedBox(height: AppSpacing.md),
            AuthTextField(
              label: 'Permit no.',
              controller: _permitNoController,
              icon: Symbols.tag_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.maxLength(v, 40, label: 'Permit no.'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _permitValidUntilController,
              readOnly: true,
              onTap: _pickValidUntil,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                labelText: 'Valid until',
                hintText: 'Tap to pick a date',
                prefixIcon: const Icon(Symbols.event_rounded, color: AppColors.textSecondary, size: 20),
                suffixIcon: _permitValidUntil == null
                    ? null
                    : IconButton(
                        icon: const Icon(Symbols.close_rounded, color: AppColors.textSecondary, size: 20),
                        tooltip: 'Clear date',
                        onPressed: () => setState(() => _setValidUntil(null)),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AuthTextField(
              label: 'Issued by (city or municipality)',
              controller: _permitLguController,
              icon: Symbols.account_balance_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.maxLength(v, 120, label: 'Issued by'),
            ),
            const SizedBox(height: AppSpacing.md),
            // With the rest of the after-scan fields rather than up top, so
            // the form opens on just the two documents to scan.
            TextFormField(
              controller: _addressController,
              readOnly: true,
              onTap: _pickLocationOnMap,
              maxLines: null,
              style: theme.textTheme.bodyLarge,
              validator: (v) => Validators.required(v, label: 'Business location'),
              decoration: const InputDecoration(
                labelText: 'Business location',
                hintText: 'Tap to pin it on the map',
                prefixIcon: Icon(Symbols.location_on_rounded, color: AppColors.textSecondary, size: 20),
                suffixIcon: Icon(Symbols.map_rounded, color: AppColors.textSecondary, size: 20),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          HeroImagePicker(
            imageUrl: _idUrl,
            folder: FirestorePaths.storageBusinessApplicationDocs,
            ownerId: uid,
            // The front is the side with the holder's name, which is what
            // gets read off it for the reviewing admin.
            label: 'Valid ID (front)',
            height: 140,
            scanDocument: true,
            onChanged: _readId,
          ),
          if (_readingId)
            const _ReadingNotice(label: 'Reading your ID…')
          else if (_idUrl.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            AuthTextField(
              label: 'Name on ID',
              controller: _idNameController,
              icon: Symbols.badge_rounded,
              textInputAction: TextInputAction.done,
              validator: (v) => Validators.maxLength(v, 120, label: 'Name on ID'),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Read from your ID — fix it if it\'s wrong. Nothing else on the ID is kept.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Only you and the reviewing admin can see these.',
            style: theme.textTheme.bodySmall,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.xl),
          AnimatedButton(label: 'Submit Application', isLoading: _busy, onPressed: _busy ? null : _submit),
        ],
      ),
    );
  }

  Widget _buildConfirmation(ThemeData theme) {
    // A Google sign-up arrives here already verified — there's no Verify
    // Email step ahead of it to announce (Continue lands on Home instead).
    final verified = context.read<AuthProvider>().isEmailVerified;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: const Icon(Symbols.check_circle_rounded, color: AppColors.secondary, size: 32),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Application submitted', style: theme.textTheme.displayMedium),
        const SizedBox(height: 4),
        Text(
          verified
              ? 'We\'ll review it and let you know.'
              : 'We\'ll review it and let you know. In the meantime, let\'s verify your email.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        AnimatedButton(label: 'Continue', onPressed: () => context.go(RoutePaths.verifyEmail)),
      ],
    );
  }
}

/// Shown under a document photo while it's being read (see `_readPermit`).
class _ReadingNotice extends StatelessWidget {
  const _ReadingNotice({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
