import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
// The mock helpers live in firebase_core's own platform interface package.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tripnest_ph/core/providers/auth_provider.dart';
import 'package:tripnest_ph/core/services/auth_service.dart';
import 'package:tripnest_ph/data/repositories/admin_repository.dart';
import 'package:tripnest_ph/data/repositories/destination_repository.dart';
import 'package:tripnest_ph/data/repositories/province_repository.dart';
import 'package:tripnest_ph/data/repositories/user_repository.dart';
import 'package:tripnest_ph/presentation/admin/admin_tourist_spot_list_screen.dart';

import '../support/fake_image_http_overrides.dart';
import 'layout_harness.dart';

/// The Tourist Spots screen with real rows in both of its steps — the
/// province picker, then one province's spots — since the mocked-Firebase
/// pass in `app_screens_layout_test.dart` only ever reaches its loading state.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = FakeImageHttpOverrides();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final firestore = FakeFirebaseFirestore();
  var seeded = false;

  Future<void> seed() async {
    if (seeded) return;
    seeded = true;
    const islandGroups = ['Luzon', 'Visayas', 'Mindanao'];
    for (var i = 0; i < 20; i++) {
      await firestore.collection('provinces').doc('prov$i').set({
        // 'A' sorts the first one to the top, where the test taps it.
        'name': i == 0 ? 'A Province of Camarines Norte and Sur Number 0' : 'Province of Camarines Norte and Sur Number $i',
        'regionId': 'region-$i',
        'regionName': 'Bangsamoro Autonomous Region in Muslim Mindanao',
        'islandGroup': islandGroups[i % 3],
      });
    }
    const categories = ['beaches', 'mountains', 'historical', 'nature', 'an-unlisted-category-id', ''];
    for (var i = 0; i < 13; i++) {
      await firestore.collection('tourist_spots').add({
        'name': 'Alona Beach and Panglao Island Marine Sanctuary Number $i',
        'provinceId': 'prov0',
        'provinceName': 'A Province of Camarines Norte and Sur Number 0',
        'categoryId': categories[i % categories.length],
        'heroImageUrl': i.isEven ? 'https://example.com/photo-$i.jpg' : '',
        'shortDescription': 'A long stretch of white sand lined with dive shops, restaurants and resorts.',
        'rating': 3.5 + (i % 3) * 0.5,
        'reviewCount': i.isOdd ? 0 : 1200 + i,
        'isFeatured': i % 2 == 0,
        'isHiddenGem': i % 3 == 0,
      });
    }
  }

  Widget withAuth(Widget app) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: AuthProvider(
        authService: AuthService(auth: MockFirebaseAuth(signedIn: true)),
        userRepository: UserRepository(
          firestore: firestore,
          destinationRepository: DestinationRepository(firestore: firestore),
        ),
        // Otherwise its admin-status stream opens against the real (absent)
        // Firestore and fails the test from outside the widget tree.
        adminRepository: AdminRepository(firestore: firestore),
      ),
      child: app,
    );
  }

  Widget screen() => AdminTouristSpotListScreen(
        provinceRepository: ProvinceRepository(firestore: firestore),
        destinationRepository: DestinationRepository(firestore: firestore),
        adminRepository: AdminRepository(firestore: firestore),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  layoutMatrix(
    'Admin: tourist spots, province picker',
    screen,
    wrap: withAuth,
    setup: seed,
    act: settle,
    verify: (_) => expect(find.textContaining('Province of Camarines'), findsWidgets),
  );

  layoutMatrix(
    'Admin: tourist spots, province picked',
    screen,
    wrap: withAuth,
    setup: seed,
    act: (tester) async {
      await settle(tester);
      final province = find.textContaining('A Province of Camarines');
      await tester.ensureVisible(province);
      await tester.pump();
      await tester.tap(province);
      await settle(tester);
    },
    verify: (_) => expect(find.textContaining('Alona Beach'), findsWidgets),
  );
}
