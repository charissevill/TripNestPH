import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/banners/offline_banner.dart';
import '../../core/widgets/navigation/app_bottom_nav.dart';

/// Hosts the five top-level tabs (Home, Explore, AI Planner, Saved, Profile)
/// behind the floating bottom navigation bar, preserving each tab's own
/// navigation stack and scroll position via [StatefulShellRoute].
class MainShellScreen extends StatelessWidget {
  const MainShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      floatingActionButton: _AiChatFab(onTap: () => context.push(RoutePaths.aiChat)),
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
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
