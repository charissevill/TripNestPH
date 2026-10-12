import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_spacing.dart';
import '../../theme/breakpoints.dart';

/// The search field + "sort by" button pair that sits above a searchable
/// list. The screen owns the text ([controller]) and the chosen [sort]; this
/// only draws the two controls and reports changes.
class SearchSortBar<T> extends StatelessWidget {
  const SearchSortBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onQueryChanged,
    required this.sort,
    required this.sortLabels,
    required this.onSortChanged,
  });

  final TextEditingController controller;
  final String hintText;

  /// Called on every edit, including the clear button.
  final VoidCallback onQueryChanged;

  final T sort;

  /// Every sort the menu offers, in menu order, with its label.
  final Map<T, String> sortLabels;
  final ValueChanged<T> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: const Icon(Symbols.search_rounded),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Symbols.close_rounded, size: 20),
                      onPressed: () {
                        controller.clear();
                        onQueryChanged();
                      },
                    ),
            ),
            onChanged: (_) => onQueryChanged(),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SortMenu<T>(
          value: sort,
          labels: sortLabels,
          onChanged: onSortChanged,
          // Only the icon where there isn't room for the label too.
          showLabel: !context.isCompact,
        ),
      ],
    );
  }
}

/// The "sort by" button on its own, for a screen whose search field is laid
/// out some other way.
class SortMenu<T> extends StatelessWidget {
  const SortMenu({
    super.key,
    required this.value,
    required this.labels,
    required this.onChanged,
    this.showLabel = true,
  });

  final T value;
  final Map<T, String> labels;
  final ValueChanged<T> onChanged;

  /// False where there's only room for the icon; the tooltip and the menu's
  /// own checked item still say which sort is active.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = labels[value] ?? '';
    return PopupMenuButton<T>(
      tooltip: 'Sort by: $label',
      initialValue: value,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      itemBuilder: (context) => [
        for (final entry in labels.entries) PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.sort_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
            if (showLabel) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
              const SizedBox(width: AppSpacing.xxs),
              Icon(Symbols.expand_more_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }
}
