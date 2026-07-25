import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/favorites_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/cards/destination_card.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/itinerary_repository.dart';
import '../../data/repositories/review_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/admin_invite.dart';
import '../../domain/models/admin_user.dart';
import '../../domain/models/destination.dart';

/// Traveler profile: live stats, favorite destinations, travel preferences
/// and the entry point into account-level settings — all backed by
/// [AuthProvider] and Firestore.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileStats {
  const _ProfileStats({
    required this.placesVisited,
    required this.tripsPlanned,
    required this.reviewsWritten,
  });

  final int placesVisited;
  final int tripsPlanned;
  final int reviewsWritten;
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserRepository _userRepository = UserRepository();
  final ItineraryRepository _itineraryRepository = ItineraryRepository();
  final ReviewRepository _reviewRepository = ReviewRepository();
  final DestinationRepository _destinationRepository = DestinationRepository();

  Future<_ProfileStats>? _statsFuture;
  String? _statsUid;

  Future<_ProfileStats> _loadStats(String uid) async {
    final recentlyViewed = await _userRepository.recentlyViewedDestinations(
      uid,
      limit: 50,
    );
    final trips = await _itineraryRepository.streamForUser(uid).first;
    final reviews = await _reviewRepository.getByUser(uid);
    return _ProfileStats(
      placesVisited: recentlyViewed.length,
      tripsPlanned: trips.length,
      reviewsWritten: reviews.length,
    );
  }

  /// Force-reloads stats (bypassing the `uid != _statsUid` guard in
  /// [build], which only reloads on sign-in) and rebuilds so the inline
  /// favorites `FutureBuilder` below re-fetches too.
  Future<void> _refresh() async {
    final uid = _statsUid;
    if (uid == null) return;
    final future = _loadStats(uid);
    setState(() => _statsFuture = future);
    try {
      await future;
    } catch (_) {
      // Surfaced by the FutureBuilder's error state; RefreshIndicator just
      // needs this Future to complete either way.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final saved = context.watch<FavoritesProvider>();
    final user = auth.currentUser;
    final uid = auth.firebaseUser?.uid;

    if (uid != null && uid != _statsUid) {
      _statsUid = uid;
      _statsFuture = _loadStats(uid);
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.huge,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Profile',
                      style: theme.textTheme.displayMedium,
                    ),
                  ),
                  InkWell(
                    onTap: () => context.push(RoutePaths.settings),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Symbols.settings_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: AppColors.gradient(AppColors.oceanGradient),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipOval(
                        child: user?.photoUrl.isNotEmpty == true
                            ? CachedNetworkImage(
                                imageUrl: user!.photoUrl,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.white.withValues(alpha: 0.2),
                                child: const Icon(
                                  Symbols.person_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name.isNotEmpty == true
                                ? user!.name
                                : 'Traveler',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.createdAt != null
                                ? 'Member since ${DateFormat.yMMMM().format(user!.createdAt!)}'
                                : '',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _PendingInviteBanner(uid: uid, email: auth.firebaseUser?.email),
              FutureBuilder<_ProfileStats>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  final stats = snapshot.data;
                  return Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Symbols.location_on_rounded,
                          value: '${stats?.placesVisited ?? 0}',
                          label: 'Places',
                          onTap: () => context.push(RoutePaths.recentlyViewed),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatTile(
                          icon: Symbols.map_rounded,
                          value: '${stats?.tripsPlanned ?? 0}',
                          label: 'Trips',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatTile(
                          icon: Symbols.bookmark_rounded,
                          value: '${saved.totalSavedCount}',
                          label: 'Saved',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatTile(
                          icon: Symbols.reviews_rounded,
                          value: '${stats?.reviewsWritten ?? 0}',
                          label: 'Reviews',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Travel Preferences', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              if (user?.travelPreferences.isEmpty ?? true)
                Text(
                  'Add your travel preferences to get better recommendations.',
                  style: theme.textTheme.bodySmall,
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: user!.travelPreferences
                      .map(
                        (p) => Chip(
                          label: Text(p),
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.08,
                          ),
                          labelStyle: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.primary,
                          ),
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
              if (saved.savedDestinationIds.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Favorite Destinations',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 250,
                  child: FutureBuilder<List<Destination>>(
                    future: _destinationRepository.getByIds(
                      saved.savedDestinationIds.toList(),
                    ),
                    builder: (context, snapshot) {
                      final favorites = snapshot.data ?? const [];
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: favorites.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.md),
                        itemBuilder: (context, i) => DestinationCard(
                          destination: favorites[i],
                          onTap: () => context.push(
                            RoutePaths.destinationDetails(favorites[i].id),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              Text('Account', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              _MenuTile(
                icon: Symbols.person_rounded,
                label: 'Edit Profile',
                onTap: () => context.push(RoutePaths.editProfile),
              ),
              _MenuTile(
                icon: Symbols.map_rounded,
                label: 'My Trips',
                onTap: () => context.push(RoutePaths.savedItineraries),
              ),
              _MenuTile(
                icon: Symbols.notifications_rounded,
                label: 'Notifications',
                onTap: () => context.push(RoutePaths.notifications),
              ),
              _MenuTile(
                icon: Symbols.settings_rounded,
                label: 'Settings',
                onTap: () => context.push(RoutePaths.settings),
              ),
              _AdminPortalMenuTile(
                uid: context.watch<AuthProvider>().firebaseUser?.uid,
              ),
              _MenuTile(
                icon: Symbols.logout_rounded,
                label: 'Log Out',
                iconColor: AppColors.error,
                onTap: () => _confirmSignOut(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _confirmSignOut(BuildContext context) async {
  final confirmed = await showConfirmationDialog(
    context,
    title: 'Log out?',
    message: 'You can sign back in anytime with the same account.',
    confirmLabel: 'Log Out',
    isDestructive: true,
  );
  if (confirmed && context.mounted) {
    await context.read<AuthProvider>().signOut();
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 6),
            Text(value, style: theme.textTheme.titleLarge),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: iconColor ?? AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Symbols.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Checks for a role an admin has staged for this account's email (see
/// `AdminRepository.createInvite`) and, if one exists and this account
/// isn't already an Admin Portal member, offers an accept/decline prompt —
/// the self-service replacement for running `tool/create_admin.js` by hand.
class _PendingInviteBanner extends StatefulWidget {
  const _PendingInviteBanner({required this.uid, required this.email});

  final String? uid;
  final String? email;

  @override
  State<_PendingInviteBanner> createState() => _PendingInviteBannerState();
}

class _PendingInviteBannerState extends State<_PendingInviteBanner> {
  final AdminRepository _repository = AdminRepository();
  late Future<AdminInvite?> _future = _load();
  bool _busy = false;

  Future<AdminInvite?> _load() async {
    final uid = widget.uid;
    final email = widget.email;
    if (uid == null || email == null || email.isEmpty) return null;
    final existingAdmin = await _repository.getById(uid);
    if (existingAdmin != null) return null;
    return _repository.getPendingInvite(email);
  }

  Future<void> _accept(AdminInvite invite) async {
    final uid = widget.uid;
    if (uid == null) return;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Accept this role?',
      message:
          '${invite.invitedByName} invited you as "${invite.role}". You\'ll gain Admin Portal access with that role.',
      confirmLabel: 'Accept',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final name = context.read<AuthProvider>().currentUser?.name ?? '';
      await _repository.claimInvite(
        uid: uid,
        email: invite.email,
        role: invite.role,
        name: name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome to the Admin Portal.')),
        );
        setState(() {
          _future = _load();
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline(AdminInvite invite) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Decline this invite?',
      message: 'You can be invited again later if you change your mind.',
      confirmLabel: 'Decline',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repository.declineInvite(invite.email);
      if (mounted) {
        setState(() {
          _future = _load();
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminInvite?>(
      future: _future,
      builder: (context, snapshot) {
        final invite = snapshot.data;
        if (invite == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.xl),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Symbols.admin_panel_settings_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${invite.invitedByName} invited you to join the Admin Portal as "${invite.role}".',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  FilledButton(
                    onPressed: _busy ? null : () => _accept(invite),
                    child: const Text('Accept'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _decline(invite),
                    child: const Text('Decline'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Only renders once an active `admin_users` doc exists for [uid] — the
/// gate that makes the whole Admin Portal invisible/unreachable to every
/// ordinary traveler, matching `firestore.rules`'s own gating on the data
/// side. Renders nothing while loading/absent rather than a placeholder,
/// since "no admin access" should look identical to "menu item doesn't
/// exist" for a traveler account.
class _AdminPortalMenuTile extends StatelessWidget {
  const _AdminPortalMenuTile({required this.uid});

  final String? uid;

  @override
  Widget build(BuildContext context) {
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<AdminUser?>(
      stream: AdminRepository().streamSelf(uid!),
      builder: (context, snapshot) {
        final admin = snapshot.data;
        if (admin == null || !admin.isActive) return const SizedBox.shrink();
        return _MenuTile(
          icon: Symbols.admin_panel_settings_rounded,
          label: 'Admin Portal',
          onTap: () => context.push(RoutePaths.adminHome),
        );
      },
    );
  }
}
