import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../services/internet_probe.dart';

/// Checks whether the internet is actually reachable (see
/// [probeInternetReachable]). Injectable so tests never hit the network.
typedef ReachabilityProbe = Future<bool> Function();

/// Tracks whether the device currently has a working internet connection.
/// Firestore's own offline cache (enabled in `main.dart`) keeps the app
/// usable while offline; this only drives the lightweight offline notices
/// (`OfflineBanner`, `ConnectivityToastHost`) rather than changing any
/// screen's behavior.
///
/// Unstable connections are handled in two ways:
/// - Every radio change waits [settleDelay] before being acted on, so a
///   brief drop (e.g. a Wi-Fi → mobile data handover) or a burst of
///   flapping events collapses into a single, final status.
/// - Coming back online is only reported once a real request succeeds, so
///   a radio that's up with no internet behind it (captive portal, dead
///   router uplink) stays "offline" and is re-checked with backoff.
class ConnectivityProvider extends ChangeNotifier {
  ConnectivityProvider({
    Connectivity? connectivity,
    ReachabilityProbe? probe,
    this.settleDelay = const Duration(milliseconds: 1500),
  }) : _connectivity = connectivity ?? Connectivity(),
       // Browsers block cross-origin probe requests, so on web the
       // browser's own online/offline signal is trusted as-is.
       _probe = probe ?? (kIsWeb ? _assumeReachable : probeInternetReachable) {
    _subscription = _connectivity.onConnectivityChanged.listen(_onNetworkChanged, onError: (Object _) {});
    _connectivity.checkConnectivity().then(_onInitialNetwork, onError: (Object _) {});
  }

  static Future<bool> _assumeReachable() async => true;

  /// Backoff between re-checks while a network is up but unreachable.
  static const List<Duration> _retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];

  final Connectivity _connectivity;
  final ReachabilityProbe _probe;
  final Duration settleDelay;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;

  bool isOnline = true;

  /// Latest raw radio state, before settling / probing.
  bool _hasNetwork = true;
  Timer? _settleTimer;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  // Bumped on every radio change so a probe that was already in flight
  // can't apply a result that's been superseded.
  int _generation = 0;
  bool _disposed = false;
  bool _sawNetworkEvent = false;

  void _onInitialNetwork(List<ConnectivityResult> results) {
    // Launching with no network at all needs no settling — report it right
    // away. Launching with one is already the default "online" state.
    // A live change event is always newer than this one-off check.
    if (_disposed || _sawNetworkEvent) return;
    if (!_hasConnection(results)) {
      _hasNetwork = false;
      _setOnline(false);
    }
  }

  void _onNetworkChanged(List<ConnectivityResult> results) {
    _sawNetworkEvent = true;
    _hasNetwork = _hasConnection(results);
    _generation++;
    _retryAttempt = 0;
    _retryTimer?.cancel();
    _settleTimer?.cancel();
    _settleTimer = Timer(settleDelay, _evaluate);
  }

  static bool _hasConnection(List<ConnectivityResult> results) => results.any((r) => r != ConnectivityResult.none);

  void _evaluate() {
    _settleTimer = null;
    if (!_hasNetwork) {
      _setOnline(false);
    } else if (!isOnline) {
      _verifyReachable();
    }
  }

  Future<void> _verifyReachable() async {
    final generation = _generation;
    bool reachable;
    try {
      reachable = await _probe();
    } catch (_) {
      reachable = false;
    }
    if (_disposed || generation != _generation) return;
    if (reachable) {
      _retryAttempt = 0;
      _setOnline(true);
      return;
    }
    final delay = _retryDelays[math.min(_retryAttempt, _retryDelays.length - 1)];
    _retryAttempt++;
    _retryTimer = Timer(delay, _verifyReachable);
  }

  void _setOnline(bool online) {
    if (online == isOnline) return;
    isOnline = online;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _settleTimer?.cancel();
    _retryTimer?.cancel();
    _subscription.cancel();
    super.dispose();
  }
}
