import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/utils/expense_split.dart';
import 'package:tripnest_ph/domain/models/expense.dart';

Expense _expense({required double amount, required String loggedBy, List<String> splitBetween = const []}) {
  return Expense(
    id: 'e',
    category: 'Food',
    amount: amount,
    note: '',
    loggedBy: loggedBy,
    createdAt: DateTime(2026),
    splitBetween: splitBetween,
  );
}

void main() {
  group('effectiveSplit()', () {
    test('falls back to every trip member when splitBetween is empty', () {
      final expense = _expense(amount: 300, loggedBy: 'a');
      expect(effectiveSplit(expense, ['a', 'b', 'c']), ['a', 'b', 'c']);
    });

    test('uses the explicit list when splitBetween is set', () {
      final expense = _expense(amount: 300, loggedBy: 'a', splitBetween: ['a', 'b']);
      expect(effectiveSplit(expense, ['a', 'b', 'c']), ['a', 'b']);
    });
  });

  group('netBalances()', () {
    test('a single payer splitting equally with one other member: payer is owed half', () {
      final expenses = [_expense(amount: 1000, loggedBy: 'a', splitBetween: ['a', 'b'])];

      final balances = netBalances(['a', 'b'], expenses);

      expect(balances['a'], 500);
      expect(balances['b'], -500);
    });

    test('an expense split among everyone (empty splitBetween) divides by all trip members', () {
      final expenses = [_expense(amount: 900, loggedBy: 'a')];

      final balances = netBalances(['a', 'b', 'c'], expenses);

      expect(balances['a'], closeTo(600, 0.01));
      expect(balances['b'], closeTo(-300, 0.01));
      expect(balances['c'], closeTo(-300, 0.01));
    });

    test('everyone paying their own share nets out to zero for all members', () {
      final expenses = [
        _expense(amount: 500, loggedBy: 'a', splitBetween: ['a', 'b']),
        _expense(amount: 500, loggedBy: 'b', splitBetween: ['a', 'b']),
      ];

      final balances = netBalances(['a', 'b'], expenses);

      expect(balances['a'], 0);
      expect(balances['b'], 0);
    });

    test('an expense split with someone outside the given member list ignores the outsider', () {
      final expenses = [_expense(amount: 200, loggedBy: 'a', splitBetween: ['a', 'stranger'])];

      final balances = netBalances(['a', 'b'], expenses);

      expect(balances['a'], 100);
      expect(balances.containsKey('stranger'), isFalse);
    });

    test('no expenses leaves every member settled at zero', () {
      final balances = netBalances(['a', 'b'], []);
      expect(balances, {'a': 0.0, 'b': 0.0});
    });
  });
}
