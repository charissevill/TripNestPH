import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/travel_tip.dart';

/// Firestore access for the `travel_tips` collection shown on Home and
/// Details screens.
class TravelTipRepository {
  TravelTipRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection(FirestorePaths.travelTips);

  Future<List<TravelTip>> getAll({int limit = 20}) async {
    try {
      final snapshot = await _collection.limit(limit).get();
      return snapshot.docs.map((d) => TravelTip.fromMap(d.id, d.data())).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
