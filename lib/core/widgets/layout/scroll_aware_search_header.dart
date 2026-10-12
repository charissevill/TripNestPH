import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

/// Shared timing for both search-header variants below, so the bar slides
/// the same way on every screen.
const Duration _showDuration = Duration(milliseconds: 250);
const Duration _hideDuration = Duration(milliseconds: 200);
const Curve _showCurve = Curves.easeOutCubic;
const Curve _hideCurve = Curves.easeInCubic;

/// Facebook-style search area for a screen whose search bar (plus any
/// filter/sort controls that go with it) sits *above* a separately
/// scrolling [body] — the usual `Column(header, Expanded(list))` shape.
///
/// Scrolling the body down slides [header] up out of the way; scrolling
/// back up (or reaching the top) slides it back in. [header] is never
/// rebuilt or removed while hidden — it's only clipped to zero height — so
/// typed text, controllers, dropdown values and chip selections all survive.
///
/// Built so it doesn't fight the rest of the screen:
/// - Only *vertical* scrolling counts, so horizontal chip rows, carousels
///   and swipe gestures inside [body] never toggle it.
/// - Small direction changes are ignored ([_hideAfter]/[_showAfter]), so it
///   doesn't flicker on a jittery drag.
/// - It won't hide unless the body can still scroll once the header is
///   gone, so a list that only barely overflows can't trap it hidden.
/// - It stays put while the user is typing in it (focus + soft keyboard
///   open); when it does hide, it drops any focus inside it so an invisible
///   field can't keep receiving keystrokes or show an autocomplete overlay.
/// - It comes back on its own whenever the body's list is replaced by a
///   fresh one or by a non-scrolling state (empty/error/loading), since
///   there'd otherwise be nothing left to scroll up on to reveal it.
class CollapsibleSearchHeader extends StatefulWidget {
  const CollapsibleSearchHeader({
    super.key,
    required this.header,
    required this.body,
    this.enabled = true,
  });

  /// The search bar and the controls that belong with it.
  final Widget header;

  /// The scrolling content. Laid out like an `Expanded` child.
  final Widget body;

  /// When false the header is always shown — lets a screen keep the same
  /// widget tree (so [header]'s state is preserved) in a mode that has no
  /// search bar to collapse.
  final bool enabled;

  @override
  State<CollapsibleSearchHeader> createState() =>
      _CollapsibleSearchHeaderState();
}

class _CollapsibleSearchHeaderState extends State<CollapsibleSearchHeader>
    with SingleTickerProviderStateMixin {
  /// Downward travel before the header hides.
  static const double _hideAfter = 24;

  /// Upward travel before it comes back — smaller, so it's quick to reach.
  static const double _showAfter = 12;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _showDuration,
    reverseDuration: _hideDuration,
    value: 1,
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: _showCurve,
    reverseCurve: _hideCurve,
  );
  final FocusNode _headerFocus = FocusNode(
    debugLabel: 'CollapsibleSearchHeader',
    canRequestFocus: false,
    skipTraversal: true,
  );
  final GlobalKey _headerKey = GlobalKey();

  bool _shown = true;

  /// Scroll distance accumulated in the current direction (+ down, − up).
  double _travel = 0;

  /// The vertical scrollable the body last reported from — used to notice
  /// when it's been swapped out (see [didUpdateWidget]).
  BuildContext? _scrollContext;

  @override
  void didUpdateWidget(CollapsibleSearchHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _show();
      return;
    }
    if (_shown) return;
    // The parent rebuilt (new results, a filter, a loading state...). If
    // that replaced the list we were tracking, a new list starts at its
    // top and a non-scrolling state can't be scrolled at all — either way
    // the header belongs back on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scrollContext = _scrollContext;
      if (scrollContext == null || !scrollContext.mounted) _show();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _headerFocus.dispose();
    super.dispose();
  }

  double get _headerHeight => _headerKey.currentContext?.size?.height ?? 0;

  void _show() {
    _travel = 0;
    if (_shown) return;
    _shown = true;
    _controller.forward();
  }

  void _hide() {
    _travel = 0;
    if (!_shown) return;
    if (_headerFocus.hasFocus) {
      // Mid-typing with the keyboard up — leave the field where it is.
      if (View.of(context).viewInsets.bottom > 0) return;
      FocusManager.instance.primaryFocus?.unfocus();
    }
    _shown = false;
    _controller.reverse();
  }

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (!widget.enabled || metrics.axis != Axis.vertical) return false;
    _scrollContext = notification.context;
    if (notification is! ScrollUpdateNotification) return false;

    if (metrics.pixels <= metrics.minScrollExtent) {
      _show();
      return false;
    }
    final delta = notification.scrollDelta ?? 0;
    // Overscroll bounce-back at the bottom reads as "scrolling up" — ignore
    // it so the header doesn't pop in every time a list hits its end.
    if (delta == 0 || metrics.outOfRange) return false;

    if (delta.sign != _travel.sign) _travel = 0;
    _travel += delta;
    if (_travel >= _hideAfter) {
      final scrollRange = metrics.maxScrollExtent - metrics.minScrollExtent;
      if (scrollRange > _headerHeight + _hideAfter) _hide();
    } else if (_travel <= -_showAfter) {
      _show();
    }
    return false;
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    final metrics = notification.metrics;
    if (!widget.enabled || metrics.axis != Axis.vertical) return false;
    _scrollContext = notification.context;
    // Content changed underneath (filtered down, refreshed, a new list) and
    // left nothing above the viewport to scroll back up through.
    if (metrics.pixels <= metrics.minScrollExtent ||
        metrics.maxScrollExtent <= metrics.minScrollExtent) {
      _show();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _controller
      ..duration = reduceMotion ? Duration.zero : _showDuration
      ..reverseDuration = reduceMotion ? Duration.zero : _hideDuration;

    return Column(
      children: [
        SizeTransition(
          sizeFactor: _animation,
          // Keep the header's bottom edge anchored so it slides up and out
          // rather than being cropped from below.
          alignment: AlignmentDirectional.bottomStart,
          child: FadeTransition(
            opacity: _animation,
            child: Focus(
              focusNode: _headerFocus,
              // Keyboard traversal into a hidden field brings it back.
              onFocusChange: (focused) {
                if (focused) _show();
              },
              child: SizedBox(
                key: _headerKey,
                width: double.infinity,
                child: widget.header,
              ),
            ),
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: _onMetrics,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: widget.body,
            ),
          ),
        ),
      ],
    );
  }
}

/// The same behavior for a screen whose search bar scrolls *with* the page
/// inside a [CustomScrollView] (Home, Explore): it scrolls away with the
/// content as usual, then floats back in at the top as soon as the user
/// scrolls up, wherever they are on the page — and snaps fully in or out
/// when the gesture ends so it's never left half-visible.
///
/// Gives [child] an opaque backdrop (plus a short fade below it) so content
/// scrolling underneath doesn't show through while it's floating. At rest
/// in its normal spot the backdrop matches the page and is invisible, so
/// the layout is identical to an ordinary [SliverToBoxAdapter].
class FloatingSearchHeaderSliver extends StatelessWidget {
  const FloatingSearchHeaderSliver({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;

  /// Space around [child], inside the backdrop — use this rather than an
  /// outer [SliverPadding], which would leave the page showing through at
  /// the sides while the header floats.
  final EdgeInsetsGeometry padding;

  static const double _fadeHeight = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SliverFloatingHeader(
      animationStyle: reduceMotion
          ? AnimationStyle.noAnimation
          : AnimationStyle(
              duration: _showDuration,
              curve: _showCurve,
              reverseDuration: _hideDuration,
              reverseCurve: _hideCurve,
            ),
      child: Stack(
        // Hand the sliver's full width straight to the backdrop, so it
        // spans edge to edge whatever [child] would shrink to on its own.
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          // Painted first so the search bar's own shadow still sits on top.
          // Decorative only — taps fall through to the content beneath.
          Positioned(
            left: 0,
            right: 0,
            bottom: -_fadeHeight,
            height: _fadeHeight,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [background, background.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          ColoredBox(
            color: background,
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );
  }
}
