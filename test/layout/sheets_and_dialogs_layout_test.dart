import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tripnest_ph/core/providers/favorites_provider.dart';
import 'package:tripnest_ph/core/services/places_service.dart';
import 'package:tripnest_ph/core/widgets/details/place_details_sheet.dart';
import 'package:tripnest_ph/core/widgets/details/review_form_sheet.dart';
import 'package:tripnest_ph/core/widgets/dialogs/confirmation_dialog.dart';
import 'package:tripnest_ph/core/widgets/dialogs/credential_dialog.dart';
import 'package:tripnest_ph/core/widgets/dialogs/emergency_access_sheet.dart';
import 'package:tripnest_ph/core/widgets/dialogs/report_content_dialog.dart';
import 'package:tripnest_ph/core/widgets/dialogs/report_review_dialog.dart';
import 'package:tripnest_ph/core/widgets/dialogs/search_filter_sheet.dart';
import 'package:tripnest_ph/data/mock/mock_provinces.dart';
import 'package:tripnest_ph/data/mock/mock_regions.dart';
import 'package:tripnest_ph/data/repositories/favorites_repository.dart';
import 'package:tripnest_ph/data/repositories/province_repository.dart';
import 'package:tripnest_ph/domain/models/place.dart';

import '../support/fake_image_http_overrides.dart';
import 'layout_harness.dart';

/// Modal sheets and dialogs are opened from a trivial host and then pumped at
/// every size / Text Size (and with the keyboard up where they hold inputs).
Widget _opener(void Function(BuildContext) open) => Builder(
      builder: (context) => Scaffold(
        body: Center(child: TextButton(onPressed: () => open(context), child: const Text('open'))),
      ),
    );

Future<void> _tapOpen(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = FakeImageHttpOverrides();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget withFavorites(Widget app) => ChangeNotifierProvider<FavoritesProvider>.value(
        value: FavoritesProvider(repository: FavoritesRepository(firestore: FakeFirebaseFirestore())),
        child: app,
      );

  const place = Place(
    id: 'places/long',
    name: 'Mount Pinatubo Crater Lake Trek and Hot Spring Adventure Park',
    types: ['tourist_attraction', 'natural_feature'],
    address: 'Barangay Santa Juliana, Capas, Tarlac, Central Luzon, Philippines 2315',
    phoneNumber: '+63 917 123 4567',
    websiteUri: 'https://www.example-very-long-domain-name-for-a-tourism-website.com.ph/attractions/pinatubo',
    rating: 4.6,
    userRatingCount: 12873,
    isOpenNow: true,
    latitude: 15.1428,
    longitude: 120.3496,
    weekdayDescriptions: [
      'Monday: 6:00 AM – 6:00 PM',
      'Tuesday: 6:00 AM – 6:00 PM',
      'Wednesday: 6:00 AM – 6:00 PM',
      'Thursday: 6:00 AM – 6:00 PM',
      'Friday: 6:00 AM – 6:00 PM',
      'Saturday: 5:00 AM – 7:00 PM',
      'Sunday: 5:00 AM – 7:00 PM',
    ],
    editorialSummary:
        'A striking crater lake formed after the 1991 eruption, reached by a scenic 4x4 ride through lahar canyons followed by a moderate trek.',
  );

  layoutMatrix(
    'Place details sheet',
    () => _opener(
      (context) => showPlaceDetailsSheet(
        context,
        place: place,
        placesService: PlacesService(caller: (name, data) async => {'places': <Map<String, dynamic>>[]}),
      ),
    ),
    wrap: withFavorites,
    act: _tapOpen,
    verify: (_) => expect(find.byType(PlaceDetailsSheet), findsOneWidget),
  );

  layoutMatrix(
    'Search filter sheet',
    () => _opener(
      (context) => showSearchFilterSheet(
        context,
        regions: mockRegions,
        provinces: mockProvinces,
        regionId: null,
        provinceId: null,
        minRating: null,
        onApply: (_, _, _, _, _, _, _) {},
      ),
    ),
    act: _tapOpen,
    verify: (_) => expect(find.byType(SearchFilterSheet), findsOneWidget),
  );

  Future<ProvinceRepository> hotlines() async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('provinces').doc('bohol').set({
      'name': 'Bohol',
      'emergencyHotlines': [
        for (var i = 0; i < 6; i++)
          {'label': 'Bohol Provincial Disaster Risk Reduction and Management Office $i', 'number': '(038) 411-300$i'},
      ],
    });
    return ProvinceRepository(firestore: firestore);
  }

  ProvinceRepository? emergencyRepo;
  layoutMatrix(
    'Emergency access sheet',
    () => _opener(
      (context) => showEmergencyAccessSheet(
        context,
        provinceId: 'bohol',
        provinceName: 'Bohol',
        provinceRepository: emergencyRepo,
      ),
    ),
    setup: () async => emergencyRepo = await hotlines(),
    act: _tapOpen,
  );

  layoutMatrix(
    'Review form sheet',
    () => _opener((context) => showReviewFormSheet(context)),
    act: _tapOpen,
  );
  layoutMatrix(
    'Review form sheet (keyboard)',
    () => _opener((context) => showReviewFormSheet(context, initialComment: 'Great place. ' * 20)),
    act: _tapOpen,
    keyboardHeight: 300,
  );

  layoutMatrix(
    'Confirmation dialog',
    () => _opener(
      (context) => showConfirmationDialog(
        context,
        title: 'Delete your account and everything saved with it?',
        message:
            'This permanently removes your profile, saved places, itineraries, reviews and group polls. This action cannot be undone, so please be sure before you continue.',
        confirmLabel: 'Delete my account',
        isDestructive: true,
      ),
    ),
    act: _tapOpen,
  );

  layoutMatrix(
    'Credential dialog (keyboard)',
    () => _opener(
      (context) => showDialog<void>(
        context: context,
        builder: (_) => CredentialDialog(
          title: 'Change your password',
          confirmLabel: 'Update password',
          onConfirm: () async => true,
          fields: [
            CredentialField(label: 'Current password', controller: TextEditingController(), obscure: true),
            CredentialField(label: 'New password', controller: TextEditingController(), obscure: true),
            CredentialField(label: 'Confirm new password', controller: TextEditingController(), obscure: true),
          ],
        ),
      ),
    ),
    act: _tapOpen,
    keyboardHeight: 300,
  );

  layoutMatrix(
    'Report content dialog',
    () => _opener((context) => showReportContentDialog(context)),
    act: _tapOpen,
  );
  layoutMatrix(
    'Report review dialog',
    () => _opener((context) => showReportReviewDialog(context)),
    act: _tapOpen,
  );
}
