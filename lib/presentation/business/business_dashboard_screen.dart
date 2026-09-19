import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/business_repository.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/review_repository.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/business.dart';
import '../../domain/models/review.dart';
import '../home/widgets/home_header.dart';
import '../../core/widgets/media/image_error_placeholder.dart';

/// The Home tab's content for an active `businessOwner` account (see
/// `HomeOrBusinessDashboardTab`) — a quick-glance recap of the owner's own
/// listing (status, views, and for an approved Food & Dining listing,
/// rating/reviews/favorites) plus a shortcut into the full editor, rather
/// than the traveler Home feed's destination browsing, which has nothing to
/// do with running a business. Explore and AI Planner stay the traveler
/// versions for this role — an owner is still a traveler who might want to
/// browse or plan a trip themselves, unlike Home's browsing-focused feed,
/// which this dashboard is a more useful use of screen real estate than.
class BusinessDashboardScreen extends StatelessWidget {
  const BusinessDashboardScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().currentUser;
    return SafeArea(
      child: StreamBuilder<List<Business>>(
        stream: BusinessRepository().streamForOwner(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return LoadingWidget.block(height: 300);
          }
          final businesses = snapshot.data ?? const [];
          final business = businesses.isEmpty ? null : businesses.first;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.huge,
            ),
            children: [
              // Same greeting/avatar/notification-bell header the traveler
              // Home feed uses — an owner is still signed in as one person
              // with one profile and one notification inbox, so this stays
              // just as relevant here as it is there.
              StreamBuilder<List<AppNotification>>(
                stream: NotificationRepository().streamForUser(uid),
                builder: (context, notifSnapshot) {
                  final hasUnread = (notifSnapshot.data ?? const []).any(
                    (n) => !n.isRead,
                  );
                  return HomeHeader(
                    userName: user?.name.isNotEmpty == true
                        ? user!.name.split(' ').first
                        : 'Owner',
                    avatarUrl: user?.photoUrl ?? '',
                    onAvatarTap: () => context.go(RoutePaths.profile),
                    onBellTap: () => context.push(RoutePaths.notifications),
                    hasUnreadNotifications: hasUnread,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Dashboard', style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                business == null
                    ? 'Set up your business listing to get started.'
                    : 'Here\'s how your listing is doing.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (business == null)
                _EmptyDashboardCard(onSetup: () => context.go(RoutePaths.saved))
              else
                _DashboardContent(business: business),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyDashboardCard extends StatelessWidget {
  const _EmptyDashboardCard({required this.onSetup});

  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Symbols.storefront_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('No listing yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Add your business details, photo and menu so travelers can find you.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onSetup,
            icon: const Icon(Symbols.add_rounded, size: 18),
            label: const Text('Set Up My Business'),
          ),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canShowReviewStats =
        business.isFoodAndDining && business.restaurantId.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: business.heroImageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: business.heroImageUrl,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) =>
                      const ImageErrorPlaceholder(
                        width: double.infinity,
                        height: 160,
                      ),
                )
              : Container(
                  width: double.infinity,
                  height: 160,
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(
                    Symbols.storefront_rounded,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        _StatusPill(status: business.status),
        const SizedBox(height: AppSpacing.sm),
        Text(business.name, style: theme.textTheme.titleLarge),
        if (business.isRejected && business.rejectionReason.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              business.rejectionReason,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (!canShowReviewStats)
          _StatCard(
            icon: Symbols.visibility_rounded,
            label: 'Views',
            value: '${business.viewCount}',
            color: AppColors.primary,
          )
        else
          StreamBuilder<List<Review>>(
            stream: ReviewRepository().streamForTarget(
              business.restaurantId,
              ReviewTargetType.restaurant,
            ),
            builder: (context, snapshot) {
              final reviews = snapshot.data ?? const <Review>[];
              final rating = reviews.isEmpty
                  ? 0.0
                  : reviews.map((r) => r.rating).reduce((a, b) => a + b) /
                        reviews.length;
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Symbols.visibility_rounded,
                          label: 'Views',
                          value: '${business.viewCount}',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatCard(
                          icon: Symbols.star_rounded,
                          label: 'Rating',
                          value: rating.toStringAsFixed(1),
                          color: AppColors.accentDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Symbols.reviews_rounded,
                          label: 'Reviews',
                          value: '${reviews.length}',
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FutureBuilder<int>(
                          future: FavoritesRepository().countForItem(
                            FavoriteType.restaurant,
                            business.restaurantId,
                          ),
                          builder: (context, favSnapshot) => _StatCard(
                            icon: Symbols.favorite_rounded,
                            label: 'Favorited',
                            value: favSnapshot.hasData
                                ? '${favSnapshot.data}'
                                : '—',
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (reviews.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _LatestReviewCard(review: reviews.first),
                  ],
                ],
              );
            },
          ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: () => context.go(RoutePaths.saved),
          icon: const Icon(Symbols.edit_rounded, size: 18),
          label: const Text('Manage Listing'),
        ),
      ],
    );
  }
}

/// The most recent traveler review, shown right on the dashboard — an
/// owner otherwise has to go find it themselves on the public restaurant
/// page to see what people are actually saying.
class _LatestReviewCard extends StatelessWidget {
  const _LatestReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest Review',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  review.authorName,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Symbols.star_rounded,
                    size: 16,
                    color: AppColors.accentDark,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    review.rating.toStringAsFixed(1),
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              review.comment,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'approved' => (AppColors.success, 'Live'),
      'rejected' => (AppColors.error, 'Rejected'),
      'suspended' => (AppColors.error, 'Suspended'),
      _ => (AppColors.warning, 'Pending Review'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
