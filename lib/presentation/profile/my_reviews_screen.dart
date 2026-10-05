import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/back_navigation.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/indicators/rating_widget.dart';
import '../../core/widgets/details/business_info_sheet.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/business_repository.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/festival_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/review_repository.dart';
import '../../domain/models/business.dart';
import '../../domain/models/review.dart';
import '../../core/widgets/media/image_error_placeholder.dart';

/// What a [Review]'s [Review.targetId]/[Review.targetType] resolve to, for
/// display and navigation — [Review] itself only stores the id, not a
/// name/photo snapshot, so this is looked up fresh each time this screen
/// loads (see [_MyReviewsScreenState._resolveTargets]).
class _ReviewTarget {
  const _ReviewTarget({
    required this.name,
    required this.heroImageUrl,
    this.route = '',
    this.business,
  });

  final String name;
  final String heroImageUrl;

  /// Empty for a [business] target — there's no dedicated details route for
  /// a business listing (it only ever opens as a bottom sheet from Explore),
  /// so [_MyReviewCard] opens [business] via [showBusinessInfoSheet] instead
  /// of pushing a route.
  final String route;
  final Business? business;
}

/// One review paired with the (possibly missing, e.g. deleted since) target
/// it was written for.
class _ReviewWithTarget {
  const _ReviewWithTarget({required this.review, required this.target});

  final Review review;
  final _ReviewTarget? target;
}

/// Every review the signed-in traveler has written, across destinations,
/// restaurants and festivals — newest first, tap through to whatever it was
/// written for. Reached from the "Reviews" stat on [ProfileScreen].
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final ReviewRepository _reviewRepository = ReviewRepository();
  final DestinationRepository _destinationRepository = DestinationRepository();
  final RestaurantRepository _restaurantRepository = RestaurantRepository();
  final FestivalRepository _festivalRepository = FestivalRepository();
  final BusinessRepository _businessRepository = BusinessRepository();

  late Future<List<_ReviewWithTarget>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_ReviewWithTarget>> _load() async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return const [];
    final reviews = await _reviewRepository.getByUser(uid);
    final targets = await _resolveTargets(reviews);
    return reviews
        .map(
          (r) => _ReviewWithTarget(review: r, target: targets[_targetKey(r)]),
        )
        .toList();
  }

  String _targetKey(Review r) => '${r.targetType.name}|${r.targetId}';

  /// One batched [getByIds] call per target type instead of a lookup per
  /// review — a traveler with a dozen reviews on the same few places
  /// shouldn't cost a dozen separate reads.
  Future<Map<String, _ReviewTarget>> _resolveTargets(
    List<Review> reviews,
  ) async {
    final destinationIds = <String>{};
    final restaurantIds = <String>{};
    final festivalIds = <String>{};
    final businessIds = <String>{};
    for (final r in reviews) {
      switch (r.targetType) {
        case ReviewTargetType.destination:
          destinationIds.add(r.targetId);
        case ReviewTargetType.restaurant:
          restaurantIds.add(r.targetId);
        case ReviewTargetType.festival:
          festivalIds.add(r.targetId);
        case ReviewTargetType.business:
          businessIds.add(r.targetId);
      }
    }

    final results = await Future.wait([
      destinationIds.isEmpty
          ? Future.value(const [])
          : _destinationRepository.getByIds(destinationIds.toList()),
      restaurantIds.isEmpty
          ? Future.value(const [])
          : _restaurantRepository.getByIds(restaurantIds.toList()),
      festivalIds.isEmpty
          ? Future.value(const [])
          : _festivalRepository.getByIds(festivalIds.toList()),
      businessIds.isEmpty
          ? Future.value(const [])
          : _businessRepository.getByIds(businessIds.toList()),
    ]);

    final map = <String, _ReviewTarget>{};
    for (final d in results[0]) {
      map['${ReviewTargetType.destination.name}|${d.id}'] = _ReviewTarget(
        name: d.name,
        heroImageUrl: d.heroImageUrl,
        route: RoutePaths.destinationDetails(d.id),
      );
    }
    for (final r in results[1]) {
      map['${ReviewTargetType.restaurant.name}|${r.id}'] = _ReviewTarget(
        name: r.name,
        heroImageUrl: r.heroImageUrl,
        route: RoutePaths.restaurantDetails(r.id),
      );
    }
    for (final f in results[2]) {
      map['${ReviewTargetType.festival.name}|${f.id}'] = _ReviewTarget(
        name: f.name,
        heroImageUrl: f.heroImageUrl,
        route: RoutePaths.festivalDetails(f.id),
      );
    }
    for (final b in results[3]) {
      final business = b as Business;
      map['${ReviewTargetType.business.name}|${business.id}'] = _ReviewTarget(
        name: business.name,
        heroImageUrl: business.heroImageUrl,
        business: business,
      );
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.popOrGo(RoutePaths.profile),
        ),
        title: const Text('My Reviews'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final future = _load();
          setState(() => _future = future);
          try {
            await future;
          } catch (_) {
            // Surfaced by the FutureBuilder's error state below.
          }
        },
        child: FutureBuilder<List<_ReviewWithTarget>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return ListView(
                children: List.generate(4, (_) => LoadingWidget.cardBlock()),
              );
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  EmptyStateWidget(
                    icon: Symbols.error_outline_rounded,
                    title: 'Couldn\'t load your reviews',
                    message: AppException.from(snapshot.error!).message,
                    actionLabel: 'Retry',
                    onActionTap: () => setState(() => _future = _load()),
                  ),
                ],
              );
            }
            final entries = snapshot.data ?? const [];
            if (entries.isEmpty) {
              return ListView(
                children: const [
                  EmptyStateWidget(
                    icon: Symbols.rate_review_rounded,
                    title: 'No reviews yet',
                    message:
                        'Reviews you write for destinations, restaurants and festivals will show up here.',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.huge,
              ),
              itemCount: entries.length,
              separatorBuilder: (context, i) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) => _MyReviewCard(entry: entries[i]),
            );
          },
        ),
      ),
    );
  }
}

class _MyReviewCard extends StatelessWidget {
  const _MyReviewCard({required this.entry});

  final _ReviewWithTarget entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final review = entry.review;
    final target = entry.target;

    return InkWell(
      // Nothing to open when the target's since been unpublished/deleted —
      // the review itself still shows, just not tappable.
      onTap: target == null
          ? null
          : () => target.business != null
                ? showBusinessInfoSheet(context, target.business!)
                : context.push(target.route),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: 56,
                height: 56,
                child: target != null && target.heroImageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: target.heroImageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            const ImageErrorPlaceholder(),
                      )
                    : ColoredBox(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(
                          Symbols.image_not_supported_rounded,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          target?.name ?? 'No longer available',
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(review.date, style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  RatingWidget(rating: review.rating, starSize: 14),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    review.comment,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (review.isHidden) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(
                          Symbols.visibility_off_rounded,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Hidden by moderators — not shown to other travelers',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (review.hasOwnerReply) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.06,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Symbols.storefront_rounded,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Reply from the owner',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            review.ownerReply!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
