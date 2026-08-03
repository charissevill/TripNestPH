import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/widgets/banners/offline_banner.dart';
import '../../core/widgets/navigation/app_bottom_nav.dart';
import '../../core/widgets/navigation/app_nav_sidebar.dart';

/// Hosts the five top-level tabs (Home, Explore, AI Planner, Saved, Profile)
/// preserving each tab's own navigation stack and scroll position via
/// [StatefulShellRoute] — behind the floating bottom navigation bar on a
/// phone-width window, or a persistent left sidebar once there's room for
/// one (see [ResponsiveContext.useSideNav]).
class MainShellScreen extends StatelessWidget {
  const MainShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    // Hidden on the AI Planner tab: it already has its own prominent
    // "AI Trip Planner" CTA, so a second floating entry point into AI
    // features is redundant there — and was the exact thing colliding
    // with that tab's pinned "Generate Itinerary" button.
    final fab = navigationShell.currentIndex == 2
        ? null
        : _AiChatFab(onTap: () => context.push(RoutePaths.aiChat));

    // Kept as a verbatim copy of the original single-Scaffold layout below
    // this breakpoint — this branch must never be refactored to share code
    // with the desktop one, so a desktop-only change can never leak into
    // the mobile layout.
    if (context.useSideNav) {
      return Scaffold(
        body: Row(
          children: [
            AppNavSidebar(currentIndex: navigationShell.currentIndex, onTap: _onTap),
            Expanded(
              child: Column(
                children: [
                  const OfflineBanner(),
                  Expanded(child: navigationShell),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: fab,
      );
    }

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      floatingActionButton: fab,
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
      ),
    );
  }
}

/// Floating entry point into the AI Travel Assistant, visible on every tab.
class _AiChatFab extends StatelessWidget {
  const _AiChatFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppColors.gradient([colorScheme.primary, colorScheme.primaryFixedDim]),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const Icon(Symbols.auto_awesome_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
