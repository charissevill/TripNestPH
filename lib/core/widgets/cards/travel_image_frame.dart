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
    this.assetFallback,
  });

  final String imageUrl;
  final double height;
  final Widget? topLeft;
  final Widget? topRight;
  final Widget? bottomLeft;
  final Widget? bottomRight;
  final double borderRadius;
  final Object? heroTag;

  /// When set and [imageUrl] is empty (and [assetFallback] isn't set),
  /// skips the network image entirely and renders this icon directly
  /// instead — lets callers with no photo (e.g. a live Places result with
  /// no `photoUrl`) pick a fallback that fits their content (hotel vs.
  /// landmark) rather than always showing a generic broken-image glyph.
  final IconData? emptyIcon;

  /// When set and [imageUrl] is empty, takes priority over [emptyIcon] —
  /// a real bundled cover photo (e.g. `FestivalCard`'s
  /// `festival_default_cover.jpg`) reads as a finished card instead of a
  /// placeholder, for content types common enough to warrant one.
  final String? assetFallback;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (imageUrl.isEmpty && assetFallback != null) {
      image = Image.asset(assetFallback!, fit: BoxFit.cover);
    } else if (imageUrl.isEmpty && emptyIcon != null) {
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
        // A broken/expired URL is "no visible photo" the same as an empty
        // one — falls back the same way rather than only handling the
        // empty-string case.
        errorWidget: (context, _, _) => assetFallback != null
            ? Image.asset(assetFallback!, fit: BoxFit.cover)
            : Container(
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
            if (topLeft != null || topRight != null)
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                child: _BadgeRow(start: topLeft, end: topRight, alignment: CrossAxisAlignment.start),
              ),
            if (bottomLeft != null || bottomRight != null)
              Positioned(
                bottom: AppSpacing.sm,
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                child: _BadgeRow(start: bottomLeft, end: bottomRight, alignment: CrossAxisAlignment.end),
              ),
          ],
        ),
      ),
    );
  }
}

/// One edge of badges over the image. [end] keeps its natural size pinned to
/// the far edge and [start] gets whatever width is left (so it can shrink or
/// wrap) — two independently positioned badges would instead slide over one
/// another on a narrow card or at a large text size.
class _BadgeRow extends StatelessWidget {
  const _BadgeRow({this.start, this.end, required this.alignment});

  final Widget? start;
  final Widget? end;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: alignment,
      children: [
        Expanded(
          child: start == null
              ? const SizedBox.shrink()
              : Align(alignment: Alignment.centerLeft, heightFactor: 1, child: start),
        ),
        if (start != null && end != null) const SizedBox(width: AppSpacing.xs),
        ?end,
      ],
    );
  }
}
