import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Shown in place of "Nearby You" when [LocationService] couldn't get a
/// position, explaining why and offering the one recovery action that
/// actually applies to that specific reason (re-prompt vs. Settings).
class LocationPromptCard extends StatelessWidget {
  const LocationPromptCard({
    super.key,
    required this.status,
    required this.onAction,
    required this.onDismiss,
    this.isBusy = false,
  });

  final LocationAccessStatus status;
  final VoidCallback onAction;
  final VoidCallback onDismiss;
  final bool isBusy;

  String get _message {
    switch (status) {
      case LocationAccessStatus.serviceDisabled:
        return 'Turn on location services on your device to see the tourist spots closest to you.';
      case LocationAccessStatus.permissionDeniedForever:
        return 'Location access is turned off for TripNest PH. Enable it in Settings to see spots near you.';
      case LocationAccessStatus.permissionDenied:
        return 'Allow location access to see the tourist spots closest to you.';
      case LocationAccessStatus.unavailable:
        return 'We couldn\'t get your location just now. Please try again.';
      case LocationAccessStatus.granted:
        return '';
    }
  }

  String get _actionLabel {
    switch (status) {
      case LocationAccessStatus.serviceDisabled:
        return 'Open Location Settings';
      case LocationAccessStatus.permissionDeniedForever:
        return 'Open App Settings';
      case LocationAccessStatus.permissionDenied:
        return 'Allow Location';
      case LocationAccessStatus.unavailable:
        return 'Try Again';
      case LocationAccessStatus.granted:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.location_off_rounded, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('See what\'s nearby', style: theme.textTheme.titleMedium)),
              InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Symbols.close_rounded, size: 18, color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(_message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: isBusy ? null : onAction,
              child: isBusy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
