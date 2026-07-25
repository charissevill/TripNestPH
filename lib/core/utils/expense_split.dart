import '../../domain/models/expense.dart';

/// Who [expense] is split between. An empty [Expense.splitBetween] means
/// "everyone on the trip" — the default for a solo traveler, and the
/// fallback for expenses logged before per-companion splitting existed.
List<String> effectiveSplit(Expense expense, List<String> allMemberIds) =>
    expense.splitBetween.isEmpty ? allMemberIds : expense.splitBetween;

/// Net balance per trip member across every logged [expenses]: how much
/// each one paid, minus their fair share of every expense they were part
/// of. Positive means the group still owes them back; negative means they
/// still owe the group. Settles to ~0 once everyone's paid their share.
Map<String, double> netBalances(List<String> allMemberIds, List<Expense> expenses) {
  final memberSet = allMemberIds.toSet();
  final balances = {for (final id in allMemberIds) id: 0.0};
  for (final expense in expenses) {
    final split = effectiveSplit(expense, allMemberIds);
    if (split.isEmpty) continue;
    // Divide by everyone the expense was split with, but only ever credit
    // or debit an actual trip member — a stray uid in splitBetween (e.g.
    // someone who's since left the trip) still counts toward the divisor
    // for fairness, it just can't accrue a balance of its own.
    final share = expense.amount / split.length;
    for (final id in split) {
      if (!memberSet.contains(id)) continue;
      balances[id] = (balances[id] ?? 0) - share;
    }
    if (memberSet.contains(expense.loggedBy)) {
      balances[expense.loggedBy] = (balances[expense.loggedBy] ?? 0) + expense.amount;
    }
  }
  return balances;
}
