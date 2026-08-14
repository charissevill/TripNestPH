import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/layout/max_width_container.dart';
import '../../core/widgets/text/stroked_text.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_text_field.dart';

/// Email/password sign-in, with a Google sign-in shortcut and links to
/// Register and Forgot Password.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (ok && mounted) context.go(RoutePaths.home);
  }

  Future<void> _signInWithGoogle() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.signInWithGoogle();
    if (ok && mounted) context.go(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/bg.png', fit: BoxFit.cover),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: MaxWidthContainer(
                maxWidth: 480,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AuthHeader(
                        title: 'Welcome back',
                        subtitle:
                            'Sign in to keep discovering the Philippines.',
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
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
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        // Deliberately not Validators.password (8-char
                        // minimum): that policy only applies to NEW
                        // passwords being set (Register/Change Password).
                        // Enforcing it here too would block sign-in for any
                        // account whose real password predates the policy
                        // or is otherwise shorter — the account's actual
                        // password is whatever Firebase Auth has on file,
                        // not whatever this form's validator allows.
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Password is required'
                            : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              context.push(RoutePaths.forgotPassword),
                          child: const Text('Forgot Password?'),
                        ),
                      ),
                      if (auth.errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          auth.errorMessage!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      AnimatedButton(
                        label: 'Sign In',
                        isLoading: auth.isBusy,
                        onPressed: auth.isBusy ? null : _submit,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: AppColors.border),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            child: Text(
                              'or continue with',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: AppColors.border),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AnimatedButton(
                        label: 'Continue with Google',
                        leading: SvgPicture.asset(
                          'assets/images/google_logo.svg',
                          width: 20,
                          height: 20,
                        ),
                        filled: false,
                        isLoading: auth.isBusy,
                        onPressed: auth.isBusy ? null : _signInWithGoogle,
                        labelColor: Colors.white,
                        strokeLabel: true,
                        strokeColor: AppColors.primaryDark,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StrokedText(
                              'Don\'t have an account?',
                              style: theme.textTheme.bodyMedium!.copyWith(
                                color: Colors.white,
                              ),
                              strokeColor: AppColors.primaryDark,
                            ),
                            TextButton(
                              onPressed: () =>
                                  context.push(RoutePaths.register),
                              child: StrokedText(
                                'Sign Up',
                                style: theme.textTheme.labelLarge!.copyWith(
                                  color: Colors.white,
                                ),
                                strokeColor: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
