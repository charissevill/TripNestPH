import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Shimmer skeleton loaders that mimic the shape of the real content so
/// screens never show a jarring blank frame while (mock) data "loads".
class LoadingWidget {
  LoadingWidget._();

  /// A skeleton matching [DestinationCard]/[RestaurantCard] proportions.
  static Widget mediaCard({double width = 210}) {
    return _shimmer(
      Container(
        width: width,
        margin: const EdgeInsets.only(right: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _block(width: width, height: 150, radius: AppRadius.lg),
            const SizedBox(height: AppSpacing.sm),
            _block(width: width * 0.7, height: 14, radius: 6),
            const SizedBox(height: AppSpacing.xxs),
            _block(width: width * 0.45, height: 12, radius: 6),
          ],
        ),
      ),
    );
  }

  static Widget carousel({int count = 3, double itemWidth = 210}) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: count,
        itemBuilder: (_, _) => mediaCard(width: itemWidth),
      ),
    );
  }

  static Widget listRow() {
    return _shimmer(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: Row(
          children: [
            _block(width: 72, height: 72, radius: AppRadius.md),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _block(width: double.infinity, height: 14, radius: 6),
                  const SizedBox(height: AppSpacing.xs),
                  _block(width: 120, height: 12, radius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget heroBanner() {
    return _shimmer(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: _block(width: double.infinity, height: 190, radius: AppRadius.xl),
      ),
    );
  }

  static Widget _block({required double width, required double height, required double radius}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: AppColors.shimmerBase, borderRadius: BorderRadius.circular(radius)),
    );
  }

  static Widget _shimmer(Widget child) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}
