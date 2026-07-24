import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/theme/app_theme.dart';
import 'package:tripnest_ph/core/widgets/cards/travel_tip_card.dart';
import 'package:tripnest_ph/domain/models/travel_tip.dart';

void main() {
  testWidgets('TravelTipCard does not overflow at 196px in the Home carousel, even with a long title', (tester) async {
    const tip = TravelTip(
      id: 'tip-1',
      title: 'Carry small bills and coins for jeepneys, tricycles, and stalls that rarely have change',
      description:
          'Plan trips between November and May to enjoy the sunniest, driest weather across most of the Philippines before the rainy season sets in.',
      iconKey: 'wb_sunny',
      colorKey: 'primary',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            height: 196,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [TravelTipCard(tip: tip)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Tapping the card opens a sheet with the full, unclipped title and description', (tester) async {
    const tip = TravelTip(
      id: 'tip-1',
      title: 'Carry small bills and coins for jeepneys, tricycles, and stalls that rarely have change',
      description:
          'Plan trips between November and May to enjoy the sunniest, driest weather across most of the Philippines before the rainy season sets in.',
      iconKey: 'wb_sunny',
      colorKey: 'primary',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SizedBox(height: 196, child: TravelTipCard(tip: tip)),
        ),
      ),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The full text should now appear twice — once (clipped) in the card
    // behind the sheet, once (in full) inside the sheet itself.
    expect(find.text(tip.title), findsNWidgets(2));
    expect(find.text(tip.description), findsNWidgets(2));
  });
}
