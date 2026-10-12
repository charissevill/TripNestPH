import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
// The mock helpers live in firebase_core's own platform interface package.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripnest_ph/data/repositories/admin_repository.dart';
import 'package:tripnest_ph/data/repositories/business_owner_application_repository.dart';
import 'package:tripnest_ph/data/repositories/notification_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late BusinessOwnerApplicationRepository repository;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // AdminRepository reaches for FirebaseFunctions as soon as it's built.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = BusinessOwnerApplicationRepository(
      firestore: firestore,
      adminRepository: AdminRepository(firestore: firestore),
      notificationRepository: NotificationRepository(firestore: firestore),
    );
  });

  Future<void> seed(String id, {required String userId, required String status, required DateTime createdAt}) {
    return firestore.collection('business_owner_applications').doc(id).set({
      'userId': userId,
      'businessName': 'Business $id',
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    });
  }

  test('getLatestApprovedForUser() returns the newest approved application of that user only', () async {
    await seed('old', userId: 'owner-1', status: 'approved', createdAt: DateTime(2026, 1, 1));
    await seed('new', userId: 'owner-1', status: 'approved', createdAt: DateTime(2026, 3, 1));
    await seed('rejected', userId: 'owner-1', status: 'rejected', createdAt: DateTime(2026, 5, 1));
    await seed('pending', userId: 'owner-1', status: 'pending', createdAt: DateTime(2026, 6, 1));
    await seed('someone-else', userId: 'owner-2', status: 'approved', createdAt: DateTime(2026, 7, 1));

    final application = await repository.getLatestApprovedForUser('owner-1');

    expect(application?.id, 'new');
  });

  test('getLatestApprovedForUser() is null when nothing of theirs is approved', () async {
    await seed('pending', userId: 'owner-1', status: 'pending', createdAt: DateTime(2026, 1, 1));
    await seed('someone-else', userId: 'owner-2', status: 'approved', createdAt: DateTime(2026, 2, 1));

    expect(await repository.getLatestApprovedForUser('owner-1'), isNull);
  });

  test('approve() grants businessOwner directly, with no invite left to accept', () async {
    await firestore.collection('business_owner_applications').doc('app-1').set({
      'userId': 'owner-1',
      'applicantName': 'Maria Santos',
      'applicantEmail': 'Maria@Example.com',
      'businessName': 'Kusina ni Maria',
      'status': 'pending',
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    final application = (await repository.streamPendingForAdmin().first).single;

    await repository.approve(application);

    final adminUser = await firestore.collection('admin_users').doc('owner-1').get();
    expect(adminUser.data()?['role'], 'businessOwner');
    expect(adminUser.data()?['status'], 'active');
    expect(adminUser.data()?['name'], 'Maria Santos');
    expect((await firestore.collection('admin_invites').get()).docs, isEmpty);
    expect((await repository.getLatestApprovedForUser('owner-1'))?.id, 'app-1');
  });

  test('approve() leaves an existing Admin Portal account as it is', () async {
    await firestore.collection('admin_users').doc('owner-1').set({'role': 'lgu', 'status': 'active'});
    await seed('app-1', userId: 'owner-1', status: 'pending', createdAt: DateTime(2026, 1, 1));
    final application = (await repository.streamPendingForAdmin().first).single;

    await repository.approve(application);

    final adminUser = await firestore.collection('admin_users').doc('owner-1').get();
    expect(adminUser.data()?['role'], 'lgu');
  });
}
