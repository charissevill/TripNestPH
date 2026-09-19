import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tripnest_ph/core/constants/legal_content.dart';
import 'package:tripnest_ph/core/providers/auth_provider.dart';
import 'package:tripnest_ph/core/services/auth_service.dart';
import 'package:tripnest_ph/data/repositories/destination_repository.dart';
import 'package:tripnest_ph/data/repositories/user_repository.dart';
import 'package:tripnest_ph/presentation/auth/forgot_password_screen.dart';
import 'package:tripnest_ph/presentation/auth/login_screen.dart';
import 'package:tripnest_ph/presentation/auth/register_screen.dart';
import 'package:tripnest_ph/presentation/auth/verify_email_screen.dart';
import 'package:tripnest_ph/presentation/auth/widgets/role_choice_dialog.dart';
import 'package:tripnest_ph/presentation/onboarding/onboarding_screen.dart';
import 'package:tripnest_ph/presentation/settings/faq_screen.dart';
import 'package:tripnest_ph/presentation/settings/legal_info_screen.dart';
import 'package:tripnest_ph/presentation/settings/whats_new_screen.dart';
import 'package:tripnest_ph/presentation/splash/splash_screen.dart';

import '../support/fake_image_http_overrides.dart';
import 'layout_harness.dart';

/// Responsive-layout regression matrix for the auth flow and static screens:
/// every screen/dialog is pumped at phone/tablet/desktop sizes in portrait
/// and landscape, at both ends of the in-app Text Size range, and must not
/// raise any overflow / unbounded-constraint error.
void main() {
  setUpAll(() {
    HttpOverrides.global = FakeImageHttpOverrides();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget withAuth(Widget child) {
    final firestore = FakeFirebaseFirestore();
    final auth = AuthProvider(
      authService: AuthService(auth: MockFirebaseAuth(signedIn: true)),
      userRepository: UserRepository(
        firestore: firestore,
        destinationRepository: DestinationRepository(firestore: firestore),
      ),
    );
    return ChangeNotifierProvider<AuthProvider>.value(value: auth, child: child);
  }

  layoutMatrix('Splash', () => const SplashScreen(), wrap: withAuth);
  layoutMatrix('Onboarding', () => const OnboardingScreen(), wrap: withAuth);
  layoutMatrix('Login', () => const LoginScreen(), wrap: withAuth);
  layoutMatrix('Register', () => const RegisterScreen(), wrap: withAuth);
  layoutMatrix('Register (business)', () => const RegisterScreen(wantsBusinessOwner: true), wrap: withAuth);
  layoutMatrix('Forgot password', () => const ForgotPasswordScreen(), wrap: withAuth);
  layoutMatrix('Verify email', () => const VerifyEmailScreen(), wrap: withAuth);
  layoutMatrix('Legal: terms', () => const LegalInfoScreen(topicKey: 'terms'));
  layoutMatrix('Legal: privacy', () => const LegalInfoScreen(topicKey: 'privacy'));
  layoutMatrix('Legal: about', () => const LegalInfoScreen(topicKey: 'about'));
  layoutMatrix('FAQ', () => const FaqScreen(items: LegalContent.faq));
  layoutMatrix('Whats new', () => const WhatsNewScreen());
  layoutMatrix(
    'Role choice dialog',
    () => Builder(
      builder: (context) => Scaffold(
        body: TextButton(onPressed: () => showRoleChoiceDialog(context), child: const Text('open')),
      ),
    ),
    act: (tester) => tester.tap(find.text('open')),
  );
}
