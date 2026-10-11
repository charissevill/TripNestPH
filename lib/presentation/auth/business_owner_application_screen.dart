import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
/// Business Permit / DTI Registration photo (OCR'd for the reviewer once
/// submitted), and a valid ID photo. All three are required.
class BusinessOwnerApplicationScreen extends StatefulWidget {
  const BusinessOwnerApplicationScreen({super.key});

  @override
  State<BusinessOwnerApplicationScreen> createState() => _BusinessOwnerApplicationScreenState();
}

class _BusinessOwnerApplicationScreenState extends State<BusinessOwnerApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  // Read-only — only ever filled from the map picker (see _pickLocationOnMap).
  final _addressController = TextEditingController();
  final _repository = BusinessOwnerApplicationRepository();
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
    _businessNameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  bool get _hasUnsentInput =>
      !_submitted &&
      (_permitUrl.isNotEmpty ||
          _idUrl.isNotEmpty ||
          [_businessNameController, _phoneController, _descriptionController, _addressController]
              .any((c) => c.text.trim().isNotEmpty));

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
        _errorMessage = latitude == null || longitude == null
            ? 'Pin your business location on the map.'
            : _permitUrl.isEmpty
                ? 'Add a photo of your Business Permit or DTI Registration.'
                : 'Add a photo of a valid ID.';
      });
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
        businessName: _businessNameController.text.trim(),
        category: _category,
        phone: _phoneController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        latitude: latitude,
        longitude: longitude,
        permitUrl: _permitUrl,
        idUrl: _idUrl,
      );
      // Best-effort reading aid for the reviewing admin — never worth
      // failing an already-saved application over.
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
            'Tell us about your business and add proof that it\'s yours. An admin will review this '
            'and, once approved, you\'ll see an invite to accept on your Profile screen.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          AuthTextField(
            label: 'Business name',
            controller: _businessNameController,
            icon: Symbols.storefront_rounded,
            textInputAction: TextInputAction.next,
            validator: (v) => Validators.required(v, label: 'Business name'),
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final category in BusinessCategory.all)
                DropdownMenuItem(value: category, child: Text(BusinessCategory.label(category))),
            ],
            onChanged: (value) => setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthTextField(
            label: 'Contact phone',
            controller: _phoneController,
            icon: Symbols.call_rounded,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            validator: (v) => Validators.phone(v, required: true),
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthTextField(
            label: 'Tell us about your business',
            controller: _descriptionController,
            icon: Symbols.description_rounded,
            textInputAction: TextInputAction.done,
            validator: (v) => Validators.maxLength(v, 1000, label: 'Description'),
          ),
          const SizedBox(height: AppSpacing.lg),
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
          const SizedBox(height: AppSpacing.xl),
          HeroImagePicker(
            imageUrl: _permitUrl,
            folder: FirestorePaths.storageBusinessApplicationDocs,
            ownerId: uid,
            label: 'Business Permit / DTI Registration',
            height: 140,
            scanDocument: true,
            onChanged: (url) => setState(() => _permitUrl = url),
          ),
          const SizedBox(height: AppSpacing.lg),
          HeroImagePicker(
            imageUrl: _idUrl,
            folder: FirestorePaths.storageBusinessApplicationDocs,
            ownerId: uid,
            label: 'Valid ID',
            height: 140,
            scanDocument: true,
            onChanged: (url) => setState(() => _idUrl = url),
          ),
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
