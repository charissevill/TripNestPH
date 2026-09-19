import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Shown the moment "Sign Up" is tapped on Login — before the registration
/// form itself even renders — so the choice of "just exploring" vs.
/// "business owner" (see `RegisterScreen`) is answered up front rather than
/// buried as an extra field inside the form. Returns `true` for Business
/// Owner, `false` for Just Exploring, or `null` if dismissed without
/// choosing (the caller should treat that the same as "just exploring"
/// rather than block navigation to Register over it).
Future<bool?> showRoleChoiceDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      // Scrolls rather than overflowing on a short viewport (landscape
      // phone) or at a large text size.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome to TripNest PH', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('What brings you here?', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            _RoleChoiceOption(
              icon: Symbols.explore_rounded,
              title: 'Just Exploring',
              subtitle: 'Discover destinations, plan trips, and save favorites.',
              onTap: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: AppSpacing.sm),
            _RoleChoiceOption(
              icon: Symbols.storefront_rounded,
              title: 'I Own a Business',
              subtitle: 'Apply for Business Owner access to list your business.',
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoleChoiceOption extends StatelessWidget {
  const _RoleChoiceOption({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Symbols.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
