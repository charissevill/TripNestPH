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
    final parts = festival.dateLabel.split(' ');
    final day = parts.length > 1 ? parts[1].replaceAll(RegExp(r'[^0-9]'), '') : '';

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
              bottomLeft: festival.isUpcoming ? const TagChip(label: 'Upcoming', color: AppColors.primary) : null,
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
          Text(month, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.error)),
          Text(day, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
