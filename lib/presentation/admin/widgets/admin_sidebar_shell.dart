import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/route_paths.dart';
import '../../../core/services/weather_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/utils/icon_registry.dart';
import '../../../core/utils/sign_out.dart';
import '../../../core/widgets/branding/app_logo.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../domain/models/admin_user.dart';
import '../../../domain/models/current_weather.dart';

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
///
/// The sidebar can be collapsed to a rail of just its icons (each still
/// labeled by a tooltip) to give the section more room; that choice lasts
/// for as long as the portal stays open.
class AdminSidebarShell extends StatefulWidget {
  const AdminSidebarShell({super.key, required this.child, required this.currentPath});

  final Widget child;
  final String currentPath;

  @override
  State<AdminSidebarShell> createState() => _AdminSidebarShellState();
}

class _AdminSidebarShellState extends State<AdminSidebarShell> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    if (context.windowSize != WindowSize.expanded) return child;

    final uid = context.watch<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return child;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: _collapsed ? 76 : 288,
            child: StreamBuilder<AdminUser?>(
              stream: AdminRepository().streamSelf(uid),
              builder: (context, snapshot) {
                final admin = snapshot.data;
                return _Sidebar(
                  admin: admin,
                  currentPath: widget.currentPath,
                  collapsed: _collapsed,
                  onToggle: () => setState(() => _collapsed = !_collapsed),
                );
              },
            ),
          ),
          VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
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

/// The Admin Portal's violet, a lighter step of it on a dark surface where
/// the full-strength one doesn't have the contrast to read as text.
Color adminVioletOf(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark ? AppColors.adminVioletLight : AppColors.adminViolet;
}

/// The signed-in account's photo, or its initials on the portal's violet —
/// shared by the sidebar footer and the overview's top bar.
class AdminAvatar extends StatelessWidget {
  const AdminAvatar({super.key, required this.admin, this.radius = 20});

  final AdminUser admin;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final displayName = admin.name.isNotEmpty ? admin.name : admin.email;
    final initials = displayName.trim().isEmpty
        ? '?'
        : displayName.trim().split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.adminVioletLight,
      backgroundImage: admin.photoUrl.isNotEmpty ? NetworkImage(admin.photoUrl) : null,
      // A failed photo just leaves the tinted circle instead of
      // surfacing an uncaught image-load error.
      onBackgroundImageError: admin.photoUrl.isNotEmpty ? (error, stackTrace) {} : null,
      child: admin.photoUrl.isNotEmpty
          ? null
          : Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }
}

/// The role pill under the account name ("Admin", "Lgu · Cebu", ...).
class AdminRoleChip extends StatelessWidget {
  const AdminRoleChip({super.key, required this.admin});

  final AdminUser admin;

  @override
  Widget build(BuildContext context) {
    final violet = adminVioletOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: violet.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        admin.provinceName != null ? '${_roleLabel(admin.role)} · ${admin.provinceName}' : _roleLabel(admin.role),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: violet, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.admin,
    required this.currentPath,
    required this.collapsed,
    required this.onToggle,
  });

  final AdminUser? admin;
  final String currentPath;

  /// Icons only, no labels — see [AdminSidebarShell].
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (admin == null || !admin!.isActive) {
      // AdminHomeScreen's own body already renders the "No access" empty
      // state in the main content area — the sidebar just stays quiet
      // rather than showing nav items nobody's entitled to use.
      return ColoredBox(color: theme.colorScheme.surface);
    }
    final admin_ = admin!;
    // An 'lgu' account with no province gets no content sections — see
    // `AdminUser.isLguWithoutProvince`.
    final canManageContent =
        admin_.role == AdminRole.admin || (admin_.role == AdminRole.lgu && !admin_.isLguWithoutProvince);
    final isAdmin = admin_.role == AdminRole.admin;

    final items = <_NavItem>[
      if (canManageContent) ...[
        const _NavItem(icon: Symbols.map_rounded, label: 'Provinces', path: RoutePaths.adminProvinces),
        const _NavItem(icon: Symbols.place_rounded, label: 'Tourist Spots', path: RoutePaths.adminTouristSpots),
        const _NavItem(icon: Symbols.celebration_rounded, label: 'Festivals', path: RoutePaths.adminFestivals),
      ],
      if (admin_.role == AdminRole.businessOwner)
        const _NavItem(icon: Symbols.storefront_rounded, label: 'My Business', path: RoutePaths.myBusiness),
      if (canManageContent)
        const _NavItem(icon: Symbols.bar_chart_rounded, label: 'Analytics', path: RoutePaths.adminAnalytics),
      if (isAdmin)
        const _NavItem(icon: Symbols.person_search_rounded, label: 'Users', path: RoutePaths.adminUsers),
      // An LGU reviews the listings in its own province — see
      // `AdminBusinessListScreen`.
      if (canManageContent)
        const _NavItem(icon: Symbols.storefront_rounded, label: 'Businesses', path: RoutePaths.adminBusinesses),
      if (isAdmin) ...[
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

    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? theme.colorScheme.surface : null,
        gradient: dark
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.surface, AppColors.adminLavender],
              ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (collapsed)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
                child: Center(
                  child: Column(
                    children: [
                      const AppLogo(size: 40),
                      const SizedBox(height: AppSpacing.xs),
                      IconButton(
                        tooltip: 'Expand sidebar',
                        onPressed: onToggle,
                        icon: const Icon(Symbols.menu_rounded, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.xs, AppSpacing.md),
              child: Row(
                children: [
                  const AppLogo(size: 44),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TripNest PH',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'ADMIN PORTAL',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Collapse sidebar',
                    onPressed: onToggle,
                    icon: const Icon(Symbols.menu_open_rounded, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: collapsed ? 10 : AppSpacing.md),
                children: [
                  _SidebarTile(
                    icon: Symbols.home_rounded,
                    label: 'Overview',
                    selected: currentPath == RoutePaths.adminHome,
                    collapsed: collapsed,
                    onTap: () => context.go(RoutePaths.adminHome),
                  ),
                  for (final item in items)
                    _SidebarTile(
                      icon: item.icon,
                      label: item.label,
                      selected: currentPath == item.path,
                      collapsed: collapsed,
                      onTap: () => context.go(item.path, extra: item.extra),
                    ),
                ],
              ),
            ),
            _ProfileFooter(admin: admin_, collapsed: collapsed),
            // Ambient, so the rail just goes without it.
            if (!collapsed) const _SidebarWeather(),
          ],
        ),
      ),
    );
  }
}

class _ProfileFooter extends StatelessWidget {
  const _ProfileFooter({required this.admin, required this.collapsed});

  final AdminUser admin;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = admin.name.isNotEmpty ? admin.name : admin.email;
    final signOut = IconButton(
      tooltip: 'Sign out',
      onPressed: () async {
        final signedOut = await confirmSignOut(context);
        if (signedOut && context.mounted) context.go(RoutePaths.login);
      },
      icon: const Icon(Symbols.logout_rounded, size: 20, color: AppColors.textSecondary),
    );
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(message: displayName, child: AdminAvatar(admin: admin)),
              signOut,
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.xxs, AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.adminViolet.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          AdminAvatar(admin: admin),
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
                const SizedBox(height: 4),
                AdminRoleChip(admin: admin),
              ],
            ),
          ),
          signOut,
        ],
      ),
    );
  }
}

/// The "right now" reading tucked under the profile card. Purely ambient:
/// while it's loading, or if the weather service can't be reached, it
/// simply isn't there rather than taking sidebar room for an error.
class _SidebarWeather extends StatefulWidget {
  const _SidebarWeather();

  @override
  State<_SidebarWeather> createState() => _SidebarWeatherState();
}

class _SidebarWeatherState extends State<_SidebarWeather> {
  // Manila — the portal has no location of its own to read.
  static const double _latitude = 14.5995;
  static const double _longitude = 120.9842;

  late final Future<CurrentWeather> _future = _load();

  Future<CurrentWeather> _load() async {
    final service = WeatherService();
    try {
      return await service.getCurrentWeather(latitude: _latitude, longitude: _longitude);
    } finally {
      service.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<CurrentWeather>(
      future: _future,
      builder: (context, snapshot) {
        final weather = snapshot.data;
        if (weather == null) return const SizedBox(height: AppSpacing.xs);
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.lg, AppSpacing.md),
          child: Row(
            children: [
              Icon(IconRegistry.resolve(weather.iconKey), size: 28, color: AppColors.accentDark),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${weather.temperature.round()}°C',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${weather.condition} · Manila',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.collapsed = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Just the icon, with [label] as its tooltip.
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final violet = adminVioletOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? violet.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Row(
              // The rail has room for the icon alone.
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Tooltip(
                  message: collapsed ? label : '',
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected
                          ? violet.withValues(alpha: 0.16)
                          : dark
                              ? theme.scaffoldBackgroundColor
                              : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: selected ? null : Border.all(color: theme.dividerColor),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 22, color: selected ? violet : AppColors.textSecondary, semanticLabel: collapsed ? label : null),
                  ),
                ),
                if (!collapsed) ...[
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: selected ? violet : null,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
