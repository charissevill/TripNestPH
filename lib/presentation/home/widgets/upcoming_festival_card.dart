import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/routes/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/repositories/festival_repository.dart';
import '../../../domain/models/festival.dart';

/// Fetches upcoming festivals independently of Home's main `_future` (same
/// self-contained pattern as [UpcomingTripData]/`PostTripReviewSection`)
/// and hands the nearest one with a structured [Festival.startDate] that
/// hasn't fully passed (or `null`) to [builder] — a data provider only, so
/// [HomeHighlightsRow] can decide whether it ends up full-width or
/// side-by-side with the trip card. Festivals saved with only a free-text
/// [Festival.dateLabel] (no [Festival.startDate]) are skipped — there's no
/// reliable day count to show for those.
class UpcomingFestivalData extends StatelessWidget {
  const UpcomingFestivalData({
    super.key,
    this.festivalRepository,
    required this.builder,
  });

  final FestivalRepository? festivalRepository;
  final Widget Function(BuildContext context, Festival? festival) builder;

  static Festival? nearest(List<Festival> festivals) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dated = festivals.where((f) {
      final start = f.startDate;
      if (start == null) return false;
      final end = f.endDate ?? start;
      final endDay = DateTime(end.year, end.month, end.day);
      return !endDay.isBefore(today);
    }).toList()..sort((a, b) => a.startDate!.compareTo(b.startDate!));
    return dated.isEmpty ? null : dated.first;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Festival>>(
      future: (festivalRepository ?? FestivalRepository()).getUpcoming(),
      builder: (context, snapshot) =>
          builder(context, nearest(snapshot.data ?? const [])),
    );
  }
}

/// The festival-countdown banner itself. Sized to look right both
/// full-width (only this card has content) and at half-width in
/// [HomeHighlightsRow]'s side-by-side row (both do), so text wraps up to
/// two lines instead of being clipped at a fixed single line.
class UpcomingFestivalCard extends StatelessWidget {
  const UpcomingFestivalCard({super.key, required this.festival});

  final Festival festival;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = festival.startDate!;
    final startDay = DateTime(start.year, start.month, start.day);
    final end = festival.endDate ?? start;
    final endDay = DateTime(end.year, end.month, end.day);
    final daysUntil = startDay.difference(today).inDays;

    // A countdown number only makes sense pre-event — "happening now"/the
    // (practically unreachable, see UpcomingFestivalData.nearest) past-end
    // fallback both fall back to a plain headline instead.
    final bool isCountdown = daysUntil > 0;
    final String eyebrow = isCountdown
        ? 'FESTIVAL'
        : !today.isAfter(endDay)
        ? 'HAPPENING NOW'
        : 'FESTIVAL';
    final String headline = isCountdown
        ? festival.name
        : !today.isAfter(endDay)
        ? '${festival.name} is on!'
        : festival.name;

    return InkWell(
      onTap: () => context.push(RoutePaths.festivalDetails(festival.id)),
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
            if (festival.heroImageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: festival.heroImageUrl,
                fit: BoxFit.cover,
              )
            else
              ColoredBox(
                color: theme.colorScheme.primary,
                child: Center(
                  child: Icon(
                    Symbols.celebration_rounded,
                    size: 40,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
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
                        Symbols.celebration_rounded,
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
