import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_spacing.dart';

/// A compact star + numeric rating, with an optional review-count suffix.
///
/// Used inline in list rows and detail headers (not the floating badge that
/// sits on top of card images — see [RatingBadge] for that).
class RatingWidget extends StatelessWidget {
  const RatingWidget({
    super.key,
    required this.rating,
    this.reviewCount,
    this.starSize = 16,
    this.textStyle,
    this.starColor,
  });

  final double rating;
  final int? reviewCount;
  final double starSize;
  final TextStyle? textStyle;
  final Color? starColor;

  @override
  Widget build(BuildContext context) {
    final style = textStyle ?? Theme.of(context).textTheme.labelMedium;
    final resolvedStarColor = starColor ?? Theme.of(context).colorScheme.tertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Symbols.star_rounded, size: starSize, color: resolvedStarColor, fill: 1),
        const SizedBox(width: AppSpacing.xxs),
        Text(rating.toStringAsFixed(1), style: style?.copyWith(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700)),
        if (reviewCount != null) ...[
          const SizedBox(width: AppSpacing.xxs),
          Text('($reviewCount)', style: style),
        ],
      ],
    );
  }
}

/// The small floating pill that overlays a card image to show a rating,
/// e.g. "★ 4.8". Distinct from [RatingWidget], which is used inline in text.
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.star_rounded, size: 14, color: Theme.of(context).colorScheme.tertiary, fill: 1),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
