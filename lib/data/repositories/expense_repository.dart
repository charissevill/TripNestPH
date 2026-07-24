import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/expense.dart';

/// Firestore access for a saved itinerary's `expenses` subcollection —
/// actual spend logged against its AI-generated budget breakdown.
class ExpenseRepository {
  ExpenseRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _collection(String itineraryId) => _db
      .collection(FirestorePaths.savedItineraries)
      .doc(itineraryId)
      .collection(FirestorePaths.expenses);

  Stream<List<Expense>> streamForItinerary(String itineraryId) {
    return _collection(itineraryId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Expense.fromMap(d.id, d.data())).toList());
  }

  Future<void> add({
    required String itineraryId,
    required String category,
    required double amount,
    required String note,
    required String loggedBy,
  }) async {
    try {
      await _collection(itineraryId).add(
        Expense(
          id: '',
          category: category,
          amount: amount,
          note: note,
          loggedBy: loggedBy,
          createdAt: DateTime.now(),
        ).toMap(),
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> delete({required String itineraryId, required String expenseId}) async {
    try {
      await _collection(itineraryId).doc(expenseId).delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
