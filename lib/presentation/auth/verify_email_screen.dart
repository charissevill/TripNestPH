import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/sign_out.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/layout/max_width_container.dart';
import 'widgets/auth_text_field.dart';

/// Shown right after registration until the traveler confirms their email.
/// Periodically checks verification status and offers a resend action.
///
/// Shared between the traveler app's router and the dedicated Admin Portal
/// site's router (both sign-in flows can land here) — [verifiedRedirect]
/// lets each supply its own "verified, go here now" destination rather than
/// this screen hardcoding [RoutePaths.home], which doesn't exist as a route
/// on the Admin Portal site at all.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, this.verifiedRedirect = RoutePaths.home});

  final String verifiedRedirect;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  // 30 polls at 4s apart = 2 minutes of automatic checking before giving up
  // and leaving it to the manual "I've verified" / code-entry path —
  // otherwise a traveler who leaves this screen open drains battery/network
  // indefinitely with no escalation ever offered. Polling stays alongside
  // the code field below since either path (an old link still floating
  // around in their inbox, or the new code) ends the same way: emailVerified
  // flips true server-side.
  static const _maxPollAttempts = 30;

  final _codeFormKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  Timer? _pollTimer;
  int _pollAttempts = 0;
  bool _justSentCode = false;
  bool _gaveUpPolling = false;
  bool _showCodeField = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkVerified());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    final auth = context.read<AuthProvider>();
    if (auth.isBusy) return;
    await auth.refreshEmailVerified();
    if (auth.isEmailVerified && mounted) {
      context.go(widget.verifiedRedirect);
      return;
    }
    _pollAttempts++;
    if (_pollAttempts >= _maxPollAttempts && mounted) {
      _pollTimer?.cancel();
      setState(() => _gaveUpPolling = true);
    }
  }

  Future<void> _sendCode() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.requestEmailVerificationCode();
    if (!ok || !mounted) return;
    if (auth.emailAlreadyVerified) {
      context.go(widget.verifiedRedirect);
      return;
    }
    setState(() {
      _justSentCode = true;
      _showCodeField = true;
    });
  }

  Future<void> _verifyCode() async {
    if (!_codeFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyEmailVerificationCode(_codeController.text);
    if (ok && mounted) context.go(widget.verifiedRedirect);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final email = auth.firebaseUser?.email ?? 'your email';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: MaxWidthContainer(
            maxWidth: 480,
            child: Form(
              key: _codeFormKey,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradient([theme.colorScheme.primary, theme.colorScheme.primaryFixedDim]),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Icon(Symbols.mark_email_unread_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Verify your email', style: theme.textTheme.displayMedium),
                const SizedBox(height: 4),
                Text(
                  _showCodeField
                      ? 'Enter the 6-digit code we sent to $email. It expires in 10 minutes.'
                      : 'Verify $email to activate your TripNest PH account.',
                  style: theme.textTheme.bodyMedium,
                ),
                if (_showCodeField) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AuthTextField(
                    label: '6-digit code',
                    controller: _codeController,
                    icon: Symbols.pin_rounded,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    validator: Validators.otpCode,
                    onFieldSubmitted: (_) => _verifyCode(),
                  ),
                ],
                if (_justSentCode) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text('Verification code sent.', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary)),
                ],
                if (_gaveUpPolling) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Still waiting? Check your spam folder, or send a code below.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(auth.errorMessage!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: AppSpacing.xl),
                if (_showCodeField) ...[
                  AnimatedButton(label: 'Verify Code', isLoading: auth.isBusy, onPressed: auth.isBusy ? null : _verifyCode),
                  const SizedBox(height: AppSpacing.sm),
                  AnimatedButton(label: 'Send New Code', filled: false, isLoading: auth.isBusy, onPressed: auth.isBusy ? null : _sendCode),
                ] else ...[
                  AnimatedButton(label: 'Send Verification Code', isLoading: auth.isBusy, onPressed: auth.isBusy ? null : _sendCode),
                  const SizedBox(height: AppSpacing.sm),
                  AnimatedButton(
                    label: 'I\'ve already verified',
                    filled: false,
                    isLoading: auth.isBusy,
                    onPressed: auth.isBusy ? null : _checkVerified,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: TextButton(
                    onPressed: () async {
                      final signedOut = await confirmSignOut(context);
                      if (signedOut && context.mounted) context.go(RoutePaths.login);
                    },
                    child: const Text('Sign out'),
                  ),
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
