import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/branding/app_logo.dart';

/// The brand mark + title/subtitle shown at the top of every auth screen,
/// echoing the Splash screen's ocean-gradient icon treatment.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Center(child: AppLogo(size: 160)),
        const SizedBox(height: AppSpacing.lg),
        Text(title, style: theme.textTheme.displayMedium, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(subtitle, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
      ],
    );
  }
}
