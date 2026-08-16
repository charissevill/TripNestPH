import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../theme/app_spacing.dart';
import '../../utils/auto_advance_gallery_mixin.dart';
import '../buttons/bookmark_button.dart';

/// The shared sticky-header gallery used by all three Details screens
/// (Tourist, Restaurant, Festival): a swipeable photo gallery that collapses
/// into a solid app bar with a title as the user scrolls, plus floating
/// back / share / bookmark buttons that stay legible over any photo.
class DetailsGalleryAppBar extends StatefulWidget {
  const DetailsGalleryAppBar({
    super.key,
    required this.imageUrls,
    required this.title,
    this.isSaved,
    this.onToggleSaved,
    required this.onShare,
    this.onEmergency,
    this.heroTag,
    this.expandedHeight = 340,
  });

  final List<String> imageUrls;
  final String title;

  /// Null on a listing with no bookmark concept (provinces) — the bookmark
  /// button is hidden entirely rather than shown disabled.
  final bool? isSaved;
  final VoidCallback? onToggleSaved;
  final VoidCallback onShare;

  /// Opens [showEmergencyAccessSheet] — null hides the button entirely (a
  /// listing whose province couldn't be resolved at all, not just one with
  /// no hotlines on file; the sheet itself already has a nationwide
  /// fallback for that case).
  final VoidCallback? onEmergency;
  final Object? heroTag;
  final double expandedHeight;

  @override
  State<DetailsGalleryAppBar> createState() => _DetailsGalleryAppBarState();
}

class _DetailsGalleryAppBarState extends State<DetailsGalleryAppBar> with AutoAdvanceGalleryMixin {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    startAutoAdvance(_pageController, widget.imageUrls.length);
  }

  @override
  void dispose() {
    stopAutoAdvance();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: widget.expandedHeight,
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      leadingWidth: 68,
      leading: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        child: _CircleIconButton(icon: Symbols.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop()),
      ),
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        if (widget.onEmergency != null) ...[
          _CircleIconButton(icon: Symbols.emergency_rounded, onTap: widget.onEmergency!),
          const SizedBox(width: AppSpacing.sm),
        ],
        _CircleIconButton(icon: Symbols.ios_share_rounded, onTap: widget.onShare),
        if (widget.isSaved != null && widget.onToggleSaved != null) ...[
          const SizedBox(width: AppSpacing.sm),
          BookmarkButton(isSaved: widget.isSaved!, onTap: widget.onToggleSaved!, background: Colors.black.withValues(alpha: 0.35)),
        ],
        const SizedBox(width: AppSpacing.md),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Stack(
          fit: StackFit.expand,
          children: [
            // An admin-added listing with no photos yet used to render a
            // blank hero header here — province_details_screen.dart already
            // has a tinted fallback for exactly this case; this mirrors the
            // simple (non-live-photo) half of it, since the other three
            // Details screens share this one widget.
            if (widget.imageUrls.isEmpty)
              Container(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                alignment: Alignment.center,
                child: Icon(
                  Symbols.image_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                ),
              )
            else
              PageView.builder(
                controller: _pageController,
                itemCount: widget.imageUrls.length,
                itemBuilder: (context, index) {
                  final image = CachedNetworkImage(imageUrl: widget.imageUrls[index], fit: BoxFit.cover);
                  return index == 0 && widget.heroTag != null ? Hero(tag: widget.heroTag!, child: image) : image;
                },
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.55, 1],
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
                    ),
                  ),
                ),
              ),
            ),
            if (widget.imageUrls.length > 1)
              Positioned(
                bottom: AppSpacing.md,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: SmoothPageIndicator(
                      controller: _pageController,
                      count: widget.imageUrls.length,
                      effect: WormEffect(
                        dotHeight: 6,
                        dotWidth: 6,
                        spacing: 6,
                        activeDotColor: Colors.white,
                        dotColor: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
