import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Width thresholds for the responsive (web/desktop) layout — deliberately
/// above Material 3's own compact/medium/expanded cutoffs (600/840) so the
/// switch to a side nav / extra grid columns only happens once there's
/// genuinely comfortable room, not in an awkward, cramped in-between width.
class Breakpoints {
  Breakpoints._();

  static const double compact = 700;
  static const double expanded = 1100;
}

enum WindowSize { compact, medium, expanded }

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  WindowSize get windowSize {
    final width = screenWidth;
    if (width < Breakpoints.compact) return WindowSize.compact;
    if (width < Breakpoints.expanded) return WindowSize.medium;
    return WindowSize.expanded;
  }

  bool get isCompact => windowSize == WindowSize.compact;

  /// A fixed-height strip's height, grown by however much its tallest text
  /// line ([textLine], in logical px at 1x) grows at the current Text Size —
  /// unchanged at the default size, but Large / Extra Large no longer clip
  /// or overflow the label inside a strip sized only for 1x text.
  double textScaledHeight(double base, {required double textLine}) {
    final grown = MediaQuery.textScalerOf(this).scale(textLine) - textLine;
    return grown > 0 ? base + grown : base;
  }

  /// A collapsing header's expanded height, capped to a share of the viewport
  /// height — a fixed 340px hero would otherwise fill an entire landscape
  /// phone (320-390px tall) and push the actual content off the first screen.
  /// Unchanged whenever the viewport is tall enough for [preferred].
  double heroHeight(double preferred, {double maxFraction = 0.55}) =>
      math.min(preferred, MediaQuery.sizeOf(this).height * maxFraction);

  /// True once there's room for a persistent side nav instead of a bottom bar.
  bool get useSideNav => windowSize != WindowSize.compact;

  /// Card-grid column count for Explore/Saved — 2 on phones, 3 once there's
  /// a side nav, 4 on a full desktop-width window.
  int get gridColumns => switch (windowSize) {
    WindowSize.compact => 2,
    WindowSize.medium => 3,
    WindowSize.expanded => 4,
  };
}
