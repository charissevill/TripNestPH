import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/layout/max_width_container.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_text_field.dart';

enum _Step { enterEmail, enterCode }

/// Two-step password reset: request a 6-digit code by email, then enter
/// that code alongside a new password — replaces the old single-step
/// "we sent you a link" flow. A numeric code has neither of that flow's two
/// real-world failure modes: there's no one-time link for a new request to
/// silently invalidate, and no link for an inbox's safety-scanner to
/// pre-consume before the traveler manually clicks it.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  _Step _step = _Step.enterEmail;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!_emailFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.requestPasswordResetCode(_emailController.text);
    if (ok && mounted) setState(() => _step = _Step.enterCode);
  }

  Future<void> _resetPassword() async {
    if (!_codeFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyPasswordResetCode(
      email: _emailController.text,
      code: _codeController.text,
      newPassword: _passwordController.text,
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. Sign in with your new password.')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => _step == _Step.enterCode ? setState(() => _step = _Step.enterEmail) : context.pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
          child: MaxWidthContainer(
            maxWidth: 480,
            child: _step == _Step.enterEmail ? _buildEmailStep(theme, auth) : _buildCodeStep(theme, auth),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep(ThemeData theme, AuthProvider auth) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthHeader(
            title: 'Reset your password',
            subtitle: 'Enter your email and we\'ll send you a 6-digit code.',
          ),
          const SizedBox(height: AppSpacing.xxxl),
          AuthTextField(
            label: 'Email',
            controller: _emailController,
            icon: Symbols.mail_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: Validators.email,
            onFieldSubmitted: (_) => _requestCode(),
          ),
          if (auth.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(auth.errorMessage!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.xl),
          AnimatedButton(label: 'Send Code', isLoading: auth.isBusy, onPressed: auth.isBusy ? null : _requestCode),
        ],
      ),
    );
  }

  Widget _buildCodeStep(ThemeData theme, AuthProvider auth) {
    return Form(
      key: _codeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(Symbols.mark_email_read_rounded, color: AppColors.secondary, size: 32),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Enter the code', style: theme.textTheme.displayMedium),
          const SizedBox(height: 4),
          Text(
            'We sent a 6-digit code to ${_emailController.text}. It expires in 10 minutes.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xxxl),
          AuthTextField(
            label: '6-digit code',
            controller: _codeController,
            icon: Symbols.pin_rounded,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            validator: Validators.otpCode,
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthTextField(
            label: 'New password',
            controller: _passwordController,
            icon: Symbols.lock_rounded,
            obscureText: true,
            textInputAction: TextInputAction.next,
            validator: Validators.password,
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthTextField(
            label: 'Confirm new password',
            controller: _confirmPasswordController,
            icon: Symbols.lock_rounded,
            obscureText: true,
            textInputAction: TextInputAction.done,
            validator: (v) => Validators.confirmPassword(v, _passwordController.text),
            onFieldSubmitted: (_) => _resetPassword(),
          ),
          if (auth.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(auth.errorMessage!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.xl),
          AnimatedButton(
            label: 'Reset Password',
            isLoading: auth.isBusy,
            onPressed: auth.isBusy ? null : _resetPassword,
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton(
              onPressed: auth.isBusy ? null : _requestCode,
              child: const Text('Resend code'),
            ),
          ),
        ],
      ),
    );
  }
}
