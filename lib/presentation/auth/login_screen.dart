import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/layout/max_width_container.dart';
import '../../core/widgets/text/stroked_text.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_hero_panel.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/role_choice_dialog.dart';

/// Email/password sign-in, with a Google sign-in shortcut and links to
/// Register and Forgot Password.
///
/// Below [WindowSize.expanded] this stays the original single-column layout
/// (the sign-in card floating over a full-bleed background photo) — that
/// treatment only reads as intentional, rather than cramped, once there's
/// genuine desktop-width room for a two-pane split, so the switch happens
/// at the same threshold [MaxWidthContainer]/the side-nav shell already use.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.homeRedirect = RoutePaths.home, this.showRegisterLink = true});

  /// Where a successful sign-in lands — shared between the traveler app's
  /// router and the dedicated Admin Portal site's router (both use this
  /// same screen), so this can't hardcode [RoutePaths.home]: that route
  /// doesn't exist on the Admin Portal site at all.
  final String homeRedirect;

  /// The Admin Portal site never offers self-registration (see
  /// `admin_router.dart` — it has no `register` route), so its instance of
  /// this screen hides the "Don't have an account? Sign Up" row entirely
  /// rather than linking to a route that doesn't exist there.
  final bool showRegisterLink;

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
    if (ok && mounted) context.go(widget.homeRedirect);
  }

  Future<void> _signInWithGoogle() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.signInWithGoogle();
    if (ok && mounted) context.go(widget.homeRedirect);
  }

  /// Asks "just exploring" vs. "business owner" up front, before Register's
  /// own form ever renders — see `showRoleChoiceDialog`'s doc comment for
  /// why this sits here instead of as a field inside that form.
  Future<void> _goToRegister(BuildContext context) async {
    final wantsBusinessOwner = await showRoleChoiceDialog(context);
    if (!context.mounted) return;
    context.push(RoutePaths.register, extra: wantsBusinessOwner == true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDesktop = context.windowSize == WindowSize.expanded;

    return Scaffold(
      body: isDesktop ? _buildDesktopLayout(auth) : _buildCompactLayout(auth),
    );
  }

  // ---- Compact (phone/tablet): card floats over a full-bleed photo -------

  Widget _buildCompactLayout(AuthProvider auth) {
    return Stack(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AuthHeader(
                    title: 'Welcome back',
                    subtitle: 'Sign in to keep discovering the Philippines.',
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  _buildFormFields(auth, signUpRowOnDark: true),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---- Desktop: branded hero on the left, sign-in card on the right ------

  Widget _buildDesktopLayout(AuthProvider auth) {
    return Row(
      children: [
        const Expanded(child: AuthHeroPanel()),
        Expanded(
          child: ColoredBox(
            color: AppColors.background,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxxl,
                  vertical: AppSpacing.xxl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Welcome back',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sign in to keep discovering the Philippines.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      _buildFormFields(auth, signUpRowOnDark: false),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---- Shared form body, used by both layouts ----------------------------

  Widget _buildFormFields(AuthProvider auth, {required bool signUpRowOnDark}) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
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
            // Deliberately not Validators.password (8-char minimum): that
            // policy only applies to NEW passwords being set (Register/
            // Change Password). Enforcing it here too would block sign-in
            // for any account whose real password predates the policy or
            // is otherwise shorter — the account's actual password is
            // whatever Firebase Auth has on file, not whatever this form's
            // validator allows.
            validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
            onFieldSubmitted: (_) => _submit(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push(RoutePaths.forgotPassword),
              child: const Text('Forgot Password?'),
            ),
          ),
          if (auth.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(auth.errorMessage!, style: const TextStyle(color: AppColors.error)),
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
              const Expanded(child: Divider(color: AppColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text('or continue with', style: theme.textTheme.bodySmall),
              ),
              const Expanded(child: Divider(color: AppColors.border)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AnimatedButton(
            label: 'Continue with Google',
            leading: SvgPicture.asset('assets/images/google_logo.svg', width: 20, height: 20),
            filled: false,
            isLoading: auth.isBusy,
            onPressed: auth.isBusy ? null : _signInWithGoogle,
            labelColor: Colors.white,
            strokeLabel: true,
            strokeColor: AppColors.primaryDark,
          ),
          if (widget.showRegisterLink) ...[
            const SizedBox(height: AppSpacing.xxl),
            Center(
              child: signUpRowOnDark
                  // Over the full-bleed photo (compact layout), plain text
                  // reads inconsistently against the image underneath it —
                  // the same stroke treatment the rest of that layout's text
                  // already relies on for legibility.
                  ? Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StrokedText(
                          'Don\'t have an account?',
                          style: theme.textTheme.bodyMedium!.copyWith(color: Colors.white),
                          strokeColor: AppColors.primaryDark,
                        ),
                        TextButton(
                          onPressed: () => _goToRegister(context),
                          child: StrokedText(
                            'Sign Up',
                            style: theme.textTheme.labelLarge!.copyWith(color: Colors.white),
                            strokeColor: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    )
                  // On the plain panel background (desktop layout) there's
                  // nothing to fight for contrast against, so ordinary themed
                  // text reads better than a stroke outline meant for a photo.
                  : Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Don\'t have an account?', style: theme.textTheme.bodyMedium),
                        TextButton(
                          onPressed: () => _goToRegister(context),
                          child: Text('Sign Up', style: theme.textTheme.labelLarge),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
