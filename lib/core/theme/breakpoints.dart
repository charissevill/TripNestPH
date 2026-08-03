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
