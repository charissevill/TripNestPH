import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/providers/connectivity_provider.dart';

import '../support/fake_connectivity.dart';

// Run under testWidgets purely for its fake clock, so the settle delay and
// retry backoff can be stepped through without real waiting.
void main() {
  const settle = Duration(milliseconds: 1500);

  late FakeConnectivity connectivity;
  late FakeProbe probe;
  late ConnectivityProvider provider;
  late int notifications;

  void create({List<ConnectivityResult> initial = const [ConnectivityResult.wifi]}) {
    connectivity = FakeConnectivity(initial: initial);
    probe = FakeProbe();
    provider = ConnectivityProvider(connectivity: connectivity, probe: probe.call, settleDelay: settle);
    notifications = 0;
    provider.addListener(() => notifications++);
  }

  testWidgets('starts online without probing when a network is present', (tester) async {
    create();
    await tester.pump();

    expect(provider.isOnline, isTrue);
    expect(notifications, 0);
    expect(probe.calls, 0);
    provider.dispose();
  });

  testWidgets('launching with no network reports offline right away', (tester) async {
    create(initial: const [ConnectivityResult.none]);
    await tester.pump();

    expect(provider.isOnline, isFalse);
    expect(notifications, 1);
    provider.dispose();
  });

  testWidgets('a drop shorter than the settle delay is ignored', (tester) async {
    create();
    connectivity.goOffline();
    await tester.pump(const Duration(milliseconds: 600));
    connectivity.goOnline(ConnectivityResult.mobile);
    await tester.pump(settle * 2);

    expect(provider.isOnline, isTrue);
    expect(notifications, 0);
    provider.dispose();
  });

  testWidgets('flapping collapses into a single change', (tester) async {
    create();
    for (var i = 0; i < 5; i++) {
      connectivity.goOffline();
      await tester.pump(const Duration(milliseconds: 200));
      connectivity.goOnline();
      await tester.pump(const Duration(milliseconds: 200));
    }
    connectivity.goOffline();
    await tester.pump(settle);

    expect(provider.isOnline, isFalse);
    expect(notifications, 1);
    provider.dispose();
  });

  testWidgets('goes offline once, and stays quiet while offline', (tester) async {
    create();
    connectivity.goOffline();
    await tester.pump(settle);
    connectivity.goOffline();
    await tester.pump(settle);

    expect(provider.isOnline, isFalse);
    expect(notifications, 1);
    provider.dispose();
  });

  testWidgets('only reports back online after a successful probe', (tester) async {
    create();
    connectivity.goOffline();
    await tester.pump(settle);

    probe.reachable = false;
    connectivity.goOnline();
    await tester.pump(settle);
    expect(provider.isOnline, isFalse, reason: 'radio is up but the internet is not reachable');
    expect(probe.calls, 1);

    // Still unreachable on the first retry — no extra notifications.
    await tester.pump(const Duration(seconds: 2));
    expect(probe.calls, 2);
    expect(provider.isOnline, isFalse);
    expect(notifications, 1);

    probe.reachable = true;
    await tester.pump(const Duration(seconds: 4));
    expect(provider.isOnline, isTrue);
    expect(notifications, 2);

    // Retrying stops once confirmed online.
    await tester.pump(const Duration(minutes: 1));
    expect(probe.calls, 3);
    provider.dispose();
  });

  testWidgets('losing the network again cancels pending retries', (tester) async {
    create();
    connectivity.goOffline();
    await tester.pump(settle);
    probe.reachable = false;
    connectivity.goOnline();
    await tester.pump(settle);
    expect(probe.calls, 1);

    connectivity.goOffline();
    await tester.pump(const Duration(minutes: 1));

    expect(probe.calls, 1);
    expect(provider.isOnline, isFalse);
    expect(notifications, 1);
    provider.dispose();
  });
}
