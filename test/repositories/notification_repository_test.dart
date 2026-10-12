import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/data/repositories/notification_repository.dart';
import 'package:tripnest_ph/domain/models/app_notification.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late NotificationRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = NotificationRepository(firestore: firestore);
  });

  Future<void> seed(String id, {required String userId}) {
    return firestore.collection('notifications').doc(id).set({
      'userId': userId,
      'title': 'Title $id',
      'body': 'Body $id',
      'category': 'general',
      'isRead': false,
    });
  }

  Future<List<String>> idsFor(String uid) async {
    final notifications = await repository.streamForUser(uid).first;
    return notifications.map((n) => n.id).toList()..sort();
  }

  test('streamForUser() merges the user\'s own notifications with broadcasts', () async {
    await seed('mine', userId: 'user-1');
    await seed('theirs', userId: 'user-2');
    await seed('broadcast', userId: '');

    expect(await idsFor('user-1'), ['broadcast', 'mine']);
  });

  test('delete() removes a personal notification outright', () async {
    await seed('mine', userId: 'user-1');
    final notification = (await repository.streamForUser('user-1').first).single;

    await repository.delete(notification, 'user-1');

    final remaining = await firestore.collection('notifications').get();
    expect(remaining.docs, isEmpty);
  });

  test('delete() hides a broadcast for that user only, keeping the shared doc', () async {
    await seed('broadcast', userId: '');
    final notification = (await repository.streamForUser('user-1').first).single;

    await repository.delete(notification, 'user-1');

    final doc = await firestore.collection('notifications').doc('broadcast').get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['dismissedBy'], ['user-1']);
    expect(await idsFor('user-1'), isEmpty);
    expect(await idsFor('user-2'), ['broadcast']);
  });

  test('deleteAll() clears personal and broadcast notifications in one go', () async {
    await seed('mine-1', userId: 'user-1');
    await seed('mine-2', userId: 'user-1');
    await seed('broadcast', userId: '');
    await seed('theirs', userId: 'user-2');

    await repository.deleteAll(await repository.streamForUser('user-1').first, 'user-1');

    expect(await idsFor('user-1'), isEmpty);
    expect(await idsFor('user-2'), ['broadcast', 'theirs']);
  });

  test('createProvinceAnnouncement() queues a province announcement, not a nationwide broadcast', () async {
    await repository.createProvinceAnnouncement(
      provinceId: 'bulacan',
      provinceName: 'Bulacan',
      createdBy: 'lgu-1',
      title: 'Road closure',
      body: 'Paseo del Congreso is closed for the parade.',
      category: NotificationCategory.general,
    );

    final announcement = (await firestore.collection('province_announcements').get()).docs.single.data();
    expect(announcement['provinceId'], 'bulacan');
    expect(announcement['createdBy'], 'lgu-1');
    expect(announcement['title'], 'Road closure');
    expect(announcement['category'], 'general');
    // Nothing lands in any traveler's bell until the Cloud Function delivers it.
    expect((await firestore.collection('notifications').get()).docs, isEmpty);
    expect(await idsFor('user-1'), isEmpty);
  });

  test('streamForUser() emits again once a broadcast is deleted, without a personal change', () async {
    await seed('broadcast', userId: '');
    final events = <List<AppNotification>>[];
    final sub = repository.streamForUser('user-1').listen(events.add);
    await Future<void>.delayed(Duration.zero);

    await repository.delete(events.last.single, 'user-1');
    await Future<void>.delayed(Duration.zero);

    expect(events.last, isEmpty);
    await sub.cancel();
  });
}
