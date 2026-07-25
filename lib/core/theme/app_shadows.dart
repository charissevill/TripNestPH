import 'package:flutter/material.dart';

/// Shared elevation shadow(s) for surface cards that sit on the screen
/// background. Compose from here instead of hand-rolling BoxShadow per
/// widget, so every "card floats above the page" treatment reads the same.
class AppShadows {
  AppShadows._();

  /// Standard resting-state card shadow.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 14, offset: Offset(0, 6)),
  ];
}
