import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:tripnest_ph/core/services/places_service.dart';
import 'package:tripnest_ph/core/widgets/details/place_details_sheet.dart';
import 'package:tripnest_ph/domain/models/place.dart';

void main() {
  final placesService = PlacesService(caller: (name, data) async => {'places': <Map<String, dynamic>>[]});

  Widget wrap(Place place) => MaterialApp(
    home: Scaffold(body: PlaceDetailsSheet(place: place, placesService: placesService)),
  );

  testWidgets('embeds a real map pin when the place has coordinates', (tester) async {
    const place = Place(
      id: 'places/alona-beach',
      name: 'Alona Beach',
      types: ['tourist_attraction'],
      address: 'Panglao, Bohol',
      latitude: 9.5488,
      longitude: 123.7729,
    );

    await tester.pumpWidget(wrap(place));
    await tester.pumpAndSettle();

    expect(find.byType(GoogleMap), findsOneWidget);
    expect(find.byIcon(Symbols.location_off_rounded), findsNothing);
  });

  testWidgets('falls back to the neutral placeholder when the place has no coordinates', (tester) async {
    const place = Place(id: 'places/unknown', name: 'Somewhere Vague', types: ['point_of_interest']);

    await tester.pumpWidget(wrap(place));
    await tester.pumpAndSettle();

    expect(find.byType(GoogleMap), findsNothing);
    expect(find.byIcon(Symbols.location_off_rounded), findsOneWidget);
  });
}
