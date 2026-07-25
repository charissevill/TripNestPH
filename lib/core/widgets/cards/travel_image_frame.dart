import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// The shared "large image + gradient scrim + floating badges" chrome used
/// by [DestinationCard], [RestaurantCard] and [FestivalCard] so every media
/// card in the app looks and behaves consistently.
class TravelImageFrame extends StatelessWidget {
  const TravelImageFrame({
    super.key,
    required this.imageUrl,
    required this.height,
    this.topLeft,
    this.topRight,
    this.bottomLeft,
    this.bottomRight,
    this.borderRadius = AppRadius.lg,
    this.heroTag,
    this.emptyIcon,
  });

  final String imageUrl;
  final double height;
  final Widget? topLeft;
  final Widget? topRight;
  final Widget? bottomLeft;
  final Widget? bottomRight;
  final double borderRadius;
  final Object? heroTag;

  /// When set and [imageUrl] is empty, skips the network image entirely and
  /// renders this icon directly instead — lets callers with no photo (e.g. a
  /// live Places result with no `photoUrl`) pick a fallback that fits their
  /// content (hotel vs. landmark) rather than always showing a generic
  /// broken-image glyph.
  final IconData? emptyIcon;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (imageUrl.isEmpty && emptyIcon != null) {
      image = Container(
        color: AppColors.shimmerBase,
        alignment: Alignment.center,
        child: Icon(emptyIcon, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 32),
      );
    } else {
      image = CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 280),
        placeholder: (context, _) => Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Container(color: AppColors.shimmerBase),
        ),
        errorWidget: (context, _, _) => Container(
          color: AppColors.shimmerBase,
          alignment: Alignment.center,
          child: Icon(emptyIcon ?? Symbols.image_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 32),
        ),
      );
    }

    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: AppColors.imageScrim,
                  ),
                ),
              ),
            ),
            if (topLeft != null) Positioned(top: AppSpacing.sm, left: AppSpacing.sm, child: topLeft!),
            if (topRight != null) Positioned(top: AppSpacing.sm, right: AppSpacing.sm, child: topRight!),
            if (bottomLeft != null) Positioned(bottom: AppSpacing.sm, left: AppSpacing.sm, child: bottomLeft!),
            if (bottomRight != null) Positioned(bottom: AppSpacing.sm, right: AppSpacing.sm, child: bottomRight!),
          ],
        ),
      ),
    );
  }
}
