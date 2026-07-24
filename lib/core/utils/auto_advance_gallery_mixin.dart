import 'dart:async';

import 'package:flutter/widgets.dart';

/// Adds a simple auto-advancing slideshow behavior to any `PageView`-backed
/// photo gallery: call [startAutoAdvance] once a [PageController] and item
/// count are known (typically `initState`), and [stopAutoAdvance] in
/// `dispose`. Loops back to the first page after the last, and is a no-op
/// for a single-image gallery — nothing to advance to.
///
/// Deliberately simple: each tick reads the controller's *current* page
/// live rather than tracking its own index, so a manual swipe never fights
/// with the timer — the next auto-advance just continues from wherever the
/// traveler left it.
mixin AutoAdvanceGalleryMixin<T extends StatefulWidget> on State<T> {
  Timer? _autoAdvanceTimer;

  void startAutoAdvance(PageController controller, int itemCount, {Duration interval = const Duration(seconds: 4)}) {
    stopAutoAdvance();
    if (itemCount <= 1) return;
    _autoAdvanceTimer = Timer.periodic(interval, (_) {
      if (!mounted || !controller.hasClients) return;
      final next = ((controller.page?.round() ?? 0) + 1) % itemCount;
      controller.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  void stopAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
  }
}
