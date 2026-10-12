import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/back_navigation.dart';
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

/// Email/password registration. Sends a verification email on success and
/// routes to the Verify Email screen — or, if [wantsBusinessOwner] came in
/// true, to [BusinessOwnerApplicationScreen] first. That choice itself is
/// asked earlier, in a modal shown the moment "Sign Up" is tapped on Login
/// (`showRoleChoiceDialog`), not as a field inside this form — [Login]
/// passes its answer through as this route's `extra`.
///
/// Same [WindowSize.expanded] split-layout treatment as [LoginScreen], for
/// the same reason: one consistent brand identity across both auth screens
/// rather than Register looking like a different, unrelated app once the
/// window is desktop-wide.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.wantsBusinessOwner = false});

  final bool wantsBusinessOwner;

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

  // Confirms the choice already made in Login's role-choice dialog — this
  // screen never re-asks it, just reflects it back.
  String get _subtitle => widget.wantsBusinessOwner
      ? 'Let\'s get your business set up.'
      : 'Start planning unforgettable Philippine trips.';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final name =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
            .trim();
    final ok = await auth.register(
      name: name,
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!ok || !mounted) return;
    if (widget.wantsBusinessOwner) {
      context.go(RoutePaths.businessOwnerApplication);
    } else {
      context.go(RoutePaths.verifyEmail);
    }
  }

  /// Same Google shortcut Login offers, but carrying the role choice through:
  /// a Google account's email is already verified, so there's no Verify
  /// Email step to land on — a traveler goes straight home, a business owner
  /// to their application first.
  Future<void> _signUpWithGoogle() async {
    final auth = context.read<AuthProvider>();
    // Captured before the await: the moment sign-in succeeds the router's
    // own redirect bounces this (auth-only) route to Home, which can unmount
    // this screen before the line below runs — and a `mounted` check there
    // would then silently drop the business owner's application step.
    final router = GoRouter.of(context);
    final ok = await auth.signInWithGoogle();
    if (!ok) return;
    // signInWithGoogle() returning doesn't mean AuthProvider has heard about
    // it yet — its auth-state listener fires on its own schedule. Navigating
    // in that gap makes the router see "nobody signed in", bounce the
    // application route to Login, and then (once the sign-in does land) on to
    // Home — the business owner ends up a plain traveler with no application.
    await _untilSignedIn(auth);
    router.go(widget.wantsBusinessOwner ? RoutePaths.businessOwnerApplication : RoutePaths.home);
  }

  /// Completes once [auth] reports a signed-in user, or after a few seconds
  /// regardless — never worth hanging the sign-up on.
  Future<void> _untilSignedIn(AuthProvider auth) async {
    if (auth.isSignedIn) return;
    final signedIn = Completer<void>();
    void listener() {
      if (auth.isSignedIn && !signedIn.isCompleted) signedIn.complete();
    }

    auth.addListener(listener);
    try {
      await signedIn.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    } finally {
      auth.removeListener(listener);
    }
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
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Symbols.arrow_back_rounded),
                  onPressed: () => context.popOrGo(RoutePaths.login),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  child: MaxWidthContainer(
                    maxWidth: 480,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AuthHeader(title: 'Create your account', subtitle: _subtitle),
                        const SizedBox(height: AppSpacing.xxxl),
                        _buildFormFields(auth, signUpRowOnDark: true),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Desktop: branded hero on the left, register card on the right -----

  Widget _buildDesktopLayout(AuthProvider auth) {
    return Row(
      children: [
        const Expanded(child: AuthHeroPanel()),
        Expanded(
          child: ColoredBox(
            color: AppColors.background,
            child: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Symbols.arrow_back_rounded),
                      onPressed: () => context.popOrGo(RoutePaths.login),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxxl,
                          vertical: AppSpacing.xl,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Create your account',
                                style: Theme.of(context).textTheme.displayMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(_subtitle, style: Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: AppSpacing.xxxl),
                              _buildFormFields(auth, signUpRowOnDark: false),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
          AnimatedButton(
            label: 'Create Account',
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
            onPressed: auth.isBusy ? null : _signUpWithGoogle,
            labelColor: Colors.white,
            strokeLabel: true,
            strokeColor: AppColors.primaryDark,
          ),
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
                        'Already have an account?',
                        style: theme.textTheme.bodyMedium!.copyWith(color: Colors.white),
                        strokeColor: AppColors.primaryDark,
                      ),
                      TextButton(
                        onPressed: () => context.popOrGo(RoutePaths.login),
                        child: StrokedText(
                          'Sign In',
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
                      Text('Already have an account?', style: theme.textTheme.bodyMedium),
                      TextButton(
                        onPressed: () => context.popOrGo(RoutePaths.login),
                        child: Text('Sign In', style: theme.textTheme.labelLarge),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
