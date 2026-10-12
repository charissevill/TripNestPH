import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/back_navigation.dart';
import '../../../core/routes/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/utils/sign_out.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/repositories/business_owner_application_repository.dart';
import '../../../data/repositories/business_repository.dart';
import '../../../data/repositories/content_report_repository.dart';
import '../../../data/repositories/review_report_repository.dart';
import '../../../domain/models/admin_user.dart';
import 'admin_sidebar_shell.dart';

const double _topBarHeight = 60;
const double _titleBandHeight = 92;

/// The app bar for an Admin Portal section — pass it straight to
/// `Scaffold.appBar`.
///
/// On desktop width (the same [WindowSize.expanded] threshold that brings in
/// `AdminSidebarShell`'s sidebar) this is the portal's own header: a slim top
/// bar with the attention bell and the signed-in account, then a rounded Back
/// button and a large [title] over a soft mountain backdrop. Anywhere
/// narrower it's the plain [AppBar] these screens have always had, so the
/// phone layout (and the traveler app's in-app Admin Portal) is unchanged.
///
/// Back pops when there's something to pop and otherwise goes to [backTo] —
/// the sidebar opens sections with `go`, which leaves nothing on the stack.
/// [bottom] sits under the title on either layout (a `TabBar`, usually).
///
/// The desktop header can also carry a [subtitle] under the title, and an
/// [icon] tile that stands in for the Back button whenever there's nothing to
/// go back to (a section opened from the sidebar).
PreferredSizeWidget adminPageHeader(
  BuildContext context, {
  required String title,
  String? subtitle,
  IconData? icon,
  String backTo = RoutePaths.adminHome,
  PreferredSizeWidget? bottom,
}) {
  void back() => context.popOrGo(backTo);
  if (context.windowSize != WindowSize.expanded) {
    return AppBar(
      leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: back),
      title: Text(title),
      bottom: bottom,
    );
  }
  // Room for the title to grow at the larger Text Size settings.
  final bandHeight = context.textScaledHeight(_titleBandHeight, textLine: 36);
  return PreferredSize(
    preferredSize: Size.fromHeight(_topBarHeight + bandHeight + (bottom?.preferredSize.height ?? 0)),
    child: _AdminPageHeader(
      title: title,
      subtitle: subtitle,
      icon: Navigator.of(context).canPop() ? null : icon,
      onBack: back,
      bandHeight: bandHeight,
      bottom: bottom,
    ),
  );
}

/// [child]'s theme with the Admin Portal's violet standing in for the
/// traveler's accent color on desktop width, so every section's chips,
/// buttons, focused fields and tinted tags pick the violet up from
/// `Theme.of(context)` without each naming it. Wrapped around the whole
/// portal by `admin_router.dart`; below desktop width the theme is left
/// alone, same as [adminPageHeader].
class AdminPortalTheme extends StatelessWidget {
  const AdminPortalTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.windowSize != WindowSize.expanded) return child;
    final theme = Theme.of(context);
    final violet = adminVioletOf(context);
    // `AppTheme` bakes the accent into these component themes, so each is
    // re-pointed here; disabled states keep whatever they resolved to.
    WidgetStateProperty<Color?> enabled(WidgetStateProperty<Color?>? original, Color color) {
      return WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? original?.resolve(states) : color,
      );
    }

    final input = theme.inputDecorationTheme;
    final focused = input.focusedBorder;
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: violet,
          onPrimary: Colors.white,
          // What a floating action button fills with.
          primaryContainer: AppColors.adminViolet,
          onPrimaryContainer: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: theme.elevatedButtonTheme.style?.copyWith(
            backgroundColor: enabled(theme.elevatedButtonTheme.style?.backgroundColor, AppColors.adminViolet),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: theme.outlinedButtonTheme.style?.copyWith(
            foregroundColor: enabled(theme.outlinedButtonTheme.style?.foregroundColor, violet),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: theme.textButtonTheme.style?.copyWith(
            foregroundColor: enabled(theme.textButtonTheme.style?.foregroundColor, violet),
          ),
        ),
        inputDecorationTheme: input.copyWith(
          floatingLabelStyle: input.floatingLabelStyle?.copyWith(color: violet),
          focusedBorder: focused is OutlineInputBorder
              ? focused.copyWith(borderSide: focused.borderSide.copyWith(color: violet))
              : focused,
        ),
      ),
      child: child,
    );
  }
}

class _AdminPageHeader extends StatelessWidget {
  const _AdminPageHeader({
    required this.title,
    required this.onBack,
    required this.bandHeight,
    this.subtitle,
    this.icon,
    this.bottom,
  });

  final String title;
  final String? subtitle;

  /// Shown as a tinted tile in place of the Back button when set.
  final IconData? icon;
  final VoidCallback onBack;
  final double bandHeight;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final violet = adminVioletOf(context);
    final dark = theme.brightness == Brightness.dark;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Container(
            height: _topBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const _AttentionBell(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: SizedBox(height: 28, child: VerticalDivider(width: 1, color: theme.dividerColor)),
                ),
                const _AccountMenu(),
              ],
            ),
          ),
          SizedBox(
            height: bandHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: CustomPaint(painter: _MountainBackdropPainter(color: violet, strength: dark ? 0.6 : 1)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Row(
                    children: [
                      if (icon != null)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: violet.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          alignment: Alignment.center,
                          child: Icon(icon, fill: 1, color: violet),
                        )
                      else
                        Material(
                          color: dark ? theme.colorScheme.surface : Color.alphaBlend(violet.withValues(alpha: 0.08), Colors.white),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            onTap: onBack,
                            child: Tooltip(
                              message: MaterialLocalizations.of(context).backButtonTooltip,
                              child: SizedBox.square(
                                dimension: 48,
                                child: Icon(Symbols.arrow_back_rounded, color: theme.colorScheme.onSurface),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: AppSpacing.xl),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ?bottom,
        ],
      ),
    );
  }
}

/// One review queue the bell counts.
class _Queue {
  _Queue({required this.icon, required this.label, required this.path, required this.count});

  final IconData icon;
  final String label;
  final String path;
  final Stream<int> count;

  /// Null until the first count arrives (or if this account can't read it),
  /// shown as a dash rather than a misleading zero.
  int? waiting;
}

/// The bell in the top bar: a red dot while anything is waiting on this
/// account, and a menu of each review queue with its live count — the same
/// queues, role by role, the Overview's "Needs your attention" cards show.
class _AttentionBell extends StatefulWidget {
  const _AttentionBell();

  @override
  State<_AttentionBell> createState() => _AttentionBellState();
}

class _AttentionBellState extends State<_AttentionBell> {
  List<_Queue> _queues = const [];
  final List<StreamSubscription<int>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final uid = context.read<AuthProvider>().firebaseUser?.uid;
      if (uid == null) return;
      final admin = await AdminRepository().getById(uid);
      if (!mounted || admin == null || !admin.isActive) return;
      final isAdmin = admin.role == AdminRole.admin;
      final isLgu = admin.role == AdminRole.lgu;
      final queues = [
        if (isAdmin)
          _Queue(
            icon: Symbols.how_to_reg_rounded,
            label: 'Business applications',
            path: RoutePaths.adminBusinessOwnerApplications,
            count: BusinessOwnerApplicationRepository().streamPendingForAdmin().map((a) => a.length),
          ),
        if (isAdmin || isLgu)
          _Queue(
            icon: Symbols.storefront_rounded,
            label: 'Listings awaiting approval',
            path: RoutePaths.adminBusinesses,
            // Same province scoping an LGU account gets on the Businesses
            // screen itself.
            count: BusinessRepository().streamAllForAdmin(provinceId: isLgu ? admin.provinceId : null).map(
              (businesses) => businesses
                  .where(
                    (b) => b.isPending && (!isLgu || admin.provinceId == null || b.provinceId == admin.provinceId),
                  )
                  .length,
            ),
          ),
        if (isAdmin) ...[
          _Queue(
            icon: Symbols.flag_rounded,
            label: 'Reported reviews',
            path: RoutePaths.adminReportedReviews,
            count: ReviewReportRepository().streamAllForAdmin().map((r) => r.length),
          ),
          _Queue(
            icon: Symbols.report_rounded,
            label: 'Reported listings',
            path: RoutePaths.adminReportedReviews,
            count: ContentReportRepository().streamAllForAdmin().map((r) => r.length),
          ),
        ],
      ];
      setState(() => _queues = queues);
      for (final queue in queues) {
        _subscriptions.add(
          queue.count.listen(
            (count) {
              if (mounted) setState(() => queue.waiting = count);
            },
            // Left as a dash.
            onError: (_) {},
          ),
        );
      }
    } catch (_) {
      // No account or database to ask — the bell just links to the Overview.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _queues.fold<int>(0, (sum, queue) => sum + (queue.waiting ?? 0));
    final bell = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Symbols.notifications_rounded, color: theme.colorScheme.onSurface),
        if (total > 0)
          Positioned(
            top: -1,
            right: -1,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
                border: Border.all(color: theme.scaffoldBackgroundColor, width: 1.5),
              ),
            ),
          ),
      ],
    );
    if (_queues.isEmpty) {
      return IconButton(
        tooltip: 'Overview',
        onPressed: () => context.go(RoutePaths.adminHome),
        icon: bell,
      );
    }
    return PopupMenuButton<String>(
      tooltip: total > 0 ? 'Needs your attention ($total)' : 'Nothing waiting on you',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      onSelected: (path) => context.go(path),
      itemBuilder: (context) => [
        for (final queue in _queues)
          PopupMenuItem<String>(
            value: queue.path,
            child: Row(
              children: [
                Icon(queue.icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(queue.label)),
                const SizedBox(width: AppSpacing.md),
                Text(
                  queue.waiting?.toString() ?? '—',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
      icon: bell,
    );
  }
}

/// The signed-in account at the right of the top bar; opens a small menu
/// with who that is and Sign out.
class _AccountMenu extends StatefulWidget {
  const _AccountMenu();

  @override
  State<_AccountMenu> createState() => _AccountMenuState();
}

class _AccountMenuState extends State<_AccountMenu> {
  /// The account's Admin Portal record, once it has arrived. Only the role
  /// pill in the menu waits on it — who's signed in comes straight from the
  /// auth session, so the menu is there from the first frame and stays put
  /// if this lookup is slow or fails.
  AdminUser? _admin;
  StreamSubscription<AdminUser?>? _subscription;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _retry?.cancel();
    super.dispose();
  }

  void _listen() {
    try {
      final uid = context.read<AuthProvider>().firebaseUser?.uid;
      if (uid == null) return;
      _subscription = AdminRepository().streamSelf(uid).listen(
        (admin) {
          if (mounted) setState(() => _admin = admin);
        },
        // A failed listen ends the stream for good; keep what's showing and
        // try again shortly rather than going blank.
        onError: (_) {
          _subscription?.cancel();
          _retry = Timer(const Duration(seconds: 5), () {
            if (mounted) _listen();
          });
        },
      );
    } catch (_) {
      // No auth session or database to ask — the menu goes without a role.
    }
  }

  Future<void> _signOut() async {
    final signedOut = await confirmSignOut(context);
    if (signedOut && mounted) context.go(RoutePaths.login);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final admin = _admin;
    final user = context.watch<AuthProvider?>()?.firebaseUser;
    final String name;
    if (admin != null) {
      name = admin.name.isNotEmpty ? admin.name : admin.email;
    } else {
      final displayName = user?.displayName ?? '';
      name = displayName.isNotEmpty ? displayName : user?.email ?? '';
    }
    if (name.isEmpty) return const SizedBox.shrink();
    return Builder(
      builder: (context) {
        return PopupMenuButton<void>(
          tooltip: 'Account',
          position: PopupMenuPosition.under,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  if (admin != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    AdminRoleChip(admin: admin),
                  ],
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              onTap: _signOut,
              child: const Row(
                children: [
                  Icon(Symbols.logout_rounded, size: 20),
                  SizedBox(width: AppSpacing.sm),
                  Text('Sign out'),
                ],
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (admin != null)
                  AdminAvatar(admin: admin, radius: 18)
                else
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.adminVioletLight,
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                const SizedBox(width: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    name,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(Symbols.expand_more_rounded, size: 20, color: theme.colorScheme.onSurface),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Two soft ridgelines, a map pin and a pair of birds along the right of the
/// title band, fading out toward the title so it never sits behind text.
class _MountainBackdropPainter extends CustomPainter {
  const _MountainBackdropPainter({required this.color, required this.strength});

  final Color color;

  /// Scales every layer's opacity — turned down on a dark surface.
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final width = math.min(size.width * 0.62, 760.0);
    final left = size.width - width;
    final h = size.height;
    final area = Rect.fromLTWH(left, 0, width, h);
    double x(double t) => left + width * t;

    Paint fade(double alpha) => Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0), color.withValues(alpha: alpha * strength)],
        stops: const [0, 0.55],
      ).createShader(area);

    final far = Path()
      ..moveTo(x(0), h)
      ..quadraticBezierTo(x(0.14), h * 0.62, x(0.26), h * 0.50)
      ..quadraticBezierTo(x(0.32), h * 0.10, x(0.40), h * 0.42)
      ..quadraticBezierTo(x(0.50), h * 0.70, x(0.60), h * 0.46)
      ..quadraticBezierTo(x(0.70), h * 0.18, x(0.80), h * 0.44)
      ..quadraticBezierTo(x(0.90), h * 0.66, x(1), h * 0.52)
      ..lineTo(x(1), h)
      ..close();
    canvas.drawPath(far, fade(0.10));

    final near = Path()
      ..moveTo(x(0.18), h)
      ..quadraticBezierTo(x(0.36), h * 0.72, x(0.48), h * 0.80)
      ..quadraticBezierTo(x(0.62), h * 0.90, x(0.74), h * 0.66)
      ..quadraticBezierTo(x(0.86), h * 0.48, x(1), h * 0.76)
      ..lineTo(x(1), h)
      ..close();
    canvas.drawPath(near, fade(0.16));

    // Map pin: a circle head pinched to a point, with a pale center.
    final pin = Offset(x(0.86), h * 0.36);
    const r = 11.0;
    final pinPath = Path()
      ..addOval(Rect.fromCircle(center: pin, radius: r))
      ..moveTo(pin.dx - r * 0.82, pin.dy + r * 0.56)
      ..lineTo(pin.dx, pin.dy + r * 2.1)
      ..lineTo(pin.dx + r * 0.82, pin.dy + r * 0.56)
      ..close();
    canvas.drawPath(pinPath, Paint()..color = color.withValues(alpha: 0.55 * strength));
    canvas.drawCircle(pin, r * 0.38, Paint()..color = Colors.white.withValues(alpha: 0.85));

    final stroke = Paint()
      ..color = color.withValues(alpha: 0.35 * strength)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    void bird(Offset at, double span) {
      canvas.drawPath(
        Path()
          ..moveTo(at.dx - span, at.dy)
          ..quadraticBezierTo(at.dx - span * 0.4, at.dy - span * 0.5, at.dx, at.dy + span * 0.2)
          ..quadraticBezierTo(at.dx + span * 0.4, at.dy - span * 0.5, at.dx + span, at.dy),
        stroke,
      );
    }

    bird(Offset(x(0.50), h * 0.36), 9);
    bird(Offset(x(0.56), h * 0.20), 6);
  }

  @override
  bool shouldRepaint(_MountainBackdropPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strength != strength;
}
