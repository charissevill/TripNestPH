import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/constants/legal_content.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/inputs/search_bar_widget.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../domain/models/legal_section.dart';

/// Frequently asked questions — searchable, grouped by category, and
/// rendered as an expandable list rather than a wall of text, since most
/// travelers are only looking for one answer.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key, required this.items});

  final List<FaqItem> items;

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _selectedCategory;
  FaqItem? _expandedItem;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final present = widget.items.map((i) => i.category).toSet();
    return LegalContent.faqCategoryOrder.where(present.contains).toList();
  }

  List<FaqItem> get _filtered {
    final query = _query.trim().toLowerCase();
    return widget.items.where((item) {
      if (_selectedCategory != null && item.category != _selectedCategory) return false;
      if (query.isEmpty) return true;
      return item.question.toLowerCase().contains(query) || item.answer.toLowerCase().contains(query);
    }).toList();
  }

  Map<String, List<FaqItem>> _grouped(List<FaqItem> items) {
    final grouped = <String, List<FaqItem>>{};
    for (final category in _categories) {
      final matches = items.where((i) => i.category == category).toList();
      if (matches.isNotEmpty) grouped[category] = matches;
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    final grouped = _grouped(filtered);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => context.pop()),
        title: const Text('FAQ'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
            child: SearchBarWidget(
              hintText: 'Search questions...',
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              trailing: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Symbols.close_rounded, size: 18, color: AppColors.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: _categories.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _CategoryChip(label: 'All', selected: _selectedCategory == null, onTap: () => setState(() => _selectedCategory = null));
                }
                final category = _categories[i - 1];
                return _CategoryChip(
                  label: category,
                  selected: _selectedCategory == category,
                  onTap: () => setState(() => _selectedCategory = _selectedCategory == category ? null : category),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: filtered.isEmpty
                ? EmptyStateWidget(
                    icon: Symbols.search_off_rounded,
                    title: 'No matches',
                    message: 'Try a different search term or category.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.huge),
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.sm),
                          child: Text(
                            entry.key.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, letterSpacing: 0.6, fontWeight: FontWeight.w700),
                          ),
                        ),
                        for (final item in entry.value)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _FaqTile(
                              item: item,
                              expanded: _expandedItem == item,
                              onTap: () => setState(() => _expandedItem = _expandedItem == item ? null : item),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: selected ? Colors.white : AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.item, required this.expanded, required this.onTap});

  final FaqItem item;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: expanded ? theme.colorScheme.primary.withValues(alpha: 0.3) : AppColors.border),
        boxShadow: expanded
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 6))]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.question,
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Symbols.expand_more_rounded, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                  firstChild: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(item.answer, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.6)),
                  ),
                  secondChild: const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
