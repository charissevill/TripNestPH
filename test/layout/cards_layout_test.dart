import 'dart:io';
import 'dart:math' as math;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tripnest_ph/core/providers/favorites_provider.dart';
import 'package:tripnest_ph/core/widgets/cards/business_card.dart';
import 'package:tripnest_ph/core/widgets/cards/destination_card.dart';
import 'package:tripnest_ph/core/widgets/cards/festival_card.dart';
import 'package:tripnest_ph/core/widgets/cards/restaurant_card.dart';
import 'package:tripnest_ph/core/widgets/cards/travel_image_frame.dart';
import 'package:tripnest_ph/core/widgets/states/loading_widget.dart';
import 'package:tripnest_ph/data/mock/mock_destinations.dart';
import 'package:tripnest_ph/data/mock/mock_festivals.dart';
import 'package:tripnest_ph/data/mock/mock_restaurants.dart';
import 'package:tripnest_ph/data/repositories/favorites_repository.dart';
import 'package:tripnest_ph/domain/models/business.dart';

import '../support/fake_image_http_overrides.dart';
import 'layout_harness.dart';

/// The grids on Explore / Saved / Recently Viewed / Nearby give each card a
/// fixed-height cell (`imageHeight + 92`) at a width that depends on the
/// column count, so the card's text block must fit that box at every column
/// width and Text Size, and its overlay badges must not collide.
const _imageHeight = 140.0;
const _cellHeight = _imageHeight + 92;

/// Card widths the grids actually produce: 2 columns on 280-390px phones,
/// 3-4 columns on tablet/desktop, and the 220px default used by carousels.
const _cardWidths = <double>[118, 138, 165, 190, 220, 260, 330];

T _longest<T>(Iterable<T> items, String Function(T) key) =>
    items.reduce((a, b) => key(a).length >= key(b).length ? a : b);

void main() {
  setUpAll(() {
    HttpOverrides.global = FakeImageHttpOverrides();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final destinations = {
    _longest(mockDestinations, (d) => d.name),
    _longest(mockDestinations, (d) => d.provinceName),
    _longest(mockDestinations, (d) => d.shortDescription),
  };
  final restaurants = {
    _longest(mockRestaurants, (r) => r.name),
    _longest(mockRestaurants, (r) => r.provinceName),
    ...mockRestaurants.where((r) => r.isPopular && r.businessId.isNotEmpty).take(1),
    ...mockRestaurants.where((r) => r.isPopular).take(1),
  };
  final festivals = {
    _longest(mockFestivals, (f) => f.name),
    _longest(mockFestivals, (f) => f.dateLabel),
    _longest(mockFestivals, (f) => f.provinceName),
  };
  const business = Business(
    id: 'b1',
    ownerId: 'o1',
    name: 'The Very Long Named Beachfront Boutique Hotel and Spa Resort of Palawan',
    category: 'accommodation',
    description: 'desc',
    provinceId: 'p',
    provinceName: 'Camarines Norte and Surigao del Sur',
    address: '123 A Very Long Street Address Name, Barangay Somewhere, City Of Somewhere Far Away',
  );

  final cards = <String, Widget Function(double width)>{
    for (final d in destinations)
      'Destination "${d.name}"': (w) => DestinationCard(destination: d, onTap: () {}, width: w, imageHeight: _imageHeight),
    for (final r in restaurants)
      'Restaurant "${r.name}"': (w) => RestaurantCard(restaurant: r, onTap: () {}, width: w, imageHeight: _imageHeight),
    for (final f in festivals)
      'Festival "${f.name}"': (w) => FestivalCard(festival: f, onTap: () {}, width: w, imageHeight: _imageHeight),
    'Business': (w) => BusinessCard(business: business, onTap: () {}, width: w, imageHeight: _imageHeight),
  };

  Widget host(Widget card, double width, double scale) => layoutApp(
        scale,
        ChangeNotifierProvider<FavoritesProvider>.value(
          value: FavoritesProvider(repository: FavoritesRepository(firestore: FakeFirebaseFirestore())),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, height: _cellHeight, child: card),
            ),
          ),
        ),
      );

  for (final entry in cards.entries) {
    for (final width in _cardWidths) {
      for (final scale in layoutTextScales) {
        final label = '${entry.key} @ card ${width.toInt()}px x$scale';
        testWidgets(label, (tester) async {
          if (!await loadLayoutFonts()) {
            markTestSkipped('Roboto (bundled with the Flutter SDK) not found.');
            return;
          }
          tester.view.physicalSize = const Size(1000, 600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final problems = await captureLayoutErrors(() async {
            await tester.pumpWidget(host(entry.value(width), width, scale));
            for (var i = 0; i < 3; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
          });

          // Overlay badges (tag / bookmark on top, location / rating below)
          // must not sit on top of one another.
          final frame = find.byType(TravelImageFrame);
          if (frame.evaluate().isNotEmpty) {
            final overlays = <Rect>[];
            final positioned = find.descendant(of: frame, matching: find.byType(Positioned));
            for (var i = 0; i < positioned.evaluate().length; i++) {
              final rect = tester.getRect(positioned.at(i));
              if (rect.size == tester.getSize(frame)) continue; // the gradient scrim
              overlays.add(rect);
            }
            for (var i = 0; i < overlays.length; i++) {
              for (var j = i + 1; j < overlays.length; j++) {
                final overlap = overlays[i].intersect(overlays[j]);
                if (overlap.width > 0.5 && overlap.height > 0.5) {
                  problems.add(
                    'badges overlap by ${overlap.width.toStringAsFixed(0)}x${overlap.height.toStringAsFixed(0)}px '
                    '(${overlays[i].width.toStringAsFixed(0)}px + ${overlays[j].width.toStringAsFixed(0)}px in ${math.min(width, 9999).toInt()}px card) @ ${entry.key.split(' ').first}',
                  );
                }
              }
            }
          }
          reportLayoutErrors(label, problems);
          expect(problems, isEmpty);
        });
      }
    }
  }

  // The skeleton must use the same responsive column count as the real grids.
  layoutMatrix('Loading grid skeleton', () => Scaffold(body: LoadingWidget.grid()));
}
