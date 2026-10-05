import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The one behavior every in-app Back button shares, so it always matches
/// the device/browser back button instead of drifting from it.
extension BackNavigation on BuildContext {
  /// Goes back to the previous screen, or to [fallbackLocation] when there
  /// isn't one.
  ///
  /// Uses `maybePop` rather than `context.pop()` on purpose: `context.pop()`
  /// skips the current route's `PopScope`, so a Back arrow silently threw
  /// away exactly the unsaved changes `DiscardChangesScope` (and the
  /// unsaved-itinerary guard) exist to protect, while the system back
  /// button on the same screen asked first.
  ///
  /// The fallback covers a screen that's the only route on its navigator —
  /// a web refresh or deep link, or an Admin Portal section opened from the
  /// desktop sidebar (which navigates with `go`). There, `context.pop()`
  /// throws "There is nothing to pop" and `maybePop` does nothing at all.
  void popOrGo(String fallbackLocation) {
    final navigator = Navigator.of(this);
    if (navigator.canPop()) {
      navigator.maybePop();
    } else {
      go(fallbackLocation);
    }
  }
}
