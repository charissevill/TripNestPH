import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/layout/max_width_container.dart';
import '../../data/repositories/business_owner_application_repository.dart';
import '../../domain/models/business.dart';
import 'widgets/auth_text_field.dart';

/// Reached right after a successful registration when "Business Owner" was
/// picked on the sign-up form's role toggle (see `RegisterScreen._submit`)
/// — a lightweight request for `businessOwner` access, reviewed by an admin
/// (`AdminBusinessOwnerApplicationsScreen`), not instant self-service. See
/// `BusinessOwnerApplication`'s doc comment for why.
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
  final _repository = BusinessOwnerApplicationRepository();
  String _category = BusinessCategory.accommodation;
  bool _busy = false;
  String? _errorMessage;
  bool _submitted = false;

  @override
  void dispose() {
    _businessNameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _hasUnsentInput =>
      !_submitted &&
      [_businessNameController, _phoneController, _descriptionController]
          .any((c) => c.text.trim().isNotEmpty);

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

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await _repository.submit(
        userId: user.uid,
        applicantName: user.displayName ?? '',
        applicantEmail: user.email ?? '',
        businessName: _businessNameController.text.trim(),
        category: _category,
        phone: _phoneController.text.trim(),
        description: _descriptionController.text.trim(),
      );
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell us about your business. An admin will review this and, once approved, '
            'you\'ll see an invite to accept on your Profile screen.',
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
          'We\'ll review it and let you know. In the meantime, let\'s verify your email.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        AnimatedButton(label: 'Continue', onPressed: () => context.go(RoutePaths.verifyEmail)),
      ],
    );
  }
}
