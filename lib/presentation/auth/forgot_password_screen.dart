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

/// Sends a Firebase password-reset email to the entered address.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.sendPasswordResetEmail(_emailController.text);
    if (ok) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => context.pop())),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
          child: MaxWidthContainer(
            maxWidth: 480,
            child: _sent ? _SentConfirmation(email: _emailController.text) : _buildForm(theme, auth),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme, AuthProvider auth) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthHeader(
            title: 'Reset your password',
            subtitle: 'Enter your email and we\'ll send you a link to reset your password.',
          ),
          const SizedBox(height: AppSpacing.xxxl),
          AuthTextField(
            label: 'Email',
            controller: _emailController,
            icon: Symbols.mail_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: Validators.email,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (auth.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(auth.errorMessage!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.xl),
          AnimatedButton(label: 'Send Reset Link', isLoading: auth.isBusy, onPressed: auth.isBusy ? null : _submit),
        ],
      ),
    );
  }
}

class _SentConfirmation extends StatelessWidget {
  const _SentConfirmation({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          child: const Icon(Symbols.mark_email_read_rounded, color: AppColors.secondary, size: 32),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Check your inbox', style: theme.textTheme.displayMedium),
        const SizedBox(height: 4),
        Text(
          'We sent a password reset link to $email. Follow the link to choose a new password.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        AnimatedButton(label: 'Back to Sign In', onPressed: () => context.pop()),
      ],
    );
  }
}
