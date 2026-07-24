import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// The small circular glass button that floats over card images and hero
/// headers, letting a user toggle a saved/bookmarked state with a bounce.
class BookmarkButton extends StatelessWidget {
  const BookmarkButton({
    super.key,
    required this.isSaved,
    required this.onTap,
    this.size = 36,
    this.background,
  });

  final bool isSaved;
  final VoidCallback onTap;
  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background ?? Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: Icon(
              isSaved ? Symbols.bookmark_rounded : Symbols.bookmark_border_rounded,
              key: ValueKey(isSaved),
              color: isSaved ? const Color(0xFFF2C94C) : Colors.white,
              size: size * 0.52,
              fill: isSaved ? 1 : 0,
            ),
          ),
        ),
      ),
    );
  }
}
