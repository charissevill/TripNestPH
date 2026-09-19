import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tripnest_ph/data/repositories/destination_repository.dart';
import 'package:tripnest_ph/data/repositories/province_repository.dart';
import 'package:tripnest_ph/data/repositories/user_repository.dart';
import 'package:tripnest_ph/presentation/admin/admin_analytics_screen.dart';
import 'package:tripnest_ph/presentation/admin/admin_bulk_province_content_screen.dart';
import 'package:tripnest_ph/presentation/admin/admin_user_management_screen.dart';

import '../support/fake_image_http_overrides.dart';
import 'layout_harness.dart';

/// The admin screens that accept injected repositories (the rest build their
/// own Firestore-backed repositories and can't run without a live Firebase
/// app), pumped with data long enough to stress the rows and tables.
void main() {
  setUpAll(() {
    HttpOverrides.global = FakeImageHttpOverrides();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final firestore = FakeFirebaseFirestore();
  var seeded = false;

  Future<void> seed() async {
    if (seeded) return;
    seeded = true;
    final users = UserRepository(
      firestore: firestore,
      destinationRepository: DestinationRepository(firestore: firestore),
    );
    for (var i = 0; i < 12; i++) {
      await users.createIfMissing(
        uid: 'user-$i',
        name: 'Juan Dela Cruz de la Santísima Trinidad the ${i}th',
        email: 'juan.dela.cruz.with.a.very.long.email.address.$i@example-organisation.com.ph',
      );
    }
    for (var i = 0; i < 20; i++) {
      await firestore.collection('provinces').doc('prov$i').set({
        'name': 'Province of Camarines Norte and Sur Number $i',
        'regionId': 'region-$i',
        'regionName': 'Central Visayas and Some Extra Long Region Name',
        'islandGroup': 'Visayas',
        'hasContent': i.isEven,
      });
    }
    await firestore.collection('users').add({'status': 'active'});
    await firestore.collection('users').add({'status': 'suspended'});
    for (var i = 0; i < 8; i++) {
      await firestore.collection('tourist_spots').add({
        'name': 'Alona Beach and Panglao Island Marine Sanctuary Number $i',
        'status': 'published',
        'provinceName': 'Bohol',
        'reviewCount': 10 + i,
      });
    }
    await firestore.collection('businesses').add({'ownerId': 'owner-1', 'status': 'pending'});
    await firestore.collection('analytics_snapshots').doc('2026-01-01').set({'date': '2026-01-01', 'travelerCount': 10});
    await firestore.collection('analytics_snapshots').doc('2026-01-02').set({'date': '2026-01-02', 'travelerCount': 15});
  }

  layoutMatrix(
    'Admin: travelers',
    () => AdminUserManagementScreen(
      userRepository: UserRepository(
        firestore: firestore,
        destinationRepository: DestinationRepository(firestore: firestore),
      ),
    ),
    setup: seed,
    act: (tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    },
    verify: (_) => expect(find.textContaining('Juan Dela Cruz'), findsWidgets),
  );

  layoutMatrix(
    'Admin: bulk province content',
    () => AdminBulkProvinceContentScreen(provinceRepository: ProvinceRepository(firestore: firestore)),
    setup: seed,
    act: (tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    },
  );

  layoutMatrix(
    'Admin: analytics',
    () => AdminAnalyticsScreen(firestore: firestore),
    setup: seed,
    act: (tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    },
  );
}
