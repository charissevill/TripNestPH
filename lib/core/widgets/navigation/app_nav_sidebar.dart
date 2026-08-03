import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../branding/app_logo.dart';
import 'nav_tab_data.dart';

/// The persistent left navigation sidebar shown instead of [AppBottomNav]
/// once the window is wide enough (see `ResponsiveContext.useSideNav`) —
/// same 5 tabs from the same [kMainNavTabs] source, just chrome shaped for
/// a desktop/web window instead of a phone screen.
class AppNavSidebar extends StatelessWidget {
  const AppNavSidebar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(right: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.4))),
      ),
      child: SafeArea(
        right: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.xl),
              child: AppLogo(size: 36),
            ),
            for (var i = 0; i < kMainNavTabs.length; i++)
              _SidebarTab(
                tab: kMainNavTabs[i],
                selected: i == currentIndex,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarTab extends StatelessWidget {
  const _SidebarTab({required this.tab, required this.selected, required this.onTap});

  final NavTabData tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      child: Material(
        color: selected ? theme.colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Icon(tab.icon, size: 22, color: selected ? Colors.white : AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  tab.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected ? Colors.white : theme.colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
