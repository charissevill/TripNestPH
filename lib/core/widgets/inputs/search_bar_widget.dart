import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// The rounded, soft-shadowed search field reused on Home (as a tappable
/// entry point) and on the Search screen (as a live text field).
class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({
    super.key,
    this.hintText = 'Search destinations, food, festivals...',
    this.onTap,
    this.controller,
    this.readOnly = false,
    this.autofocus = false,
    this.onChanged,
    this.trailing,
    this.onFilterTap,
  });

  final String hintText;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final bool readOnly;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;
  final VoidCallback? onFilterTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.md),
          Icon(Symbols.search_rounded, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              onTap: onTap,
              readOnly: readOnly,
              autofocus: autofocus,
              onChanged: onChanged,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: theme.textTheme.bodyMedium,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
            ),
          ),
          ?trailing,
          if (onFilterTap != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: InkWell(
                onTap: onFilterTap,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Symbols.tune_rounded, color: AppColors.primary, size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
