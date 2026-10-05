import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Scripted stand-in for the `connectivity_plus` platform plugin.
class FakeConnectivity implements Connectivity {
  FakeConnectivity({this.initial = const [ConnectivityResult.wifi]});

  final List<ConnectivityResult> initial;
  final StreamController<List<ConnectivityResult>> _changes = StreamController.broadcast();

  void goOffline() => _changes.add(const [ConnectivityResult.none]);
  void goOnline([ConnectivityResult via = ConnectivityResult.wifi]) => _changes.add([via]);

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _changes.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => initial;
}

/// Reachability probe whose answer the test controls, counting calls.
class FakeProbe {
  bool reachable = true;
  int calls = 0;

  Future<bool> call() async {
    calls++;
    return reachable;
  }
}
