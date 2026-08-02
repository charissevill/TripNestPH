import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/festival.dart';
import '../../providers/favorites_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../buttons/bookmark_button.dart';
import '../indicators/rating_widget.dart';
import 'tag_chip.dart';
import 'travel_image_frame.dart';

/// Festival card with a distinctive date badge instead of the usual pin
/// location badge, used on Home's "Upcoming Festivals" carousel and Explore.
class FestivalCard extends StatelessWidget {
  const FestivalCard({
    super.key,
    required this.festival,
    required this.onTap,
    this.width = 220,
    this.imageHeight = 150,
  });

  final Festival festival;
  final VoidCallback onTap;
  final double width;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saved = context.watch<FavoritesProvider>();
    final isSaved = saved.isFestivalSaved(festival.id);
    final day = _dayLabel(festival);

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TravelImageFrame(
              imageUrl: festival.heroImageUrl,
              height: imageHeight,
              topLeft: _DateBadge(month: festival.month, day: day),
              topRight: BookmarkButton(isSaved: isSaved, onTap: () => saved.toggleFestival(festival.id)),
              bottomLeft: festival.isUpcoming ? TagChip(label: 'Upcoming', color: theme.colorScheme.primary) : null,
              bottomRight: RatingBadge(rating: festival.rating),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(festival.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              '${festival.provinceName} · ${festival.dateLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact day label for the date badge, e.g. "11-17" for a multi-day
/// festival or "15" for a single day. Prefers the structured [Festival.startDate]/
/// [Festival.endDate] fields when set; older festivals created before those
/// existed only have the formatted [Festival.dateLabel] string (e.g.
/// "January 11–17, 2027") to fall back on. The previous implementation
/// stripped every non-digit character from that string, which turned a
/// range like "11–17" into "1117" instead of "11-17".
String _dayLabel(Festival festival) {
  final start = festival.startDate;
  final end = festival.endDate;
  if (start != null) {
    return (end != null && end.day != start.day) ? '${start.day}-${end.day}' : '${start.day}';
  }
  // Split off the year first (dateLabel is "<month> <day range>, <year>")
  // so a lone day doesn't get paired with the year as a fake "day-year" range.
  final days = RegExp(r'\d+').allMatches(festival.dateLabel.split(',').first).map((m) => m.group(0)!).toList();
  return switch (days.length) {
    0 => '',
    1 => days[0],
    _ => '${days[0]}-${days[1]}',
  };
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.month, required this.day});

  final String month;
  final String day;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(month, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.error)),
          // A multi-day range (e.g. "22-24") is wider than the single-digit
          // day this badge was originally sized for — `FittedBox` shrinks it
          // to fit the fixed 42px width instead of wrapping/overflowing.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(day, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
