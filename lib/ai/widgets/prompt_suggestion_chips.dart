import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../prompts/chat_prompts.dart';

/// The empty-state "try asking..." chip rail (feature 10: AI prompt
/// suggestions). Tapping a chip sends it immediately via [onSelected].
class PromptSuggestionChips extends StatelessWidget {
  const PromptSuggestionChips({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: ChatPrompts.suggestions.map((suggestion) {
        return InkWell(
          onTap: () => onSelected(suggestion),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.border),
            ),
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - AppSpacing.lg * 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Symbols.auto_awesome_rounded, size: 15, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    suggestion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
