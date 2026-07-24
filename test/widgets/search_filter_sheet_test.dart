import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/theme/app_theme.dart';
import 'package:tripnest_ph/core/widgets/dialogs/search_filter_sheet.dart';
import 'package:tripnest_ph/data/mock/mock_provinces.dart';
import 'package:tripnest_ph/data/mock/mock_regions.dart';

void main() {
  testWidgets('SearchFilterSheet does not overflow on a short phone screen with many regions/provinces', (tester) async {
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2.63;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showSearchFilterSheet(
                  context,
                  regions: mockRegions,
                  provinces: mockProvinces,
                  regionId: null,
                  provinceId: null,
                  minRating: null,
                  onApply: (_, _, _) {},
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Both fixed footer actions must still be reachable, not pushed off-screen,
    // with all 17 region chips visible.
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);

    // Drilling into a region with several provinces (Bicol Region: 6) adds
    // another full row of chips — still must not overflow or lose the
    // footer actions. The chip may start below the fold in the scrollable
    // sheet, so scroll it into view before tapping.
    await tester.ensureVisible(find.text('Bicol Region'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bicol Region'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Albay'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
  });
}
