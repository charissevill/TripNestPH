import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/app_spacing.dart';
import '../../theme/breakpoints.dart';

/// Centers and caps [child] at [maxWidth] once the screen is wide enough to
/// need it — a plain no-op (returns [child] unchanged) below
/// [Breakpoints.compact], so this can never alter the existing mobile
/// layout. Use this widget directly only when a screen body has no single
/// shared padding site to substitute [sidePadding] into instead (a flat
/// `Column` of independent siblings, e.g. AI Chat's message list + input
/// bar) — everywhere else, prefer [sidePadding] as a drop-in replacement
/// for an existing `AppSpacing.lg` gutter literal.
class MaxWidthContainer extends StatelessWidget {
  const MaxWidthContainer({super.key, required this.child, this.maxWidth = 1200});

  final Widget child;
  final double maxWidth;

  /// The horizontal inset needed on each side to center [maxWidth] of
  /// content within the current screen — `math.max` against [minPadding]
  /// means this is provably identical to a bare `AppSpacing.lg` literal
  /// below [Breakpoints.compact], and correctly grows above it.
  static double sidePadding(
    BuildContext context, {
    required double maxWidth,
    double minPadding = AppSpacing.lg,
  }) {
    final width = context.screenWidth;
    return math.max(minPadding, (width - maxWidth) / 2);
  }

  @override
  Widget build(BuildContext context) {
    if (context.isCompact) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
