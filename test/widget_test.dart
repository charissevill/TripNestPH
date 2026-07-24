import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/providers/auth_provider.dart';
import 'package:tripnest_ph/core/providers/favorites_provider.dart';
import 'package:tripnest_ph/core/services/auth_service.dart';
import 'package:tripnest_ph/data/repositories/destination_repository.dart';
import 'package:tripnest_ph/data/repositories/favorites_repository.dart';
import 'package:tripnest_ph/core/widgets/branding/app_logo.dart';
import 'package:tripnest_ph/data/repositories/user_repository.dart';
import 'package:tripnest_ph/main.dart';

import 'support/fake_image_http_overrides.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = FakeImageHttpOverrides();
  });

  testWidgets('App boots to the splash screen', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final authProvider = AuthProvider(
      authService: AuthService(auth: MockFirebaseAuth()),
      userRepository: UserRepository(firestore: firestore, destinationRepository: DestinationRepository(firestore: firestore)),
    );
    final favoritesProvider = FavoritesProvider(repository: FavoritesRepository(firestore: firestore));

    await tester.pumpWidget(TripNestApp(authProvider: authProvider, favoritesProvider: favoritesProvider));
    await tester.pump();

    expect(find.byType(AppLogo), findsOneWidget);

    // Let the splash screen's auto-navigation timer fire and settle so no
    // Timer is left pending when the test tears down.
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();
  });
}
