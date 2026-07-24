import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../domain/models/place.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../indicators/rating_widget.dart';
import 'tag_chip.dart';
import 'travel_image_frame.dart';

/// A live Places API result, styled to match [DestinationCard]/
/// [RestaurantCard] so Places-sourced content looks native to the app
/// rather than bolted on. [imageUrl] is resolved by the caller (via
/// `PlacesService.photoUrl`) rather than built here, keeping this widget a
/// plain presentational card with no service dependency.
class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.place,
    required this.imageUrl,
    required this.onTap,
    this.width = 220,
    this.imageHeight = 160,
  });

  final Place place;
  final String imageUrl;
  final VoidCallback onTap;
  final double width;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TravelImageFrame(
              imageUrl: imageUrl,
              height: imageHeight,
              topLeft: TagChip(label: place.categoryLabel, color: AppColors.primary),
              bottomLeft: place.distanceMeters != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Symbols.near_me_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 2),
                        Text(_distanceLabel(place.distanceMeters!), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    )
                  : null,
              bottomRight: place.rating != null ? RatingBadge(rating: place.rating!) : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Row(
              children: [
                if (place.userRatingCount != null) ...[
                  Text('${place.userRatingCount} reviews', style: theme.textTheme.bodySmall),
                ],
                if (place.userRatingCount != null && place.priceLevelLabel.isNotEmpty)
                  Text(' · ', style: theme.textTheme.bodySmall),
                if (place.priceLevelLabel.isNotEmpty)
                  Text(place.priceLevelLabel, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _distanceLabel(double meters) {
    if (meters < 1000) return '${meters.round()} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }
}
