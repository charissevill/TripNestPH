import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:tripnest_ph/core/providers/auth_provider.dart';
import 'package:tripnest_ph/core/services/auth_service.dart';
import 'package:tripnest_ph/core/services/otp_service.dart';
import 'package:tripnest_ph/data/repositories/destination_repository.dart';
import 'package:tripnest_ph/data/repositories/user_repository.dart';
import 'package:tripnest_ph/presentation/auth/forgot_password_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('Resend code on the code step requests a second code without throwing', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final requested = <String>[];
    final firestore = FakeFirebaseFirestore();
    final auth = AuthProvider(
      authService: AuthService(auth: MockFirebaseAuth()),
      otpService: OtpService(caller: (name, data) async {
        requested.add(name);
        return {'success': true};
      }),
      userRepository: UserRepository(
        firestore: firestore,
        destinationRepository: DestinationRepository(firestore: firestore),
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: ForgotPasswordScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'tester01@example.com');
    await tester.tap(find.text('Send Code'));
    await _settle(tester);
    expect(find.text('Enter the code'), findsOneWidget);

    await tester.tap(find.text('Resend code'));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(requested, ['requestPasswordResetCode', 'requestPasswordResetCode']);
    expect(find.text('Enter the code'), findsOneWidget);
  });
}
