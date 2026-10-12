import 'package:flutter/material.dart';

/// Facebook-style swipe navigation for a tabbed body that isn't a
/// [TabBarView] — e.g. Explore, whose tab content lives inside one shared
/// page scroll (see `ExploreScreen.build`), so a [TabBarView] (which needs a
/// bounded height of its own) can't be dropped in there. Swiping left moves
/// to the next tab, right to the previous one (mirrored under RTL, same as
/// [TabBarView]); the caller's own tab state stays the single source of
/// truth, so the selected tab, its indicator and the content all update
/// together through [onIndexChanged], exactly as if the tab were tapped.
///
/// Built so it never steals gestures it shouldn't:
/// - Only a *horizontal* drag recognizer is added, so vertical scrolling
///   wins the gesture arena whenever the drag starts out vertical.
/// - Nested horizontal scrollables (carousels, chip rows) sit deeper in the
///   tree and claim the drag first, as they would inside a [TabBarView].
/// - Taps, long-presses and form fields are untouched — a drag only wins
///   once it moves past the touch slop.
/// - Drag devices follow the ambient [ScrollConfiguration], so a mouse
///   click-drag on web/desktop doesn't flip tabs (same as scrollables).
/// - Swiping past the first/last tab does nothing here: the content doesn't
///   move and no callback fires. If another [SwipeTabSwitcher] encloses this
///   one (the bottom-nav one around Explore's own tabs), that swipe is
///   handed up to it instead, so the outer tabs take over at either end.
class SwipeTabSwitcher extends StatefulWidget {
  const SwipeTabSwitcher({
    super.key,
    required this.index,
    required this.length,
    required this.onIndexChanged,
    required this.child,
  });

  /// The currently selected tab.
  final int index;

  /// Total number of tabs.
  final int length;

  /// Called with `index ± 1` once a swipe commits — never outside
  /// `0..length-1`.
  final ValueChanged<int> onIndexChanged;

  final Widget child;

  @override
  State<SwipeTabSwitcher> createState() => _SwipeTabSwitcherState();
}

class _SwipeTabSwitcherState extends State<SwipeTabSwitcher>
    with SingleTickerProviderStateMixin {
  /// A swipe commits once it travels this fraction of the width...
  static const double _distanceThreshold = 0.25;

  /// ...or is flung at least this fast (logical px/s) in the same direction.
  static const double _velocityThreshold = 400;

  /// How far the content visibly follows the finger relative to the actual
  /// drag — enough to feel attached, without exposing the empty space where
  /// the neighbouring tab (not built here) would be.
  static const double _followFactor = 0.4;

  /// Unbounded — its value *is* the content's horizontal offset in px.
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );
  double _dragDx = 0;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  bool get _isRtl => Directionality.of(context) == TextDirection.rtl;

  /// The tab a drag of sign [dx] leads to, or null past either end.
  int? _targetFor(double dx) {
    if (dx == 0) return null;
    // A leftward drag (dx < 0) means "next" in LTR, "previous" in RTL.
    final step = (dx < 0) != _isRtl ? 1 : -1;
    final target = widget.index + step;
    return target >= 0 && target < widget.length ? target : null;
  }

  void _onDragStart(DragStartDetails _) {
    _offset.stop();
    _dragDx = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragDx += details.primaryDelta ?? 0;
    // Nothing to swipe to in this direction — stay put rather than hint at
    // a tab that doesn't exist.
    _offset.value = _targetFor(_dragDx) == null ? 0 : _dragDx * _followFactor;
  }

  void _onDragEnd(DragEndDetails details) {
    final width = context.size?.width ?? 0;
    final velocity = details.primaryVelocity ?? 0;
    final flung =
        velocity.abs() >= _velocityThreshold &&
        velocity.sign == _dragDx.sign;
    final farEnough =
        width > 0 &&
        _dragDx.abs() >= width * _distanceThreshold &&
        // A drag that's past the threshold but being flung back the other
        // way is the user changing their mind.
        !(velocity.abs() >= _velocityThreshold &&
            velocity.sign != _dragDx.sign);
    if (!flung && !farEnough) {
      _settle();
      return;
    }
    final dx = _dragDx;
    if (_targetFor(dx) == null) {
      // Nothing further this way in our own tabs — see the class doc.
      context.findAncestorStateOfType<_SwipeTabSwitcherState>()?._commit(dx);
      _settle();
      return;
    }
    _commit(dx);
  }

  /// Switches to the tab a committed swipe of sign [dx] leads to (a no-op
  /// past either end) and slides its content in.
  void _commit(double dx) {
    final target = _targetFor(dx);
    if (target == null) return;
    final width = context.size?.width ?? 0;
    widget.onIndexChanged(target);
    // Slide the new tab's content in from the side the swipe came from.
    _offset.value = -dx.sign * width * _followFactor * 0.5;
    _settle();
  }

  void _settle() {
    _dragDx = 0;
    _offset.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Translucent so a swipe that starts in the gaps between cards still
      // registers, without blocking hits on the cards themselves.
      behavior: HitTestBehavior.translucent,
      supportedDevices: ScrollConfiguration.of(context).dragDevices,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: _settle,
      child: AnimatedBuilder(
        animation: _offset,
        child: widget.child,
        // Same widget shape at rest and mid-drag — swapping wrappers in and
        // out would remount [child] and drop its state (scroll positions,
        // in-flight FutureBuilders) on every swipe.
        builder: (context, child) {
          final dx = _offset.value;
          return ClipRect(
            clipBehavior: dx == 0 ? Clip.none : Clip.hardEdge,
            child: Transform.translate(offset: Offset(dx, 0), child: child),
          );
        },
      ),
    );
  }
}
