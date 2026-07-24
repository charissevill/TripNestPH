import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/destination.dart';
import '../../providers/favorites_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../buttons/bookmark_button.dart';
import '../indicators/rating_widget.dart';
import 'tag_chip.dart';
import 'travel_image_frame.dart';

/// The primary destination card used across Home carousels, Explore grids
/// and Search results: large image, gradient overlay, location badge,
/// rating badge and a working bookmark toggle.
class DestinationCard extends StatelessWidget {
  const DestinationCard({
    super.key,
    required this.destination,
    required this.onTap,
    this.width = 220,
    this.imageHeight = 160,
  });

  final Destination destination;
  final VoidCallback onTap;
  final double width;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saved = context.watch<FavoritesProvider>();
    final isSaved = saved.isDestinationSaved(destination.id);

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TravelImageFrame(
              imageUrl: destination.heroImageUrl,
              height: imageHeight,
              topLeft: destination.isHiddenGem
                  ? const TagChip(label: 'Hidden Gem', color: AppColors.secondary)
                  : null,
              topRight: BookmarkButton(
                isSaved: isSaved,
                onTap: () => saved.toggleDestination(destination.id),
              ),
              bottomLeft: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Symbols.location_on_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 2),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: width - 70),
                    child: Text(
                      destination.provinceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              bottomRight: RatingBadge(rating: destination.rating),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              destination.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              destination.shortDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
