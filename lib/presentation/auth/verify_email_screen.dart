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
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/layout/max_width_container.dart';

/// Shown right after registration until the traveler confirms their email.
/// Periodically checks verification status and offers a resend action.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _pollTimer;
  bool _justResent = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkVerified());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    final auth = context.read<AuthProvider>();
    await auth.refreshEmailVerified();
    if (auth.isEmailVerified && mounted) {
      context.go(RoutePaths.home);
    }
  }

  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.resendVerificationEmail();
    if (ok && mounted) setState(() => _justResent = true);
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
                  'We sent a verification link to $email. Open it to activate your TripNest PH account.',
                  style: theme.textTheme.bodyMedium,
                ),
                if (_justResent) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text('Verification email resent.', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary)),
                ],
                const SizedBox(height: AppSpacing.xl),
                AnimatedButton(label: 'I\'ve verified my email', isLoading: auth.isBusy, onPressed: auth.isBusy ? null : _checkVerified),
                const SizedBox(height: AppSpacing.sm),
                AnimatedButton(label: 'Resend Email', filled: false, isLoading: auth.isBusy, onPressed: auth.isBusy ? null : _resend),
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
    );
  }
}
