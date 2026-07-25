import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../buttons/animated_button.dart';

/// A friendly, illustrated empty state for Saved, Search results, and any
/// other list that can legitimately come up empty.
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onActionTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.huge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: AppColors.gradient([theme.colorScheme.primary, theme.colorScheme.primaryFixedDim]),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: Colors.white),
          ).animate().scale(duration: 420.ms, curve: Curves.easeOutBack),
          const SizedBox(height: AppSpacing.xl),
          Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.xl),
            AnimatedButton(label: actionLabel!, onPressed: onActionTap, icon: Symbols.explore_rounded, expand: false),
          ],
        ],
      ),
    );
    // Scrolls instead of overflowing when the available height is bounded
    // but too short for the illustration + text to fit — e.g. a keyboard
    // open above a search box shrinks whatever empty state sits below it.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return content;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        );
      },
    ).animate().fadeIn(duration: 320.ms);
  }
}
