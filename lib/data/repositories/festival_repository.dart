import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/festival.dart';

/// Firestore access for the `festivals` collection.
class FestivalRepository {
  FestivalRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection(FirestorePaths.festivals);

  Festival _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) => Festival.fromMap(doc.id, doc.data());

  /// Every traveler-facing query filters to `status == 'published'` so
  /// content drafted in the Admin Portal never surfaces here — direct
  /// lookups (getById/getByIds) intentionally skip this filter.
  Query<Map<String, dynamic>> get _publishedOnly => _collection.where('status', isEqualTo: 'published');

  Future<List<Festival>> getUpcoming({int limit = 10}) => _query(
        _publishedOnly.where('isUpcoming', isEqualTo: true).limit(limit),
      );

  Future<({List<Festival> items, DocumentSnapshot<Map<String, dynamic>>? lastDoc})> getPage({
    int pageSize = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    try {
      var query = _publishedOnly.orderBy('name').limit(pageSize);
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snapshot = await query.get();
      return (
        items: snapshot.docs.map(_fromDoc).toList(),
        lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Festival?> getById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) return null;
      return Festival.fromMap(doc.id, doc.data()!);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Festival>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final snapshot = await _collection.where(FieldPath.documentId, whereIn: ids.take(30).toList()).get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Case-insensitive "starts with" search against the seeded `nameLower`
  /// field. The private-use codepoint U+F8FF sorts after ordinary text, so
  /// `[prefix, prefix + U+F8FF]` is the standard Firestore range-query
  /// idiom for a prefix match.
  Future<List<Festival>> searchByName(String query, {int limit = 20}) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];
    final rangeEnd = '$normalized';
    try {
      final snapshot = await _publishedOnly
          .orderBy('nameLower')
          .startAt([normalized])
          .endAt([rangeEnd])
          .limit(limit)
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Festival>> filter({String? provinceId, double? minRating, int limit = 30}) async {
    try {
      Query<Map<String, dynamic>> query = _publishedOnly;
      if (provinceId != null && provinceId.isNotEmpty) {
        query = query.where('provinceId', isEqualTo: provinceId);
      }
      if (minRating != null) {
        query = query.where('rating', isGreaterThanOrEqualTo: minRating);
      }
      final snapshot = await query.limit(limit).get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> updateAggregateRating(String id, {required double rating, required int reviewCount}) async {
    try {
      await _collection.doc(id).update({'rating': rating, 'reviewCount': reviewCount});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Every festival created by [uid] regardless of status — an
  /// `eventOrganizer` account's own "My Events" list.
  Future<List<Festival>> getAllForOwner(String uid) async {
    try {
      final snapshot = await _collection.where('organizerId', isEqualTo: uid).orderBy('name').get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Every festival regardless of status — the admin/LGU "Festivals"
  /// module, matching `DestinationRepository.getAllForProvinceAdmin`.
  Future<List<Festival>> getAllForAdmin() async {
    try {
      final snapshot = await _collection.orderBy('name').get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Admin/LGU/eventOrganizer write — matches `firestore.rules`'s
  /// `hasAdminRole(['admin','lgu'])` (unscoped) or eventOrganizer
  /// (organizerId-scoped) create permission. Published immediately, same
  /// no-draft-workflow precedent as `DestinationRepository.create`.
  Future<String> create(Festival festival) async {
    try {
      final doc = await _collection.add({
        ...festival.toMap(),
        'nameLower': festival.name.toLowerCase(),
        'status': 'published',
      });
      return doc.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> update(String id, Festival festival) async {
    try {
      await _collection.doc(id).update({
        ...festival.toMap(),
        'nameLower': festival.name.toLowerCase(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Festival>> _query(Query<Map<String, dynamic>> query) async {
    try {
      final snapshot = await query.get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
