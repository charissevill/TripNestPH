import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/place.dart';
import '../../providers/favorites_provider.dart';
import '../../theme/app_spacing.dart';
import '../buttons/bookmark_button.dart';
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
    final saved = context.watch<FavoritesProvider>();

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
              topLeft: TagChip(label: place.categoryLabel, color: theme.colorScheme.primary),
              // Signals "live web result" vs. an in-app catalog listing, same
              // reasoning as `_SearchResultTile`'s globe icon in search_screen.dart.
              topRight: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                child: const Icon(
                  Symbols.public_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
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
              bottomRight: BookmarkButton(
                isSaved: saved.isPlaceSaved(place.id),
                onTap: () => saved.togglePlace(place),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
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
