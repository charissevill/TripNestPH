import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'nav_tab_data.dart';

/// The floating, rounded bottom navigation bar shared by every top-level
/// tab (Home, Explore, AI Planner, Saved, Profile).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isBusinessOwner = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// See [mainNavTabsFor] — swaps the "Saved" tab for "My Business".
  final bool isBusinessOwner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The selected tab shows its label next to its icon ("My Business" is the
    // longest), which needs more room than a very narrow phone has — trim the
    // spacing there. Unchanged at 360px and wider.
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final barMargin = narrow ? AppSpacing.xs : AppSpacing.md;
    return Container(
      margin: EdgeInsets.fromLTRB(barMargin, 0, barMargin, AppSpacing.md),
      padding: EdgeInsets.symmetric(
        horizontal: narrow ? AppSpacing.xxs : AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: GNav(
          selectedIndex: currentIndex,
          onTabChange: onTap,
          rippleColor: theme.colorScheme.primary.withValues(alpha: 0.08),
          hoverColor: theme.colorScheme.primary.withValues(alpha: 0.06),
          gap: 4,
          activeColor: Colors.white,
          iconSize: 20,
          padding: EdgeInsets.symmetric(
            horizontal: narrow ? AppSpacing.xxs : AppSpacing.xs,
            vertical: 10,
          ),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          tabBackgroundColor: theme.colorScheme.primary,
          color: AppColors.textSecondary,
          textStyle: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          tabs: mainNavTabsFor(
            isBusinessOwner: isBusinessOwner,
          ).map((tab) => GButton(icon: tab.icon, text: tab.label)).toList(),
        ),
      ),
    );
  }
}
