import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_spacing.dart';
import '../prompts/chat_prompts.dart';
import 'suggestion_pill.dart';

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
        return SuggestionPill(
          label: suggestion,
          icon: Symbols.auto_awesome_rounded,
          maxWidth: MediaQuery.sizeOf(context).width - AppSpacing.lg * 2,
          onTap: () => onSelected(suggestion),
        );
      }).toList(),
    );
  }
}
