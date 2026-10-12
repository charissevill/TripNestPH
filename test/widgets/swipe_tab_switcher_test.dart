import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/widgets/navigation/swipe_tab_switcher.dart';

/// Three tabs whose body is a vertical list (tall enough to scroll) with a
/// horizontal chip strip and a button on top — the same mix of gestures
/// Explore's tab body sits among.
class _Harness extends StatefulWidget {
  const _Harness({super.key, this.initialIndex = 0, this.onButton});

  final int initialIndex;
  final VoidCallback? onButton;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late int index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Selected: $index'),
        Expanded(
          child: SwipeTabSwitcher(
            index: index,
            length: 3,
            onIndexChanged: (i) => setState(() => index = i),
            child: ListView(
              key: const Key('vertical'),
              children: [
                SizedBox(
                  height: 60,
                  child: ListView(
                    key: const Key('horizontal'),
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (var i = 0; i < 20; i++)
                        SizedBox(width: 100, child: Text('Chip $i')),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: widget.onButton,
                  child: const Text('Button'),
                ),
                for (var i = 0; i < 40; i++)
                  SizedBox(height: 60, child: Text('Tab $index row $i')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget harness, {
  TextDirection textDirection = TextDirection.ltr,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: Scaffold(body: harness),
      ),
    ),
  );
}

final _body = find.text('Tab 0 row 3');

void main() {
  testWidgets('swiping left moves to the next tab, right to the previous', (
    tester,
  ) async {
    await _pump(tester, const _Harness());

    await tester.drag(_body, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 1'), findsOneWidget);
    expect(find.text('Tab 1 row 3'), findsOneWidget);

    await tester.drag(find.text('Tab 1 row 3'), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 0'), findsOneWidget);
  });

  testWidgets('a quick fling commits even over a short distance', (
    tester,
  ) async {
    await _pump(tester, const _Harness());

    await tester.fling(_body, const Offset(-60, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Selected: 1'), findsOneWidget);
  });

  testWidgets('a short, slow drag snaps back without changing tabs', (
    tester,
  ) async {
    await _pump(tester, const _Harness());

    await tester.timedDrag(
      _body,
      const Offset(-50, 0),
      const Duration(milliseconds: 800),
    );
    await tester.pumpAndSettle();
    expect(find.text('Selected: 0'), findsOneWidget);
  });

  testWidgets('swiping past the first or last tab does nothing', (
    tester,
  ) async {
    await _pump(tester, const _Harness());
    await tester.drag(_body, const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 0'), findsOneWidget);

    await _pump(tester, const _Harness(key: Key('last'), initialIndex: 2));
    await tester.drag(find.text('Tab 2 row 3'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 2'), findsOneWidget);
  });

  testWidgets('vertical scrolling still scrolls and never changes tabs', (
    tester,
  ) async {
    await _pump(tester, const _Harness());

    await tester.drag(_body, const Offset(-20, -400));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 0'), findsOneWidget);
    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('vertical')),
            matching: find.byType(Scrollable),
          ).first,
        )
        .position;
    expect(position.pixels, greaterThan(0));
  });

  testWidgets('a nested horizontal list scrolls itself instead of the tabs', (
    tester,
  ) async {
    await _pump(tester, const _Harness());

    await tester.drag(find.text('Chip 1'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 0'), findsOneWidget);
    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('horizontal')),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(position.pixels, greaterThan(0));
  });

  testWidgets('taps on buttons inside the swipe area still work', (
    tester,
  ) async {
    var taps = 0;
    await _pump(tester, _Harness(onButton: () => taps++));

    await tester.tap(find.text('Button'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.text('Selected: 0'), findsOneWidget);
  });

  testWidgets('directions mirror under RTL, same as TabBarView', (
    tester,
  ) async {
    await _pump(tester, const _Harness(), textDirection: TextDirection.rtl);

    // Leftward is "previous" in RTL — nothing before tab 0.
    await tester.drag(_body, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 0'), findsOneWidget);

    await tester.drag(_body, const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 1'), findsOneWidget);
  });

  testWidgets('hands a swipe past its last tab up to an enclosing switcher', (
    tester,
  ) async {
    var outer = 0;
    var inner = 1;
    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => SwipeTabSwitcher(
          index: outer,
          length: 3,
          onIndexChanged: (i) => setState(() => outer = i),
          child: SwipeTabSwitcher(
            index: inner,
            length: 2,
            onIndexChanged: (i) => setState(() => inner = i),
            child: SizedBox.expand(child: Text('outer $outer inner $inner')),
          ),
        ),
      ),
    );

    // The inner switcher is already on its last tab, so the outer one moves.
    await tester.drag(find.textContaining('outer'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.text('outer 1 inner 1'), findsOneWidget);

    // Swiping back has somewhere to go inside, so the inner one takes it.
    await tester.drag(find.textContaining('outer'), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(find.text('outer 1 inner 0'), findsOneWidget);
  });
}
