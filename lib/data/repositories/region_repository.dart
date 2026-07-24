import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/region.dart';

/// Firestore access for the `regions` collection — a small, fixed
/// 17-document reference list, always loaded in full rather than paginated
/// or filtered (see [ProvinceRepository] for the same reasoning at the
/// province tier).
class RegionRepository {
  RegionRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection(FirestorePaths.regions);

  Future<List<Region>> getAll() async {
    try {
      final snapshot = await _collection.get();
      return snapshot.docs.map((d) => Region.fromMap(d.id, d.data())).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
