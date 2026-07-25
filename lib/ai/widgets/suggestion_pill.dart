import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Shared "suggestion" pill for the AI Chat surface — the empty-state
/// prompt suggestions (with a leading sparkle icon) and the post-reply
/// quick-follow-ups (label only) are the same visual control with an
/// optional icon, not two separate chip designs.
class SuggestionPill extends StatelessWidget {
  const SuggestionPill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.maxWidth,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        constraints: maxWidth != null ? BoxConstraints(maxWidth: maxWidth!) : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: enabled ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: enabled ? null : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
