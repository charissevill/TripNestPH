import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/details/business_info_sheet.dart';
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
/// listing (status, what's still missing from it, views/rating/reviews/
/// favorites, and what travelers are saying) plus a shortcut into the full
/// editor, rather than the traveler Home feed's destination browsing, which
/// has nothing to do with running a business. Explore and AI Planner stay
/// the traveler versions for this role — an owner is still a traveler who
/// might want to browse or plan a trip themselves, unlike Home's
/// browsing-focused feed, which this dashboard is a more useful use of
/// screen real estate than.
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
    // Same target a traveler's favorite/review lands on (the `restaurants`
    // mirror for Food & Dining, the business doc itself otherwise) — so
    // every category gets the full set of stats, not just Views.
    final (favoriteType, reviewTargetType, targetId) =
        businessFavoriteAndReviewTarget(business);
    // Only a restaurant-targeted review can be replied to (see the
    // `reviews` update rule in firestore.rules), and that page is also the
    // only public listing page there is to link to.
    final hasPublicPage = reviewTargetType == ReviewTargetType.restaurant;
    void openPublicPage() =>
        context.push(RoutePaths.restaurantDetails(targetId));
    final statusNote = switch (business.status) {
      'pending' =>
        'Your listing is being reviewed. Travelers will see it once it\'s approved.',
      'suspended' =>
        'Your listing is hidden from travelers. Open Manage Listing to contact support.',
      _ => null,
    };

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
        const SizedBox(height: 2),
        Text(
          [
            BusinessCategory.label(business.category),
            if (business.provinceName.isNotEmpty) business.provinceName,
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
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
        if (statusNote != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            statusNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _ListingStrengthCard(
          business: business,
          onTap: () => context.go(RoutePaths.saved),
        ),
        StreamBuilder<List<Review>>(
          stream: ReviewRepository().streamForTarget(targetId, reviewTargetType),
          builder: (context, snapshot) {
            final reviews = snapshot.data ?? const <Review>[];
            final rating = reviews.isEmpty
                ? 0.0
                : reviews.map((r) => r.rating).reduce((a, b) => a + b) /
                      reviews.length;
            final unanswered = hasPublicPage
                ? reviews.where((r) => !r.hasOwnerReply).length
                : 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        value: reviews.isEmpty
                            ? '—'
                            : rating.toStringAsFixed(1),
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
                      child: _FavoritedStat(
                        // A fresh count whenever the target changes (a
                        // Food & Dining listing only gets its restaurant
                        // mirror on first approval).
                        key: ValueKey('${favoriteType.name}:$targetId'),
                        type: favoriteType,
                        itemId: targetId,
                      ),
                    ),
                  ],
                ),
                if (unanswered > 0) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _ActionCard(
                    icon: Symbols.reply_rounded,
                    color: AppColors.warning,
                    title: unanswered == 1
                        ? '1 review is waiting for your reply'
                        : '$unanswered reviews are waiting for your reply',
                    subtitle:
                        'Replying shows travelers you\'re listening.',
                    onTap: openPublicPage,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'What travelers are saying',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (reviews.isEmpty)
                  Text(
                    business.isApproved
                        ? 'No reviews yet. They\'ll show up here as soon as a traveler leaves one.'
                        : 'Reviews will show up here once your listing is live.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else ...[
                  _RatingBreakdownCard(reviews: reviews, average: rating),
                  for (final review in reviews.take(3)) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _ReviewCard(
                      review: review,
                      needsReply: hasPublicPage && !review.hasOwnerReply,
                      onTap: hasPublicPage ? openPublicPage : null,
                    ),
                  ],
                ],
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.go(RoutePaths.saved),
            icon: const Icon(Symbols.edit_rounded, size: 18),
            label: const Text('Manage Listing'),
          ),
        ),
        if (hasPublicPage && business.isApproved) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: openPublicPage,
              icon: const Icon(Symbols.open_in_new_rounded, size: 18),
              label: const Text('View Public Page'),
            ),
          ),
        ],
      ],
    );
  }
}

/// What a traveler would want to see on the listing, and whether the owner
/// has filled it in yet — the catalog entry is worded per category, same
/// vocabulary as `MyBusinessScreen`'s own section labels.
List<(String, bool)> _listingChecks(Business business) {
  final catalogLabel = switch (business.category) {
    BusinessCategory.foodAndDining => 'Menu items',
    BusinessCategory.accommodation => 'Room types',
    BusinessCategory.tourOperator => 'Tour packages',
    BusinessCategory.shop => 'Products',
    BusinessCategory.transport => 'Services',
    _ => 'Items you offer',
  };
  return [
    ('Cover photo', business.heroImageUrl.isNotEmpty),
    ('Description', business.description.trim().isNotEmpty),
    ('Address', business.address.trim().isNotEmpty),
    ('Map pin', business.hasCoordinates),
    ('Contact number', business.contactNumber.trim().isNotEmpty),
    // Only Food & Dining listings have opening hours at all.
    if (business.isFoodAndDining)
      ('Opening hours', business.openingHours.isNotEmpty),
    (catalogLabel, business.menuItems.isNotEmpty),
  ];
}

/// Nudges the owner toward a complete listing — renders nothing (not even
/// its own bottom spacing) once every check passes.
class _ListingStrengthCard extends StatelessWidget {
  const _ListingStrengthCard({required this.business, required this.onTap});

  final Business business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checks = _listingChecks(business);
    final missing = [
      for (final (label, done) in checks)
        if (!done) label,
    ];
    if (missing.isEmpty) return const SizedBox.shrink();
    final doneCount = checks.length - missing.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Complete your listing',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      '$doneCount of ${checks.length}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: doneCount / checks.length,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Complete listings get more attention from travelers. Still missing:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final label in missing)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Symbols.radio_button_unchecked_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            label,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
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

/// How many travelers have saved this listing. Holds its own future so the
/// count isn't re-fetched (and the card doesn't flash back to "—") every
/// time the surrounding review stream rebuilds.
class _FavoritedStat extends StatefulWidget {
  const _FavoritedStat({super.key, required this.type, required this.itemId});

  final FavoriteType type;
  final String itemId;

  @override
  State<_FavoritedStat> createState() => _FavoritedStatState();
}

class _FavoritedStatState extends State<_FavoritedStat> {
  late final Future<int> _count = FavoritesRepository().countForItem(
    widget.type,
    widget.itemId,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _count,
      builder: (context, snapshot) => _StatCard(
        icon: Symbols.favorite_rounded,
        label: 'Favorited',
        value: snapshot.hasData ? '${snapshot.data}' : '—',
        color: AppColors.error,
      ),
    );
  }
}

/// A single tappable "something needs you" row.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Symbols.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The average alongside how many reviews landed on each star — one bad
/// week reads very differently from a steady 3.
class _RatingBreakdownCard extends StatelessWidget {
  const _RatingBreakdownCard({required this.reviews, required this.average});

  final List<Review> reviews;
  final double average;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <int, int>{};
    for (final review in reviews) {
      final stars = review.rating.round().clamp(1, 5);
      counts[stars] = (counts[stars] ?? 0) + 1;
    }
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
      child: Row(
        children: [
          Column(
            children: [
              Text(
                average.toStringAsFixed(1),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                reviews.length == 1 ? '1 review' : '${reviews.length} reviews',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              children: [
                for (var stars = 5; stars >= 1; stars--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text('$stars', style: theme.textTheme.labelSmall),
                        const SizedBox(width: 2),
                        const Icon(
                          Symbols.star_rounded,
                          size: 12,
                          color: AppColors.accentDark,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadius.pill,
                            ),
                            child: LinearProgressIndicator(
                              value: (counts[stars] ?? 0) / reviews.length,
                              minHeight: 6,
                              color: AppColors.accentDark,
                              backgroundColor: theme.colorScheme.outline
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        SizedBox(
                          width: 20,
                          child: Text(
                            '${counts[stars] ?? 0}',
                            textAlign: TextAlign.end,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One recent traveler review, shown right on the dashboard — an owner
/// otherwise has to go find it themselves on the public restaurant page to
/// see what people are actually saying.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.needsReply,
    this.onTap,
  });

  final Review review;
  final bool needsReply;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      review.authorName,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
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
              const SizedBox(height: 2),
              Text(
                review.date,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
              if (needsReply) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Needs reply',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
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
