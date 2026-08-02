import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/data/repositories/province_repository.dart';
import 'package:tripnest_ph/presentation/admin/admin_bulk_province_content_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('loads the existing province list and shows the picker button', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('provinces').doc('bohol').set({
      'name': 'Bohol',
      'regionId': 'region-7',
      'regionName': 'Central Visayas',
      'islandGroup': 'Visayas',
    });

    await tester.pumpWidget(
      _wrap(
        AdminBulkProvinceContentScreen(
          provinceRepository: ProvinceRepository(firestore: firestore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose CSV File'), findsOneWidget);
    expect(find.text('Bulk Fill Province Content'), findsOneWidget);
    // No file picked yet — no preview list or import button should show.
    expect(find.textContaining('valid'), findsNothing);
  });
}
