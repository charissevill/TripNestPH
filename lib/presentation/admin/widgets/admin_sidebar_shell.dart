import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/utils/sign_out.dart';
import '../../../core/widgets/branding/app_logo.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../domain/models/admin_user.dart';

/// Wraps every `/admin/*` route (see `admin_router.dart`'s `ShellRoute`)
/// with a persistent left sidebar once there's genuine desktop-width room
/// — the same [WindowSize.expanded] threshold the auth screens already use
/// for their own split layouts. Below that, this is a no-op: [child] renders
/// exactly as it always has, back button and all, since a sidebar competing
/// with a phone-width screen for space would just be cramped, not useful.
///
/// The nav item list here deliberately mirrors `AdminHomeScreen`'s own
/// role-gated tile list exactly — same routes, same role checks, same
/// icons — so switching between the sidebar and that screen's tiles (still
/// what a narrow window sees) never feels like two different apps.
class AdminSidebarShell extends StatelessWidget {
  const AdminSidebarShell({super.key, required this.child, required this.currentPath});

  final Widget child;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    if (context.windowSize != WindowSize.expanded) return child;

    final uid = context.watch<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return child;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 288,
            child: StreamBuilder<AdminUser?>(
              stream: AdminRepository().streamSelf(uid),
              builder: (context, snapshot) {
                final admin = snapshot.data;
                return _Sidebar(admin: admin, currentPath: currentPath);
              },
            ),
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label, required this.path, this.extra});

  final IconData icon;
  final String label;
  final String path;
  final Object? extra;
}

/// 'businessOwner' -> 'Business Owner'; every [AdminRole] value is already
/// a single word except that one.
String _roleLabel(String role) {
  return role == AdminRole.businessOwner ? 'Business Owner' : role[0].toUpperCase() + role.substring(1);
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.admin, required this.currentPath});

  final AdminUser? admin;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    if (admin == null || !admin!.isActive) {
      // AdminHomeScreen's own body already renders the "No access" empty
      // state in the main content area — the sidebar just stays quiet
      // rather than showing nav items nobody's entitled to use.
      return const ColoredBox(color: AppColors.surface);
    }
    final admin_ = admin!;
    final canManageContent = admin_.role == AdminRole.admin || admin_.role == AdminRole.lgu;
    final isAdmin = admin_.role == AdminRole.admin;

    final items = <_NavItem>[
      if (canManageContent) ...[
        const _NavItem(icon: Symbols.public_rounded, label: 'Provinces', path: RoutePaths.adminProvinces),
        const _NavItem(
          icon: Symbols.edit_note_rounded,
          label: 'Bulk Fill Province Content',
          path: RoutePaths.adminBulkProvinceContent,
        ),
        const _NavItem(icon: Symbols.place_rounded, label: 'Tourist Spots', path: RoutePaths.adminTouristSpots),
        const _NavItem(icon: Symbols.upload_file_rounded, label: 'Bulk Import', path: RoutePaths.adminBulkImport),
        const _NavItem(icon: Symbols.celebration_rounded, label: 'Festivals', path: RoutePaths.adminFestivals),
      ],
      if (admin_.role == AdminRole.businessOwner)
        const _NavItem(icon: Symbols.storefront_rounded, label: 'My Business', path: RoutePaths.myBusiness),
      if (canManageContent)
        const _NavItem(icon: Symbols.analytics_rounded, label: 'Analytics', path: RoutePaths.adminAnalytics),
      if (isAdmin) ...[
        const _NavItem(icon: Symbols.person_search_rounded, label: 'Travelers', path: RoutePaths.adminUsers),
        const _NavItem(icon: Symbols.storefront_rounded, label: 'Businesses', path: RoutePaths.adminBusinesses),
        const _NavItem(
          icon: Symbols.how_to_reg_rounded,
          label: 'Business Applications',
          path: RoutePaths.adminBusinessOwnerApplications,
        ),
        const _NavItem(
          icon: Symbols.flag_rounded,
          label: 'Reported Reviews',
          path: RoutePaths.adminReportedReviews,
        ),
      ],
      if (canManageContent)
        const _NavItem(icon: Symbols.campaign_rounded, label: 'Send Announcement', path: RoutePaths.adminBroadcast),
      if (isAdmin)
        _NavItem(
          icon: Symbols.group_rounded,
          label: 'Team',
          path: RoutePaths.adminTeam,
          extra: {'uid': admin_.uid, 'name': admin_.name.isNotEmpty ? admin_.name : admin_.email},
        ),
    ];

    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
              child: Row(
                children: [
                  const AppLogo(size: 36),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TripNest PH', style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          'ADMIN PORTAL',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
                children: [
                  _SidebarTile(
                    icon: Symbols.home_rounded,
                    label: 'Overview',
                    selected: currentPath == RoutePaths.adminHome,
                    onTap: () => context.go(RoutePaths.adminHome),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Divider(height: AppSpacing.md, color: AppColors.divider),
                  ),
                  for (final item in items)
                    _SidebarTile(
                      icon: item.icon,
                      label: item.label,
                      selected: currentPath == item.path,
                      onTap: () => context.go(item.path, extra: item.extra),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            _ProfileFooter(admin: admin_),
          ],
        ),
      ),
    );
  }
}

class _ProfileFooter extends StatelessWidget {
  const _ProfileFooter({required this.admin});

  final AdminUser admin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = admin.name.isNotEmpty ? admin.name : admin.email;
    final initials = displayName.trim().isEmpty
        ? '?'
        : displayName.trim().split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: admin.photoUrl.isNotEmpty ? NetworkImage(admin.photoUrl) : null,
            child: admin.photoUrl.isNotEmpty
                ? null
                : Text(initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    admin.provinceName != null ? '${_roleLabel(admin.role)} · ${admin.provinceName}' : _roleLabel(admin.role),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.secondaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              final signedOut = await confirmSignOut(context);
              if (signedOut && context.mounted) context.go(RoutePaths.login);
            },
            icon: const Icon(Symbols.logout_rounded, size: 20, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 18, color: selected ? Colors.white : AppColors.textSecondary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
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
