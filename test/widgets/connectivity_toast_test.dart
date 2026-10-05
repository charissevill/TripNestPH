import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:tripnest_ph/core/providers/connectivity_provider.dart';
import 'package:tripnest_ph/core/widgets/banners/connectivity_toast.dart';

import '../support/fake_connectivity.dart';

void main() {
  const settle = Duration(milliseconds: 1500);
  const offlineText = 'No internet connection';
  const onlineText = 'Back online';

  late FakeConnectivity connectivity;
  late FakeProbe probe;
  late ConnectivityProvider provider;
  late int taps;

  Future<void> pumpApp(WidgetTester tester, {List<ConnectivityResult> initial = const [ConnectivityResult.wifi]}) async {
    connectivity = FakeConnectivity(initial: initial);
    probe = FakeProbe();
    provider = ConnectivityProvider(connectivity: connectivity, probe: probe.call, settleDelay: settle);
    taps = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          builder: (context, child) => ConnectivityToastHost(child: child!),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 80,
                  child: TextButton(onPressed: () => taps++, child: const Text('Under the toast')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  }

  testWidgets('shows nothing while the connection holds', (tester) async {
    await pumpApp(tester);
    await tester.pump(const Duration(seconds: 10));

    expect(find.text(offlineText), findsNothing);
    expect(find.text(onlineText), findsNothing);
    await tearDownApp(tester);
  });

  testWidgets('offline then back online, each shown once and auto-hidden', (tester) async {
    await pumpApp(tester);

    connectivity.goOffline();
    await tester.pump(settle);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(offlineText), findsOneWidget);

    // Repeated offline events while offline don't re-show it.
    await tester.pump(ConnectivityToastHost.offlineVisibleFor);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(offlineText), findsNothing);
    connectivity.goOffline();
    await tester.pump(settle);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(offlineText), findsNothing);

    connectivity.goOnline();
    await tester.pump(settle);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(onlineText), findsOneWidget);
    expect(find.text(offlineText), findsNothing);

    await tester.pump(ConnectivityToastHost.onlineVisibleFor);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(onlineText), findsNothing);
    await tearDownApp(tester);
  });

  testWidgets('does not say back online until the internet is reachable', (tester) async {
    await pumpApp(tester);
    connectivity.goOffline();
    await tester.pump(settle);
    await tester.pump(const Duration(seconds: 5));

    probe.reachable = false;
    connectivity.goOnline();
    await tester.pump(settle);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(onlineText), findsNothing);

    probe.reachable = true;
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(onlineText), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tearDownApp(tester);
  });

  testWidgets('launching offline shows the offline notice', (tester) async {
    await pumpApp(tester, initial: const [ConnectivityResult.none]);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(offlineText), findsOneWidget);
    await tester.pump(ConnectivityToastHost.offlineVisibleFor);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(offlineText), findsNothing);
    await tearDownApp(tester);
  });

  testWidgets('never blocks taps on the screen underneath', (tester) async {
    await pumpApp(tester);
    connectivity.goOffline();
    await tester.pump(settle);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(offlineText), findsOneWidget);

    await tester.tap(find.text('Under the toast'), warnIfMissed: false);
    await tester.tapAt(tester.getCenter(find.text(offlineText)));
    expect(taps, 2);

    await tester.pump(const Duration(seconds: 5));
    await tearDownApp(tester);
  });
}
