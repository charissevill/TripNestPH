import 'package:cloud_firestore/cloud_firestore.dart';

/// One logged spend against a saved itinerary's budget, persisted at
/// `saved_itineraries/{id}/expenses/{expenseId}`.
class Expense {
  const Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.note,
    required this.loggedBy,
    required this.createdAt,
    this.splitBetween = const [],
  });

  final String id;

  /// Matches a [BudgetItem.label] from the itinerary's budget breakdown when
  /// possible, so actual spend can be compared category-by-category. Falls
  /// back to a free-text category the user typed for anything uncategorized.
  final String category;
  final double amount;
  final String note;

  /// Uid of whoever logged it — the owner or a collaborator.
  final String loggedBy;
  final DateTime createdAt;

  /// Uids of the trip members this expense is split between. Empty means
  /// "split between everyone on the trip" — both the default for a solo
  /// traveler and the fallback for expenses logged before per-companion
  /// splitting existed.
  final List<String> splitBetween;

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    final timestamp = map['createdAt'];
    return Expense(
      id: id,
      category: map['category'] as String? ?? 'Other',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      note: map['note'] as String? ?? '',
      loggedBy: map['loggedBy'] as String? ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      splitBetween: List<String>.from(map['splitBetween'] as List? ?? const []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'amount': amount,
      'note': note,
      'loggedBy': loggedBy,
      'createdAt': FieldValue.serverTimestamp(),
      'splitBetween': splitBetween,
    };
  }
}
