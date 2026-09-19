import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/favorites_repository.dart';
import '../../../domain/models/business.dart';
import '../../providers/favorites_provider.dart';
import '../../theme/app_spacing.dart';
import '../buttons/bookmark_button.dart';
import '../details/business_info_sheet.dart';
import 'tag_chip.dart';
import 'travel_image_frame.dart';

/// A [BusinessCategory] listing card for Explore's "Local Finds" tab and
/// [SavedScreen]'s matching tab — same image-card shape as
/// [RestaurantCard]/[FestivalCard] (so it sits in the same grid
/// consistently), including the same top-right [BookmarkButton] (not a
/// heart — this app's saved/bookmark icon is consistent everywhere, the
/// info sheet's heart from the first pass was the inconsistent one and has
/// since been switched to match). No rating badge here (the bottom-sheet
/// detail view is where a live review average shows — see
/// [showBusinessInfoSheet]). Tapping the card opens the full listing via
/// [showBusinessInfoSheet], same as [ProvinceDetailsScreen]'s own business
/// tile; tapping the bookmark toggles [FavoritesProvider] via
/// [businessFavoriteAndReviewTarget], same routing the info sheet's own
/// bookmark uses (a linked food business's favorite lives on its
/// restaurant mirror, not the raw business doc).
class BusinessCard extends StatelessWidget {
  const BusinessCard({
    super.key,
    required this.business,
    required this.onTap,
    this.width = 220,
    this.imageHeight = 160,
  });

  final Business business;
  final VoidCallback onTap;
  final double width;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (favoriteType, _, targetId) = businessFavoriteAndReviewTarget(
      business,
    );
    final saved = context.watch<FavoritesProvider>();
    final isSaved = favoriteType == FavoriteType.restaurant
        ? saved.isRestaurantSaved(targetId)
        : saved.isBusinessSaved(targetId);

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TravelImageFrame(
              imageUrl: business.heroImageUrl,
              height: imageHeight,
              emptyIcon: Symbols.storefront_rounded,
              topLeft: TagChip(
                label: BusinessCategory.label(business.category),
                color: theme.colorScheme.primary,
              ),
              topRight: BookmarkButton(
                isSaved: isSaved,
                onTap: () => favoriteType == FavoriteType.restaurant
                    ? saved.toggleRestaurant(targetId)
                    : saved.toggleBusiness(targetId),
              ),
              bottomLeft: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Symbols.location_on_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      business.provinceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              business.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              business.isFoodAndDining
                  ? '${business.cuisine.isNotEmpty ? business.cuisine : 'Food & Dining'} · ${business.priceRange}'
                  : business.address.isNotEmpty
                  ? business.address
                  : BusinessCategory.label(business.category),
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
