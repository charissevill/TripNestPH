import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
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

/// Pumps in bounded increments rather than `pumpAndSettle()`. Screens with
/// network images never reach a strict zero-pending-frames state inside the
/// test harness even though nothing is actually broken, so a fixed settle
/// window is the correct tool here (see Phase 1's golden path test for the
/// full explanation of why).
Future<void> _settle(WidgetTester tester, [int steps = 20]) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = FakeImageHttpOverrides();
  });

  testWidgets(
    'splash -> onboarding -> unauthenticated redirect to login -> register -> verify email',
    (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      // A fresh, signed-out mock auth session backed by an in-memory
      // Firestore fake — the whole test never touches the real project.
      final mockAuth = MockFirebaseAuth(verifyEmailAutomatically: false);
      final firestore = FakeFirebaseFirestore();
      final authProvider = AuthProvider(
        authService: AuthService(auth: mockAuth),
        userRepository: UserRepository(firestore: firestore, destinationRepository: DestinationRepository(firestore: firestore)),
      );
      final favoritesProvider = FavoritesProvider(repository: FavoritesRepository(firestore: firestore));

      await tester.pumpWidget(TripNestApp(authProvider: authProvider, favoritesProvider: favoritesProvider));
      await tester.pump();
      expect(find.byType(AppLogo), findsOneWidget);

      // Splash auto-navigates to Onboarding after ~2.2s.
      await tester.pump(const Duration(milliseconds: 2300));
      await _settle(tester);
      expect(find.text('Skip'), findsOneWidget);

      // Tapping "Skip" targets Home, but the router redirect must catch
      // this: nobody is signed in yet, so it should land on Login instead.
      await tester.tap(find.text('Skip'));
      await _settle(tester);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);

      // Move to Register.
      await tester.tap(find.text('Sign Up'));
      await _settle(tester);
      expect(find.text('Create your account'), findsOneWidget);

      // Fill out and submit the registration form (First Name, Last Name,
      // Email, Password, Confirm Password).
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Alex');
      await tester.enterText(fields.at(1), 'Traveler');
      await tester.enterText(fields.at(2), 'alex.traveler@example.com');
      await tester.enterText(fields.at(3), 'supersecret1');
      await tester.enterText(fields.at(4), 'supersecret1');
      await _settle(tester, 2);

      await tester.tap(find.text('Create Account'));
      await _settle(tester);

      // A brand-new email/password account is unverified, so the router
      // redirect must land on Verify Email rather than Home.
      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.textContaining('alex.traveler@example.com'), findsOneWidget);

      // Resending the verification email should succeed silently (the mock
      // user's sendEmailVerification is a no-op) and show the confirmation.
      await tester.tap(find.text('Resend Email'));
      await _settle(tester);
      expect(find.text('Verification email resent.'), findsOneWidget);
    },
  );
}
