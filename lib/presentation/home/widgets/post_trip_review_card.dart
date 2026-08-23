import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/routes/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/repositories/itinerary_repository.dart';
import '../../../data/repositories/review_repository.dart';
import '../../../domain/models/review.dart';
import '../../../domain/models/saved_itinerary.dart';

/// Nudges the traveler to review the destination of a trip that ended
/// recently and hasn't been reviewed yet — surfaced on Home the same way
/// [UpcomingTripSection] surfaces a trip still ahead, just for the other
/// side of the trip's lifecycle.
class PostTripReviewSection extends StatelessWidget {
  const PostTripReviewSection({super.key, required this.uid});

  final String? uid;

  /// How far back a trip's end date can be and still prompt a review —
  /// old enough that nagging about a years-old trip would feel stale, but
  /// long enough to catch someone opening the app again after getting home.
  static const _lookback = Duration(days: 30);

  /// Trips that actually ended (not still ahead/ongoing), have a single
  /// destination to review (whole-province trips have no `destinationId` —
  /// see [Itinerary.destinationId]'s doc comment), and ended within
  /// [_lookback] — most-recently-ended first, so the freshest trip wins if
  /// more than one qualifies.
  static List<SavedItinerary> _recentlyEnded(List<SavedItinerary> trips) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = today.subtract(_lookback);
    final ended = trips.where((t) {
      final destinationId = t.itinerary.destinationId;
      if (destinationId == null || destinationId.isEmpty) return false;
      final end = t.endDate;
      if (end == null) return false;
      final endDay = DateTime(end.year, end.month, end.day);
      return endDay.isBefore(today) && !endDay.isBefore(cutoff);
    }).toList()..sort((a, b) => b.endDate!.compareTo(a.endDate!));
    return ended;
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<List<SavedItinerary>>(
      stream: ItineraryRepository().streamForUser(uid!),
      builder: (context, tripSnapshot) {
        final candidates = _recentlyEnded(tripSnapshot.data ?? const []);
        if (candidates.isEmpty) return const SizedBox.shrink();

        return FutureBuilder<List<Review>>(
          // A one-shot fetch, not a stream — this is a low-priority nudge,
          // not something that needs to react live to a review written in
          // another tab; it's re-evaluated fresh every time Home rebuilds.
          future: ReviewRepository().getByUser(uid!),
          builder: (context, reviewSnapshot) {
            if (!reviewSnapshot.hasData) return const SizedBox.shrink();
            final reviewedIds = reviewSnapshot.data!
                .where((r) => r.targetType == ReviewTargetType.destination)
                .map((r) => r.targetId)
                .toSet();

            SavedItinerary? trip;
            for (final candidate in candidates) {
              if (!reviewedIds.contains(candidate.itinerary.destinationId)) {
                trip = candidate;
                break;
              }
            }
            if (trip == null) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: _ReviewNudgeCard(trip: trip),
            );
          },
        );
      },
    );
  }
}

class _ReviewNudgeCard extends StatelessWidget {
  const _ReviewNudgeCard({required this.trip});

  final SavedItinerary trip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push(
        RoutePaths.destinationDetails(trip.itinerary.destinationId!),
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: 44,
                height: 44,
                child: trip.itinerary.coverImageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: trip.itinerary.coverImageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            _fallbackIcon(theme),
                      )
                    : _fallbackIcon(theme),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How was ${trip.itinerary.destinationName}?',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Leave a review to help other travelers.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Symbols.chevron_right_rounded,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackIcon(ThemeData theme) {
    return Container(
      color: theme.colorScheme.primary.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Icon(
        Symbols.rate_review_rounded,
        size: 20,
        color: theme.colorScheme.primary,
      ),
    );
  }
}
