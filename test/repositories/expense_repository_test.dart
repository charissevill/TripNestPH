import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/data/repositories/expense_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ExpenseRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = ExpenseRepository(firestore: firestore);
  });

  test('add() creates an expense that streamForItinerary() picks up', () async {
    await repository.add(itineraryId: 'trip-1', category: 'Food', amount: 500, note: 'Lunch', loggedBy: 'user-1');

    final expenses = await repository.streamForItinerary('trip-1').first;

    expect(expenses, hasLength(1));
    expect(expenses.first.category, 'Food');
    expect(expenses.first.amount, 500);
    expect(expenses.first.loggedBy, 'user-1');
  });

  test('streamForItinerary() only returns expenses under that itinerary', () async {
    await repository.add(itineraryId: 'trip-1', category: 'Food', amount: 500, note: '', loggedBy: 'user-1');
    await repository.add(itineraryId: 'trip-2', category: 'Transport', amount: 200, note: '', loggedBy: 'user-1');

    final expenses = await repository.streamForItinerary('trip-1').first;

    expect(expenses, hasLength(1));
    expect(expenses.first.category, 'Food');
  });

  test('delete() removes the expense so streamForItinerary() no longer includes it', () async {
    await repository.add(itineraryId: 'trip-1', category: 'Food', amount: 500, note: '', loggedBy: 'user-1');
    final expenses = await repository.streamForItinerary('trip-1').first;

    await repository.delete(itineraryId: 'trip-1', expenseId: expenses.first.id);

    final remaining = await repository.streamForItinerary('trip-1').first;
    expect(remaining, isEmpty);
  });
}
