import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/data/repositories/destination_repository.dart';
import 'package:tripnest_ph/data/repositories/user_repository.dart';
import 'package:tripnest_ph/presentation/admin/admin_user_management_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

// `UserRepository`'s default `destinationRepository` param would otherwise
// eagerly construct an un-overridden `DestinationRepository()`, whose own
// field initializer touches `FirebaseFirestore.instance` synchronously —
// that throws under `flutter test` with no real Firebase app registered.
UserRepository _userRepository(FakeFirebaseFirestore firestore) =>
    UserRepository(
      firestore: firestore,
      destinationRepository: DestinationRepository(firestore: firestore),
    );

void main() {
  testWidgets('lists travelers and suspends one after confirmation', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final repository = _userRepository(firestore);
    await repository.createIfMissing(
      uid: 'user-1',
      name: 'Juan Dela Cruz',
      email: 'juan@example.com',
    );

    await tester.pumpWidget(
      _wrap(AdminUserManagementScreen(userRepository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('juan@example.com'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suspend'));
    await tester.pumpAndSettle();

    expect(find.text('Suspend this account?'), findsOneWidget);
    await tester.tap(find.text('Suspend').last);
    await tester.pumpAndSettle();

    final updated = await repository.getUser('user-1');
    expect(updated!.isSuspended, isTrue);
    expect(find.text('juan@example.com · suspended'), findsOneWidget);
  });

  testWidgets('filters the list by name or email as the admin types', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final repository = _userRepository(firestore);
    await repository.createIfMissing(
      uid: 'user-1',
      name: 'Juan Dela Cruz',
      email: 'juan@example.com',
    );
    await repository.createIfMissing(
      uid: 'user-2',
      name: 'Maria Santos',
      email: 'maria@example.com',
    );

    await tester.pumpWidget(
      _wrap(AdminUserManagementScreen(userRepository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('Maria Santos'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'maria');
    await tester.pumpAndSettle();

    expect(find.text('Juan Dela Cruz'), findsNothing);
    expect(find.text('Maria Santos'), findsOneWidget);
  });

  testWidgets('cancelling the suspend dialog leaves the account active', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final repository = _userRepository(firestore);
    await repository.createIfMissing(
      uid: 'user-1',
      name: 'Juan Dela Cruz',
      email: 'juan@example.com',
    );

    await tester.pumpWidget(
      _wrap(AdminUserManagementScreen(userRepository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suspend'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final unchanged = await repository.getUser('user-1');
    expect(unchanged!.isSuspended, isFalse);
  });
}
