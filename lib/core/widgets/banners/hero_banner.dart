import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Content for a single slide of the [HeroBanner] carousel.
class HeroBannerItem {
  const HeroBannerItem({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onTap,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onTap;
}

/// The large auto-advancing hero carousel shown at the top of Home, with a
/// gradient scrim, headline copy, a CTA chip and a smooth page indicator.
class HeroBanner extends StatefulWidget {
  const HeroBanner({super.key, required this.items, this.height = 210});

  final List<HeroBannerItem> items;
  final double height;

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  late final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `SmoothPageIndicator`'s `WormPainter` divides by the dot count when
    // laying itself out — with zero items that's a division by zero
    // (Infinity/NaN), which crashes on paint. An empty carousel (e.g. a
    // Places API hiccup returning no results) should just render nothing.
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            itemBuilder: (context, index) => _HeroSlide(item: widget.items[index]),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SmoothPageIndicator(
          controller: _controller,
          count: widget.items.length,
          effect: WormEffect(
            dotHeight: 6,
            dotWidth: 6,
            spacing: 6,
            activeDotColor: theme.colorScheme.primary,
            dotColor: AppColors.border,
          ),
          onDotClicked: (index) => _controller.animateToPage(
            index,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          ),
        ),
      ],
    );
  }
}

class _HeroSlide extends StatelessWidget {
  const _HeroSlide({required this.item});

  final HeroBannerItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.05), Colors.black.withValues(alpha: 0.68)],
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  GestureDetector(
                    onTap: item.onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.ctaLabel,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 4),
                          Icon(Symbols.arrow_forward_rounded, size: 15, color: theme.colorScheme.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
