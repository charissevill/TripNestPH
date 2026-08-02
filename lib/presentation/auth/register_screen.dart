import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons/animated_button.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_text_field.dart';

/// Email/password registration. Sends a verification email on success and
/// routes to the Verify Email screen.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final name = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();
    final ok = await auth.register(
      name: name,
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (ok && mounted) context.go(RoutePaths.verifyEmail);
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AuthHeader(title: 'Create your account', subtitle: 'Start planning unforgettable Philippine trips.'),
                const SizedBox(height: AppSpacing.xxxl),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AuthTextField(
                        label: 'First Name',
                        controller: _firstNameController,
                        icon: Symbols.person_rounded,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.givenName],
                        validator: Validators.name,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AuthTextField(
                        label: 'Last Name',
                        controller: _lastNameController,
                        icon: Symbols.person_rounded,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.familyName],
                        validator: Validators.name,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthTextField(
                  label: 'Email',
                  controller: _emailController,
                  icon: Symbols.mail_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthTextField(
                  label: 'Password',
                  controller: _passwordController,
                  icon: Symbols.lock_rounded,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  validator: Validators.password,
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthTextField(
                  label: 'Confirm Password',
                  controller: _confirmPasswordController,
                  icon: Symbols.lock_rounded,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) => Validators.confirmPassword(v, _passwordController.text),
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(auth.errorMessage!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: AppSpacing.xl),
                AnimatedButton(label: 'Create Account', isLoading: auth.isBusy, onPressed: auth.isBusy ? null : _submit),
                const SizedBox(height: AppSpacing.xxl),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Already have an account?', style: theme.textTheme.bodyMedium),
                      TextButton(onPressed: () => context.pop(), child: const Text('Sign In')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
