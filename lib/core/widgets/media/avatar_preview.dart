import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Wraps an avatar with an Instagram-style "hold to preview" gesture: long
/// pressing shows the full-size photo over a dimmed backdrop, and releasing
/// (or dragging away) dismisses it immediately — no separate tap-to-open or
/// tap-to-close step. No-ops when there's no photo to preview.
class AvatarPreview extends StatefulWidget {
  const AvatarPreview({super.key, required this.photoUrl, required this.child});

  final String? photoUrl;
  final Widget child;

  @override
  State<AvatarPreview> createState() => _AvatarPreviewState();
}

class _AvatarPreviewState extends State<AvatarPreview> {
  OverlayEntry? _entry;

  void _show() {
    final url = widget.photoUrl;
    if (url == null || url.isEmpty) return;
    _entry = OverlayEntry(
      builder: (context) => _AvatarPreviewOverlay(photoUrl: url),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _show(),
      onLongPressEnd: (_) => _hide(),
      onLongPressCancel: _hide,
      child: widget.child,
    );
  }
}

class _AvatarPreviewOverlay extends StatelessWidget {
  const _AvatarPreviewOverlay({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).shortestSide * 0.7;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: 1,
          duration: const Duration(milliseconds: 150),
          child: Container(
            color: Colors.black.withValues(alpha: 0.75),
            alignment: Alignment.center,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: ClipOval(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
