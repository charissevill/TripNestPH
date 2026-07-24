import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../providers/connectivity_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// A slim "you're offline" strip shown above the main tab content.
/// Firestore's own offline cache keeps most screens usable without a
/// connection — this is just a heads-up, not a blocking error state.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityProvider>().isOnline;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: isOnline
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              color: AppColors.warning,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Symbols.cloud_off_rounded, size: 15, color: AppColors.textPrimary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'You\'re offline — showing saved data',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
