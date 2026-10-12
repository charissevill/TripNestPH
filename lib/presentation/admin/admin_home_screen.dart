import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/back_navigation.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/utils/sign_out.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/business_owner_application_repository.dart';
import '../../data/repositories/business_repository.dart';
import '../../data/repositories/content_report_repository.dart';
import '../../data/repositories/review_report_repository.dart';
import '../../domain/models/admin_user.dart';
import 'widgets/admin_sidebar_shell.dart';

/// The Admin Portal's landing screen — built into this same traveler app
/// (not a separate project), reachable only via the "Admin Portal" tile on
/// Profile, which itself only renders for a signed-in user with an active
/// `admin_users` doc. This screen re-checks that live via [AdminRepository]
/// rather than trusting the caller, so a mid-session suspension or role
/// change (see `firestore.rules`'s "enforced live" comments) takes effect
/// immediately even if someone is already sitting on this screen.
///
/// On the dedicated Admin Portal site's desktop width, `AdminSidebarShell`
/// already lists every one of these same destinations in a persistent left
/// sidebar, so that width gets an actual overview instead of a bare list:
/// live counts of what's waiting on this account, then the same tiles laid
/// out as a grid (their subtitles are the one thing the sidebar doesn't
/// say). Below that breakpoint (including the traveler app's in-app Admin
/// Portal, which never gets the sidebar), the plain tile list is still how
/// navigation happens at all.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().firebaseUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: SafeArea(
          child: EmptyStateWidget(
            icon: Symbols.lock_rounded,
            title: 'Sign in required',
            message: 'Sign in to continue.',
          ),
        ),
      );
    }

    return StreamBuilder<AdminUser?>(
      stream: AdminRepository().streamSelf(uid),
      builder: (context, snapshot) {
        final admin = snapshot.data;
        // The desktop overview brings its own top bar (queue bell, account
        // menu, and the Back arrow when there's somewhere to go back to).
        final showsOverview =
            context.windowSize == WindowSize.expanded &&
            admin != null &&
            admin.isActive;
        return Scaffold(
          appBar: showsOverview
              ? null
              : AppBar(
                  // This is the standalone Admin Portal build's landing
                  // route — reached right after login with nothing to pop
                  // back to (see admin_router.dart) — so only show a back
                  // arrow when there's actually somewhere to go, instead of
                  // a dead button.
                  leading: context.canPop()
                      ? IconButton(
                          icon: const Icon(Symbols.arrow_back_rounded),
                          onPressed: () => context.popOrGo(RoutePaths.profile),
                        )
                      : null,
                  title: Text(_portalTitle(admin)),
                ),
          body: _AdminHomeBody(uid: uid, snapshot: snapshot),
        );
      },
    );
  }
}

/// A businessOwner account only ever sees "My Business" below — labeling
/// that as "Admin Portal" reads as if they'd somehow been granted admin
/// access, which they haven't.
String _portalTitle(AdminUser? admin) {
  return admin?.role == AdminRole.businessOwner
      ? 'Business Owner'
      : 'Admin Portal';
}

class _AdminHomeBody extends StatelessWidget {
  const _AdminHomeBody({required this.uid, required this.snapshot});

  final String uid;
  final AsyncSnapshot<AdminUser?> snapshot;

  @override
  Widget build(BuildContext context) {
    final admin = snapshot.data;
    if (admin == null && snapshot.connectionState == ConnectionState.waiting) {
      return LoadingWidget.block(height: 300);
    }
    if (admin == null || !admin.isActive) {
      return const SafeArea(
        child: EmptyStateWidget(
          icon: Symbols.block_rounded,
          title: 'No access',
          message: 'This account doesn\'t have an active Admin Portal role.',
        ),
      );
    }
    if (admin.isLguWithoutProvince) {
      return const SafeArea(
        child: EmptyStateWidget(
          icon: Symbols.public_off_rounded,
          title: 'No province assigned',
          message:
              'This LGU account isn\'t assigned to a province yet. Ask an admin to invite it again with a province.',
        ),
      );
    }

    final canManageContent =
        admin.role == AdminRole.admin || admin.role == AdminRole.lgu;
    final isAdmin = admin.role == AdminRole.admin;
    // The desktop sidebar switches sections with `go`, so the overview's own
    // cards do the same there; narrower layouts keep stacking with `push`.
    final expanded = context.windowSize == WindowSize.expanded;
    void open(String path, {Object? extra}) {
      if (expanded) {
        context.go(path, extra: extra);
      } else {
        context.push(path, extra: extra);
      }
    }

    final tiles = <Widget>[
      if (canManageContent) ...[
        _AdminModuleTile(
          icon: Symbols.public_rounded,
          color: AppColors.adminViolet,
          label: 'Provinces',
          subtitle:
              'Write overview, culture, tips, hotlines and budget guidance',
          onTap: () => open(RoutePaths.adminProvinces),
        ),
        _AdminModuleTile(
          icon: Symbols.place_rounded,
          color: AppColors.adminBlue,
          label: 'Tourist Spots',
          subtitle: 'Add, edit or remove destinations shown to travelers',
          onTap: () => open(RoutePaths.adminTouristSpots),
        ),
        _AdminModuleTile(
          icon: Symbols.celebration_rounded,
          color: AppColors.adminPink,
          label: 'Festivals',
          subtitle: 'Add, edit or remove festivals shown to travelers',
          onTap: () => open(RoutePaths.adminFestivals),
        ),
      ],
      if (admin.role == AdminRole.businessOwner)
        _AdminModuleTile(
          icon: Symbols.storefront_rounded,
          color: AppColors.adminTeal,
          label: 'My Business',
          subtitle: 'Submit or edit your business listing for admin approval',
          onTap: () => open(RoutePaths.myBusiness),
        ),
      if (canManageContent)
        _AdminModuleTile(
          icon: Symbols.bar_chart_rounded,
          color: AppColors.adminGreen,
          label: 'Analytics',
          subtitle: isAdmin
              ? 'Traveler, content, business and engagement stats'
              : 'Content and engagement stats for ${admin.provinceName ?? 'your province'}',
          onTap: () => open(RoutePaths.adminAnalytics),
        ),
      if (isAdmin)
        _AdminModuleTile(
          icon: Symbols.person_search_rounded,
          color: AppColors.adminOrange,
          label: 'Users',
          subtitle: 'Search, filter by role and suspend/reactivate accounts',
          onTap: () => open(RoutePaths.adminUsers),
        ),
      if (canManageContent)
        _AdminModuleTile(
          icon: Symbols.storefront_rounded,
          color: AppColors.adminTeal,
          label: 'Businesses',
          subtitle: isAdmin
              ? 'Approve, reject or suspend business owner submissions'
              : 'Approve, reject or suspend submissions in ${admin.provinceName ?? 'your province'}',
          onTap: () => open(RoutePaths.adminBusinesses),
        ),
      if (isAdmin)
        _AdminModuleTile(
          icon: Symbols.how_to_reg_rounded,
          color: AppColors.adminViolet,
          label: 'Business Applications',
          subtitle: 'Review requests to become a Business Owner',
          onTap: () => open(RoutePaths.adminBusinessOwnerApplications),
        ),
      if (isAdmin)
        _AdminModuleTile(
          icon: Symbols.flag_rounded,
          color: AppColors.adminPink,
          label: 'Reported Reviews',
          subtitle: 'Moderate reviews travelers have flagged',
          onTap: () => open(RoutePaths.adminReportedReviews),
        ),
      if (canManageContent)
        _AdminModuleTile(
          icon: Symbols.campaign_rounded,
          color: AppColors.adminBlue,
          label: 'Send Announcement',
          subtitle: isAdmin
              ? 'Broadcast a notification to every traveler'
              : 'Notify travelers with a trip or favorite in ${admin.provinceName ?? 'your province'}',
          onTap: () => open(RoutePaths.adminBroadcast),
        ),
      if (isAdmin)
        _AdminModuleTile(
          icon: Symbols.group_rounded,
          color: AppColors.adminGreen,
          label: 'Team',
          subtitle: 'Invite or manage Admin Portal accounts',
          onTap: () => open(
            RoutePaths.adminTeam,
            extra: {
              'uid': uid,
              'name': admin.name.isNotEmpty ? admin.name : admin.email,
            },
          ),
        ),
    ];

    if (expanded) {
      return _OverviewDashboard(
        // Its queue streams depend on the role and province, so a live
        // change to either rebuilds them rather than keeping stale ones.
        key: ValueKey('${admin.role}|${admin.provinceId}'),
        admin: admin,
        tiles: tiles,
        onOpen: open,
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Signed in as ${admin.name.isNotEmpty ? admin.name : admin.email}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 2),
          Text(
            admin.provinceName != null
                ? 'Role: ${admin.role} · Managing ${admin.provinceName}'
                : 'Role: ${admin.role}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (tiles.isEmpty)
            EmptyStateWidget(
              icon: Symbols.construction_rounded,
              title: 'Nothing here yet',
              message:
                  'The ${admin.role} workflow hasn\'t been built in this Admin Portal yet.',
            )
          else
            for (var i = 0; i < tiles.length; i++) ...[
              tiles[i],
              if (i != tiles.length - 1) const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}

/// The soft, violet-tinted lift every overview card sits on. A dark surface
/// swallows that shadow, so there it's an outline instead.
BoxDecoration _cardDecoration(BuildContext context, {Color? outline}) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  return BoxDecoration(
    color: theme.colorScheme.surface,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    border: outline != null
        ? Border.all(color: outline, width: 1.5)
        : dark
            ? Border.all(color: theme.dividerColor)
            : null,
    boxShadow: dark
        ? null
        : [
            BoxShadow(
              color: AppColors.adminViolet.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
  );
}

/// Who the overview greets: the account's name, never its email address. An
/// account with no name saved (on its admin doc or its sign-in profile) is
/// greeted by what it is instead.
String _greetingName(BuildContext context, AdminUser admin) {
  if (admin.name.trim().isNotEmpty) return admin.name.trim();
  final authName =
      context.read<AuthProvider>().firebaseUser?.displayName?.trim() ?? '';
  if (authName.isNotEmpty) return authName;
  switch (admin.role) {
    case AdminRole.businessOwner:
      return admin.businessName.trim().isNotEmpty
          ? admin.businessName.trim()
          : 'Business Owner';
    case AdminRole.lgu:
      return admin.provinceName ?? 'LGU';
    default:
      return 'Admin';
  }
}

/// One live "waiting on you" queue on the desktop overview.
class _AttentionItem {
  const _AttentionItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
    required this.path,
  });

  final IconData icon;
  final Color color;
  final String label;
  final Stream<int> count;
  final String path;
}

/// Desktop-width overview: who's signed in, how much is sitting in each
/// review queue this role can act on, then every module as a card.
class _OverviewDashboard extends StatefulWidget {
  const _OverviewDashboard({
    super.key,
    required this.admin,
    required this.tiles,
    required this.onOpen,
  });

  final AdminUser admin;
  final List<Widget> tiles;
  final void Function(String path) onOpen;

  @override
  State<_OverviewDashboard> createState() => _OverviewDashboardState();
}

class _OverviewDashboardState extends State<_OverviewDashboard> {
  // Held in state so a rebuild doesn't resubscribe every queue.
  late final List<_AttentionItem> _attention = _buildAttention();

  // Each queue is subscribed to exactly once and its latest count kept here,
  // since both its card and the top bar's bell read it. Stays null for a
  // queue this account can't read (or that hasn't loaded yet).
  late final List<ValueNotifier<int?>> _counts = [
    for (final _ in _attention) ValueNotifier<int?>(null),
  ];
  final List<StreamSubscription<int>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _attention.length; i++) {
      _subscriptions.add(
        _attention[i].count.listen(
          (count) => _counts[i].value = count,
          onError: (Object _) {},
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    for (final count in _counts) {
      count.dispose();
    }
    super.dispose();
  }

  List<_AttentionItem> _buildAttention() {
    final admin = widget.admin;
    final isAdmin = admin.role == AdminRole.admin;
    final isLgu = admin.role == AdminRole.lgu;
    return [
      if (isAdmin)
        _AttentionItem(
          icon: Symbols.how_to_reg_rounded,
          color: AppColors.adminViolet,
          label: 'Business applications to review',
          count: BusinessOwnerApplicationRepository()
              .streamPendingForAdmin()
              .map((applications) => applications.length),
          path: RoutePaths.adminBusinessOwnerApplications,
        ),
      if (isAdmin || isLgu)
        _AttentionItem(
          icon: Symbols.storefront_rounded,
          color: AppColors.adminBlue,
          label: 'Business listings awaiting approval',
          // Same province scoping an LGU account gets on the Businesses
          // screen itself.
          count: BusinessRepository()
              .streamAllForAdmin(provinceId: isLgu ? admin.provinceId : null)
              .map(
                (businesses) => businesses
                    .where(
                      (b) =>
                          b.isPending &&
                          (!isLgu ||
                              admin.provinceId == null ||
                              b.provinceId == admin.provinceId),
                    )
                    .length,
              ),
          path: RoutePaths.adminBusinesses,
        ),
      if (isAdmin) ...[
        _AttentionItem(
          icon: Symbols.flag_rounded,
          color: AppColors.adminGreen,
          label: 'Reported reviews',
          count: ReviewReportRepository()
              .streamAllForAdmin()
              .map((reports) => reports.length),
          path: RoutePaths.adminReportedReviews,
        ),
        _AttentionItem(
          icon: Symbols.report_rounded,
          color: AppColors.adminPink,
          label: 'Reported listings',
          count: ContentReportRepository()
              .streamAllForAdmin()
              .map((reports) => reports.length),
          path: RoutePaths.adminReportedReviews,
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final admin = widget.admin;
    final tiles = widget.tiles;
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: dark
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surface,
                  Color.lerp(AppColors.surface, AppColors.adminLavender, 0.7)!,
                ],
              ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _TopBar(
              admin: admin,
              attention: _attention,
              counts: _counts,
              onOpen: widget.onOpen,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1000;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Hero(
                              title: _portalTitle(admin),
                              name: _greetingName(context, admin),
                              subtitle: tiles.isEmpty
                                  ? 'The ${admin.role} workflow hasn\'t been built in this Admin Portal yet.'
                                  : _attention.isEmpty
                                      ? 'Pick a module below to get started.'
                                      : admin.provinceName != null
                                          ? 'Here\'s what\'s waiting on you in ${admin.provinceName}.'
                                          : 'Here\'s what\'s waiting on you.',
                              showArt: wide,
                            ),
                            if (_attention.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xl),
                              const _SectionHeader(
                                icon: Symbols.notifications_rounded,
                                label: 'Needs your attention',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _CardGrid(
                                // No more columns than there are queues, so
                                // an account with a single queue (LGU) gets
                                // one full-width card rather than a card and
                                // three empty slots.
                                columns: _attention.length < (wide ? 4 : 2)
                                    ? _attention.length
                                    : (wide ? 4 : 2),
                                children: [
                                  for (var i = 0; i < _attention.length; i++)
                                    _AttentionCard(
                                      item: _attention[i],
                                      count: _counts[i],
                                      horizontal: _attention.length == 1,
                                      onTap: () =>
                                          widget.onOpen(_attention[i].path),
                                    ),
                                ],
                              ),
                            ],
                            if (tiles.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xxl),
                              const _SectionHeader(
                                icon: Symbols.grid_view_rounded,
                                label: 'Modules',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _CardGrid(columns: wide ? 3 : 2, children: tiles),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The overview's own header strip, standing in for the `AppBar` at desktop
/// width: Back (only when there's somewhere to go back to), the review-queue
/// bell, and the signed-in account with its menu.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.admin,
    required this.attention,
    required this.counts,
    required this.onOpen,
  });

  final AdminUser admin;
  final List<_AttentionItem> attention;
  final List<ValueNotifier<int?>> counts;
  final void Function(String path) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          if (context.canPop())
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Symbols.arrow_back_rounded),
              onPressed: () => context.popOrGo(RoutePaths.profile),
            ),
          const Spacer(),
          if (attention.isNotEmpty) ...[
            _QueueBell(attention: attention, counts: counts, onOpen: onOpen),
            const SizedBox(width: AppSpacing.md),
          ],
          _AccountMenu(admin: admin),
        ],
      ),
    );
  }
}

/// Bell with a dot whenever any review queue has something in it; opens the
/// same queues the "Needs your attention" cards show, with their counts.
class _QueueBell extends StatelessWidget {
  const _QueueBell({
    required this.attention,
    required this.counts,
    required this.onOpen,
  });

  final List<_AttentionItem> attention;
  final List<ValueNotifier<int?>> counts;
  final void Function(String path) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      tooltip: 'Review queues',
      position: PopupMenuPosition.under,
      onSelected: onOpen,
      itemBuilder: (context) => [
        for (var i = 0; i < attention.length; i++)
          PopupMenuItem<String>(
            value: attention[i].path,
            child: Row(
              children: [
                Icon(attention[i].icon, size: 20, color: attention[i].color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(attention[i].label)),
                const SizedBox(width: AppSpacing.md),
                Text(
                  counts[i].value?.toString() ?? '—',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
      icon: ListenableBuilder(
        listenable: Listenable.merge(counts),
        builder: (context, _) {
          final waiting = counts.any((count) => (count.value ?? 0) > 0);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Symbols.notifications_rounded, size: 26),
              if (waiting)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.admin});

  final AdminUser admin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      tooltip: 'Account',
      position: PopupMenuPosition.under,
      onSelected: (_) async {
        final signedOut = await confirmSignOut(context);
        if (signedOut && context.mounted) context.go(RoutePaths.login);
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'signOut',
          child: Row(
            children: [
              Icon(Symbols.logout_rounded, size: 20),
              SizedBox(width: AppSpacing.sm),
              Text('Sign out'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminAvatar(admin: admin, radius: 22),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    admin.name.isNotEmpty ? admin.name : admin.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  AdminRoleChip(admin: admin),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Symbols.expand_more_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// The welcome block: portal name, who's signed in, what the page is for —
/// with the travel illustration alongside when there's room for it.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.name,
    required this.subtitle,
    required this.showArt,
  });

  final String title;
  final String name;
  final String subtitle;
  final bool showArt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final violet = adminVioletOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: violet,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text.rich(
                TextSpan(
                  text: 'Welcome back, ',
                  children: [
                    TextSpan(text: name, style: TextStyle(color: violet)),
                  ],
                ),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (showArt) ...[
          const SizedBox(width: AppSpacing.xl),
          const ExcludeSemantics(child: _HeroArt()),
        ],
      ],
    );
  }
}

/// Purely decorative: layered hills, clouds, a map pin and a plane, plus the
/// handwritten tagline.
class _HeroArt extends StatelessWidget {
  const _HeroArt();

  @override
  Widget build(BuildContext context) {
    final violet = adminVioletOf(context);
    return SizedBox(
      width: 460,
      height: 150,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 110,
            top: 0,
            bottom: 0,
            child: CustomPaint(painter: _HillsPainter(violet)),
          ),
          Positioned(
            left: 138,
            top: 40,
            child: Icon(
              Symbols.location_on_rounded,
              fill: 1,
              size: 40,
              color: violet,
            ),
          ),
          Positioned(
            left: 206,
            top: 12,
            child: Transform.rotate(
              angle: 1.25,
              child: Icon(
                Symbols.flight_rounded,
                fill: 1,
                size: 30,
                color: violet.withValues(alpha: 0.55),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 12,
            child: Transform.rotate(
              angle: -0.16,
              child: Text(
                'Better\nPlaces\nTogether',
                textAlign: TextAlign.center,
                style: GoogleFonts.caveat(
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: violet,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HillsPainter extends CustomPainter {
  const _HillsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cloud = Paint()..color = color.withValues(alpha: 0.10);
    _cloud(canvas, cloud, Offset(size.width * 0.16, size.height * 0.22), 1);
    _cloud(canvas, cloud, Offset(size.width * 0.86, size.height * 0.5), 1.2);

    canvas.drawPath(
      _ridge(size, const [
        Offset(0, 0.96),
        Offset(0.16, 0.62),
        Offset(0.3, 0.28),
        Offset(0.46, 0.66),
        Offset(0.6, 0.46),
        Offset(0.8, 0.84),
        Offset(1, 0.96),
      ]),
      Paint()..color = color.withValues(alpha: 0.22),
    );
    canvas.drawPath(
      _ridge(size, const [
        Offset(0, 1),
        Offset(0.14, 0.8),
        Offset(0.3, 0.6),
        Offset(0.46, 0.86),
        Offset(0.64, 0.68),
        Offset(0.82, 0.9),
        Offset(1, 1),
      ]),
      Paint()..color = color.withValues(alpha: 0.32),
    );
  }

  /// A filled silhouette running through [points] (fractions of [size]),
  /// rounded off at each peak and dip.
  Path _ridge(Size size, List<Offset> points) {
    Offset at(int i) =>
        Offset(points[i].dx * size.width, points[i].dy * size.height);
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      final previous = at(i - 1);
      final mid = Offset.lerp(previous, at(i), 0.5)!;
      path.quadraticBezierTo(previous.dx, previous.dy, mid.dx, mid.dy);
    }
    return path
      ..lineTo(size.width, at(points.length - 1).dy)
      ..lineTo(size.width, size.height)
      ..close();
  }

  void _cloud(Canvas canvas, Paint paint, Offset center, double scale) {
    canvas.drawCircle(center, 16 * scale, paint);
    canvas.drawCircle(center + Offset(-18 * scale, 6 * scale), 11 * scale, paint);
    canvas.drawCircle(center + Offset(19 * scale, 5 * scale), 12 * scale, paint);
  }

  @override
  bool shouldRepaint(_HillsPainter oldDelegate) => oldDelegate.color != color;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 24, color: adminVioletOf(context)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Lays [children] out [columns] across, every card in a row as tall as
/// that row's tallest — a plain `Wrap` leaves them ragged whenever one
/// subtitle runs to a second line.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i += columns) ...[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = i; j < i + columns; j++) ...[
                  if (j > i) const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: j < children.length
                        ? children[j]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.item,
    required this.count,
    required this.onTap,
    this.horizontal = false,
  });

  final _AttentionItem item;
  final ValueNotifier<int?> count;
  final VoidCallback onTap;

  /// Lays the card out as a single row — icon, label, count, chevron — for
  /// when it's the only one and spans the full width.
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<int?>(
      valueListenable: count,
      builder: (context, count, _) {
        final waiting = (count ?? 0) > 0;
        // A queue this account can't read (or that hasn't loaded yet) shows
        // a dash rather than a misleading zero.
        final countLabel = count?.toString() ?? '—';
        if (horizontal) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: _cardDecoration(
                context,
                outline: waiting ? item.color : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    alignment: Alignment.center,
                    child: Icon(item.icon, color: item.color, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  // Count sits right beside the label rather than out at the
                  // far edge, so the row doesn't read as a gap.
                  Text(
                    countLabel,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      item.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Symbols.chevron_right_rounded, color: item.color),
                ],
              ),
            ),
          );
        }
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            // A queue with something in it gets its accent as an outline,
            // so it stands out from the ones sitting at zero.
            decoration: _cardDecoration(
              context,
              outline: waiting ? item.color : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  alignment: Alignment.center,
                  child: Icon(item.icon, color: item.color, size: 26),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  item.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        countLabel,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(Symbols.chevron_right_rounded, color: item.color),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdminModuleTile extends StatelessWidget {
  const _AdminModuleTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: _cardDecoration(context),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // Soft wash of the module's accent curving in from the right.
              Positioned(
                top: -40,
                bottom: -40,
                right: -70,
                width: 190,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color.lerp(color, Colors.white, 0.3)!, color],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, fill: 1, size: 30, color: Colors.white),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xl),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Symbols.chevron_right_rounded,
                          size: 20,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
