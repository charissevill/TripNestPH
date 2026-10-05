import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../providers/connectivity_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Wraps the whole app (via `MaterialApp.builder`) and floats a small
/// "No internet connection" / "Back online" pill at the top of the screen
/// whenever [ConnectivityProvider.isOnline] changes, on every route.
///
/// It only reacts to actual status changes, so the same message is never
/// repeated while the status holds, and it hides itself after a few seconds.
/// It ignores all touches and sits in its own layer above the navigator, so
/// it never blocks a tap, steals focus or triggers navigation. Debouncing
/// flapping connections and confirming real reachability are handled by
/// [ConnectivityProvider], not here.
class ConnectivityToastHost extends StatefulWidget {
  const ConnectivityToastHost({super.key, required this.child});

  final Widget child;

  static const Duration offlineVisibleFor = Duration(seconds: 4);
  static const Duration onlineVisibleFor = Duration(seconds: 3);

  @override
  State<ConnectivityToastHost> createState() => _ConnectivityToastHostState();
}

class _ConnectivityToastHostState extends State<ConnectivityToastHost> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, -1.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic));

  ConnectivityProvider? _provider;
  bool _lastOnline = true;
  bool _showingOnline = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    // Rebuild once the hide animation finishes so the pill leaves the tree.
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<ConnectivityProvider>(context, listen: false);
    if (identical(provider, _provider)) return;
    _provider?.removeListener(_onConnectivityChanged);
    _provider = provider..addListener(_onConnectivityChanged);
    _lastOnline = provider.isOnline;
    // Already offline by the time the app first builds (launched offline).
    if (!provider.isOnline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_lastOnline) _show(online: false);
      });
    }
  }

  void _onConnectivityChanged() {
    final online = _provider!.isOnline;
    if (online == _lastOnline) return;
    _lastOnline = online;
    _show(online: online);
  }

  void _show({required bool online}) {
    _hideTimer?.cancel();
    setState(() => _showingOnline = online);
    _controller.forward();
    _hideTimer = Timer(
      online ? ConnectivityToastHost.onlineVisibleFor : ConnectivityToastHost.offlineVisibleFor,
      () {
        if (mounted) _controller.reverse();
      },
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _provider?.removeListener(_onConnectivityChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_controller.isDismissed)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: SafeArea(
                bottom: false,
                minimum: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SlideTransition(
                    position: _slide,
                    child: FadeTransition(
                      opacity: _controller,
                      child: _ConnectivityPill(online: _showingOnline),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConnectivityPill extends StatelessWidget {
  const _ConnectivityPill({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final message = online ? 'Back online' : 'No internet connection';
    // Same dark slate as the app's snackbars for the offline notice, and a
    // green dark enough for white text to stay readable for "back online".
    // Fixed colors (not theme-derived) so it reads the same in light and dark.
    final background = online ? AppColors.secondaryDark : AppColors.textPrimary;
    return Semantics(
      liveRegion: true,
      container: true,
      label: message,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: background,
          elevation: 6,
          shadowColor: Colors.black38,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(online ? Symbols.wifi_rounded : Symbols.wifi_off_rounded, size: 18, color: Colors.white),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
