import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Shimmer skeleton loaders that mimic the shape of the real content so
/// screens never show a jarring blank frame while (mock) data "loads".
class LoadingWidget {
  LoadingWidget._();

  /// A single generic shimmering block, for screens whose content (e.g. a
  /// calendar grid) doesn't map cleanly onto any of the other shapes below —
  /// still shimmer-consistent with the rest of the app instead of a bare
  /// spinner, without a bespoke skeleton per one-off layout.
  static Widget block({double height = 300}) {
    return _shimmer(
      Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: _block(
          width: double.infinity,
          height: height,
          radius: AppRadius.lg,
        ),
      ),
    );
  }

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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
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
        child: _block(
          width: double.infinity,
          height: 190,
          radius: AppRadius.xl,
        ),
      ),
    );
  }

  /// A 2-column grid of [mediaCard]-shaped placeholders, matching the
  /// `crossAxisCount: 2` grids used across Explore/Saved/Nearby Places/
  /// Recently Viewed (card width comes from the grid itself, not a fixed
  /// value, so each cell fills its column).
  static Widget grid({int count = 6}) {
    return _shimmer(
      GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.huge,
        ),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.lg,
          mainAxisExtent: 140 + 92,
        ),
        itemCount: count,
        itemBuilder: (_, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _block(width: double.infinity, height: 140, radius: AppRadius.lg),
            const SizedBox(height: AppSpacing.sm),
            _block(width: double.infinity, height: 14, radius: 6),
            const SizedBox(height: AppSpacing.xxs),
            _block(width: 90, height: 12, radius: 6),
          ],
        ),
      ),
    );
  }

  /// A plain title+subtitle row with no leading thumbnail — matches the
  /// bare `ListTile`s used in the Admin Portal's province/festival/tourist
  /// spot lists. Set [leadingCircle] for rows that do have a small leading
  /// icon (e.g. the Team list) instead of a bare `ListTile`.
  static Widget textTile({bool leadingCircle = false}) {
    return _shimmer(
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            if (leadingCircle) ...[
              _block(width: 32, height: 32, radius: AppRadius.pill),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _block(width: double.infinity, height: 15, radius: 6),
                  const SizedBox(height: AppSpacing.xs),
                  _block(width: 140, height: 12, radius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A `Card`-shaped block of stacked text lines — matches the Admin
  /// Portal's business/reported-review rows (title, a couple of detail
  /// lines, no thumbnail).
  static Widget cardBlock() {
    return _shimmer(
      Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _block(width: 160, height: 15, radius: 6),
            const SizedBox(height: AppSpacing.sm),
            _block(width: double.infinity, height: 12, radius: 6),
            const SizedBox(height: AppSpacing.xs),
            _block(width: double.infinity, height: 12, radius: 6),
            const SizedBox(height: AppSpacing.xs),
            _block(width: 100, height: 12, radius: 6),
          ],
        ),
      ),
    );
  }

  /// Full-page skeleton for a Details screen: gallery image, title block,
  /// a row of stat cards, and a couple of paragraph placeholders — mirrors
  /// [TouristDetailsScreen]/[RestaurantDetailsScreen]/[FestivalDetailsScreen]/
  /// [ProvinceDetailsScreen]'s actual layout closely enough that the real
  /// content doesn't visibly "jump" once it swaps in.
  static Widget detailPage() {
    return _shimmer(
      SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _block(width: double.infinity, height: 260, radius: 0),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _block(width: 220, height: 22, radius: 6),
                  const SizedBox(height: AppSpacing.sm),
                  _block(width: 140, height: 14, radius: 6),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: _block(
                          width: double.infinity,
                          height: 64,
                          radius: AppRadius.md,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _block(
                          width: double.infinity,
                          height: 64,
                          radius: AppRadius.md,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _block(
                          width: double.infinity,
                          height: 64,
                          radius: AppRadius.md,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _block(width: 100, height: 16, radius: 6),
                  const SizedBox(height: AppSpacing.sm),
                  _block(width: double.infinity, height: 12, radius: 6),
                  const SizedBox(height: AppSpacing.xs),
                  _block(width: double.infinity, height: 12, radius: 6),
                  const SizedBox(height: AppSpacing.xs),
                  _block(width: 220, height: 12, radius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _block({
    required double width,
    required double height,
    required double radius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(radius),
      ),
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
