import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/widgets/layout/scroll_aware_search_header.dart';

const double _headerHeight = 80;

/// A search field over a vertical list with a horizontal chip strip at the
/// top — the same shape as Search/Nearby/FAQ. [rows] controls whether the
/// list is long enough to scroll; [showList] swaps it for a non-scrolling
/// empty state, like a "No matches" result.
class _Harness extends StatefulWidget {
  const _Harness({super.key, required this.controller, this.rows = 40});

  final TextEditingController controller;
  final int rows;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool showList = true;

  void setShowList(bool value) => setState(() => showList = value);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: CollapsibleSearchHeader(
          header: SizedBox(
            height: _headerHeight,
            child: TextField(
              key: const Key('field'),
              controller: widget.controller,
            ),
          ),
          body: showList
              ? ListView(
                  key: const Key('body'),
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
                    for (var i = 0; i < widget.rows; i++)
                      SizedBox(height: 60, child: Text('Row $i')),
                  ],
                )
              : const Center(key: Key('body'), child: Text('No matches')),
        ),
      ),
    );
  }
}

/// How much of the header is on screen — the body starts right below it.
double _visibleHeader(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const Key('body'))).dy;

void main() {
  group('FloatingSearchHeaderSliver', _sliverTests);

  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  testWidgets('hides on scroll down and comes back on scroll up', (
    tester,
  ) async {
    await tester.pumpWidget(_Harness(controller: controller));
    expect(_visibleHeader(tester), _headerHeight);

    await tester.drag(find.byKey(const Key('body')), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(_visibleHeader(tester), 0);

    // Partway back up, nowhere near the top — still reappears.
    await tester.drag(find.byKey(const Key('body')), const Offset(0, 60));
    await tester.pumpAndSettle();
    expect(_visibleHeader(tester), _headerHeight);
    expect(
      tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const Key('body')),
              matching: find.byType(Scrollable),
            ).first,
          )
          .position
          .pixels,
      greaterThan(0),
    );
  });

  testWidgets('ignores a small jitter', (tester) async {
    await tester.pumpWidget(_Harness(controller: controller));
    // A real movement, but well short of the hide distance.
    await tester.drag(find.byKey(const Key('body')), const Offset(0, -15));
    await tester.pumpAndSettle();
    expect(_visibleHeader(tester), _headerHeight);
  });

  testWidgets('horizontal scrolling never toggles it', (tester) async {
    await tester.pumpWidget(_Harness(controller: controller));
    await tester.drag(find.byKey(const Key('horizontal')), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(_visibleHeader(tester), _headerHeight);
  });

  testWidgets('keeps the typed search text while hidden', (tester) async {
    await tester.pumpWidget(_Harness(controller: controller));
    await tester.enterText(find.byKey(const Key('field')), 'Boracay');
    await tester.pump();

    await tester.drag(find.byKey(const Key('body')), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(_visibleHeader(tester), 0);
    // Focus is dropped so keystrokes can't land in an invisible field.
    expect(FocusManager.instance.primaryFocus?.context?.widget, isNot(isA<EditableText>()));

    await tester.drag(find.byKey(const Key('body')), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(_visibleHeader(tester), _headerHeight);
    expect(controller.text, 'Boracay');
    expect(find.text('Boracay'), findsOneWidget);
  });

  testWidgets('does not hide when the list barely overflows', (tester) async {
    // 600px viewport - 80px header: a few rows past that can't hide it
    // without the content then fitting and leaving nothing to scroll back.
    await tester.pumpWidget(_Harness(controller: controller, rows: 9));
    await tester.drag(find.byKey(const Key('body')), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(_visibleHeader(tester), _headerHeight);
  });

  testWidgets('comes back when the list is replaced by a non-scrolling state', (
    tester,
  ) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, controller: controller));
    await tester.drag(find.byKey(const Key('body')), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(_visibleHeader(tester), 0);

    key.currentState!.setShowList(false);
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
    expect(_visibleHeader(tester), _headerHeight);
  });

  testWidgets('respects reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_Harness(controller: controller));
    await tester.drag(find.byKey(const Key('body')), const Offset(0, -300));
    await tester.pump();
    await tester.pump();
    expect(_visibleHeader(tester), 0);
  });
}

/// Home/Explore shape: a title, the floating search header, then a long page
/// that also contains a horizontal strip.
class _SliverHarness extends StatelessWidget {
  const _SliverHarness();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          key: const Key('page'),
          slivers: [
            const SliverToBoxAdapter(
              child: SizedBox(height: 100, child: Text('Title')),
            ),
            const FloatingSearchHeaderSliver(
              child: SizedBox(
                key: Key('search'),
                height: 60,
                child: Text('Search'),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  SizedBox(
                    height: 60,
                    child: ListView(
                      key: const Key('strip'),
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (var i = 0; i < 20; i++)
                          SizedBox(width: 100, child: Text('Chip $i')),
                      ],
                    ),
                  ),
                  for (var i = 0; i < 40; i++)
                    SizedBox(height: 60, child: Text('Row $i')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _sliverTests() {
  double searchTop(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(const Key('search'))).dy;

  testWidgets('floating header rests in place, scrolls away, floats back', (
    tester,
  ) async {
    await tester.pumpWidget(const _SliverHarness());
    // At rest it sits exactly where a plain box would: under the title.
    expect(searchTop(tester), 100);

    await tester.drag(find.byKey(const Key('page')), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search')), findsNothing);

    // A short scroll back up, still far from the top of the page.
    await tester.drag(find.byKey(const Key('page')), const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(searchTop(tester), 0);

    await tester.drag(find.byKey(const Key('page')), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search')), findsNothing);
  });

  testWidgets('floating header ignores horizontal scrolling', (tester) async {
    await tester.pumpWidget(const _SliverHarness());
    await tester.drag(find.byKey(const Key('page')), const Offset(0, -170));
    await tester.pumpAndSettle();
    // Finders skip slivers that are fully out of the viewport.
    expect(find.byKey(const Key('search')), findsNothing);

    await tester.drag(find.byKey(const Key('strip')), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search')), findsNothing);
  });
}
