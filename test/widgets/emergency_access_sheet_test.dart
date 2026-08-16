import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/widgets/dialogs/emergency_access_sheet.dart';
import 'package:tripnest_ph/data/repositories/province_repository.dart';

void main() {
  Future<void> pumpOpener(WidgetTester tester, {required ProvinceRepository repository, String? provinceId, String? provinceName}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showEmergencyAccessSheet(
                  context,
                  provinceId: provinceId,
                  provinceName: provinceName,
                  provinceRepository: repository,
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
  }

  testWidgets('always shows the national hotline, even with no province resolved', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await pumpOpener(tester, repository: ProvinceRepository(firestore: firestore));

    expect(find.text('National Emergency Hotline'), findsOneWidget);
    expect(find.text('911'), findsOneWidget);
    expect(find.text('Nationwide emergency numbers.'), findsOneWidget);
  });

  testWidgets('shows that province\'s own hotlines once resolved', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('provinces').doc('bohol').set({
      'name': 'Bohol',
      'emergencyHotlines': [
        {'label': 'Bohol Police', 'number': '(038) 411-3000'},
        {'label': 'Bohol Fire Department', 'number': '(038) 411-4000'},
      ],
    });

    await pumpOpener(
      tester,
      repository: ProvinceRepository(firestore: firestore),
      provinceId: 'bohol',
      provinceName: 'Bohol',
    );

    expect(find.text('National Emergency Hotline'), findsOneWidget);
    expect(find.text('Bohol Police'), findsOneWidget);
    expect(find.text('(038) 411-3000'), findsOneWidget);
    expect(find.text('Bohol Fire Department'), findsOneWidget);
    expect(find.text('Numbers for Bohol, plus nationwide help.'), findsOneWidget);
  });

  testWidgets('a province with no hotlines on file still shows just the national one, no error', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('provinces').doc('empty-province').set({'name': 'Nowhereland'});

    await pumpOpener(
      tester,
      repository: ProvinceRepository(firestore: firestore),
      provinceId: 'empty-province',
      provinceName: 'Nowhereland',
    );

    expect(tester.takeException(), isNull);
    expect(find.text('National Emergency Hotline'), findsOneWidget);
  });

  testWidgets('shows Find Nearby actions for hospital and police', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await pumpOpener(tester, repository: ProvinceRepository(firestore: firestore));

    expect(find.text('Hospital'), findsOneWidget);
    expect(find.text('Police'), findsOneWidget);
  });
}
