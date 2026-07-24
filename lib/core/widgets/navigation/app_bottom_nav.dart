import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// The floating, rounded bottom navigation bar shared by every top-level
/// tab (Home, Explore, AI Planner, Saved, Profile).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: GNav(
          selectedIndex: currentIndex,
          onTabChange: onTap,
          rippleColor: AppColors.primary.withValues(alpha: 0.08),
          hoverColor: AppColors.primary.withValues(alpha: 0.06),
          gap: 4,
          activeColor: Colors.white,
          iconSize: 20,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 10),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          tabBackgroundColor: AppColors.primary,
          color: AppColors.textSecondary,
          textStyle: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          tabs: const [
            GButton(icon: Symbols.home_rounded, text: 'Home'),
            GButton(icon: Symbols.explore_rounded, text: 'Explore'),
            GButton(icon: Symbols.auto_awesome_rounded, text: 'Planner'),
            GButton(icon: Symbols.bookmark_rounded, text: 'Saved'),
            GButton(icon: Symbols.person_rounded, text: 'Profile'),
          ],
        ),
      ),
    );
  }
}
