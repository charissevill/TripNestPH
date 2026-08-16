import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/presentation/admin/admin_analytics_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('shows real counts from every seeded collection', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').add({'status': 'active'});
    await firestore.collection('users').add({'status': 'active'});
    await firestore.collection('users').add({'status': 'suspended'});
    await firestore.collection('tourist_spots').add({
      'name': 'Alona Beach',
      'status': 'published',
      'provinceName': 'Bohol',
      'reviewCount': 10,
    });
    await firestore.collection('provinces').add({
      'name': 'Bohol',
      'hasContent': true,
    });
    await firestore.collection('provinces').add({
      'name': 'Cebu',
      'hasContent': false,
    });
    await firestore.collection('businesses').add({
      'ownerId': 'owner-1',
      'status': 'pending',
    });
    await firestore.collection('saved_itineraries').add({'userId': 'user-1'});

    await tester.pumpWidget(_wrap(AdminAnalyticsScreen(firestore: firestore)));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget); // Total Travelers
    expect(
      find.text('1'),
      findsAtLeastNWidgets(1),
    ); // Suspended / published spot / etc.
    expect(find.text('1/2'), findsOneWidget); // Provinces w/ Content

    // "Most Popular Destinations" sits below the fold in the test
    // viewport — scroll it into the built element tree before asserting.
    await tester.scrollUntilVisible(
      find.text('Alona Beach'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Alona Beach'), findsOneWidget);
  });

  testWidgets('shows the traveler-growth trend chart once at least 2 daily snapshots exist', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('analytics_snapshots').doc('2026-01-01').set({'date': '2026-01-01', 'travelerCount': 10});
    await firestore.collection('analytics_snapshots').doc('2026-01-02').set({'date': '2026-01-02', 'travelerCount': 15});

    await tester.pumpWidget(_wrap(AdminAnalyticsScreen(firestore: firestore)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Traveler Growth'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Traveler Growth'), findsOneWidget);
    expect(find.text('Total signed-up travelers, last 2 days'), findsOneWidget);
  });

  testWidgets('hides the trend chart when fewer than 2 daily snapshots exist', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('analytics_snapshots').doc('2026-01-01').set({'date': '2026-01-01', 'travelerCount': 10});

    await tester.pumpWidget(_wrap(AdminAnalyticsScreen(firestore: firestore)));
    await tester.pumpAndSettle();

    expect(find.text('Traveler Growth'), findsNothing);
  });

  testWidgets('shows zero stats gracefully when every collection is empty', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();

    await tester.pumpWidget(_wrap(AdminAnalyticsScreen(firestore: firestore)));
    await tester.pumpAndSettle();

    expect(find.text('0'), findsAtLeastNWidgets(1));
    expect(find.text('0/0'), findsOneWidget);
  });
}
