import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_colors.dart';

/// Neutral stand-in for a network image that failed to load (broken/expired
/// URL, offline with nothing cached). Pass as a `CachedNetworkImage`'s
/// `errorWidget` so a failed photo reads as an intentional placeholder
/// instead of an empty gap. Sized to fill whatever space the image would have
/// occupied unless [width]/[height] are given.
class ImageErrorPlaceholder extends StatelessWidget {
  const ImageErrorPlaceholder({
    super.key,
    this.width,
    this.height,
    this.icon = Symbols.image_not_supported_rounded,
  });

  final double? width;
  final double? height;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.shimmerBase,
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shortest = [constraints.maxWidth, constraints.maxHeight].where((v) => v.isFinite).fold<double>(double.infinity, (a, b) => b < a ? b : a);
          final size = shortest.isFinite ? (shortest * 0.4).clamp(16.0, 36.0) : 28.0;
          return Icon(icon, size: size, color: Theme.of(context).colorScheme.onSurfaceVariant);
        },
      ),
    );
  }
}
