import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/restaurant.dart';
import '../../providers/favorites_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../buttons/bookmark_button.dart';
import '../indicators/rating_widget.dart';
import 'tag_chip.dart';
import 'travel_image_frame.dart';

/// Restaurant card used on Home carousels, Explore, and "Nearby Restaurants"
/// sections inside details screens.
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
    this.width = 220,
    this.imageHeight = 150,
  });

  final Restaurant restaurant;
  final VoidCallback onTap;
  final double width;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saved = context.watch<FavoritesProvider>();
    final isSaved = saved.isRestaurantSaved(restaurant.id);

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TravelImageFrame(
              imageUrl: restaurant.heroImageUrl,
              height: imageHeight,
              topLeft: (restaurant.businessId.isNotEmpty || restaurant.isPopular)
                  ? Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (restaurant.businessId.isNotEmpty)
                          const TagChip(label: 'Verified Partner', color: AppColors.primary),
                        if (restaurant.isPopular)
                          const TagChip(label: 'Popular', color: AppColors.accentDark),
                      ],
                    )
                  : null,
              topRight: BookmarkButton(isSaved: isSaved, onTap: () => saved.toggleRestaurant(restaurant.id)),
              bottomLeft: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Symbols.location_on_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 2),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: width - 70),
                    child: Text(
                      restaurant.provinceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              bottomRight: RatingBadge(rating: restaurant.rating),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(restaurant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              '${restaurant.cuisine} · ${restaurant.priceRange}',
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
