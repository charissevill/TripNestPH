import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/routes/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/repositories/itinerary_repository.dart';
import '../../../domain/models/saved_itinerary.dart';

/// Streams the signed-in traveler's trips and hands the nearest one whose
/// start date hasn't fully passed yet (or `null`, if none qualify) to
/// [builder] — a data provider only, so [HomeHighlightsRow] can decide
/// whether it ends up full-width or side-by-side with the festival card.
class UpcomingTripData extends StatelessWidget {
  const UpcomingTripData({super.key, required this.uid, required this.builder});

  final String? uid;
  final Widget Function(BuildContext context, SavedItinerary? trip) builder;

  /// The soonest trip that's either still ahead or currently underway —
  /// a trip whose last day has already passed is never worth surfacing
  /// here, even though it's still visible in Saved Trips.
  static SavedItinerary? nearestRelevant(List<SavedItinerary> trips) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dated = trips.where((t) {
      final start = t.startDate;
      if (start == null) return false;
      final end = t.endDate ?? start;
      final endDay = DateTime(end.year, end.month, end.day);
      return !endDay.isBefore(today);
    }).toList()..sort((a, b) => a.startDate!.compareTo(b.startDate!));
    return dated.isEmpty ? null : dated.first;
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) return builder(context, null);
    return StreamBuilder<List<SavedItinerary>>(
      stream: ItineraryRepository().streamForUser(uid!),
      builder: (context, snapshot) =>
          builder(context, nearestRelevant(snapshot.data ?? const [])),
    );
  }
}

/// The trip-countdown banner itself — a cover-image card with a "days
/// until"/"happening now" headline. Sized to look right both full-width
/// (only this card has content) and at half-width in [HomeHighlightsRow]'s
/// side-by-side row (both do), so text wraps up to two lines instead of
/// being clipped at a fixed single line.
class UpcomingTripCard extends StatelessWidget {
  const UpcomingTripCard({super.key, required this.trip});

  final SavedItinerary trip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = trip.startDate!;
    final startDay = DateTime(start.year, start.month, start.day);
    final end = trip.endDate ?? start;
    final endDay = DateTime(end.year, end.month, end.day);
    final daysUntil = startDay.difference(today).inDays;
    final destination = trip.itinerary.destinationName;

    // A countdown number only makes sense pre-trip — "happening now"/the
    // past-end fallback both fall back to a plain headline instead (same
    // reasoning as UpcomingFestivalCard).
    final bool isCountdown = daysUntil > 0;
    final String eyebrow = isCountdown
        ? 'TRIP'
        : !today.isAfter(endDay)
        ? 'HAPPENING NOW'
        : 'TRIP';
    final String headline = !isCountdown && !today.isAfter(endDay)
        ? 'Your $destination trip is on!'
        : 'Your $destination trip';

    return InkWell(
      onTap: () => context.push(
        RoutePaths.generatedItinerary,
        extra: {'itinerary': trip.itinerary, 'savedId': trip.id},
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        height: 150,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (trip.itinerary.coverImageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: trip.itinerary.coverImageUrl,
                fit: BoxFit.cover,
              )
            else
              ColoredBox(color: theme.colorScheme.primary),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Symbols.flight_takeoff_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          eyebrow,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isCountdown) ...[
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$daysUntil',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            daysUntil == 1 ? 'day to go' : 'days to go',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
