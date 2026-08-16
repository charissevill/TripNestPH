import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/province.dart';

/// Firestore access for the `provinces` collection (83 docs: 82 real
/// provinces + the `metro-manila` NCR pseudo-province) and each province's
/// on-demand `cities` subcollection.
///
/// [getAll] replaces the old per-content-collection `distinctProvinces()`
/// scans (deleted from `DestinationRepository`/`RestaurantRepository`/
/// `FestivalRepository`) — those did a full unfiltered read of every
/// destination/restaurant/festival just to dedupe province names, which
/// grows unboundedly with content. This is a single bounded 83-doc read
/// that never grows, structurally decoupled from content volume.
class ProvinceRepository {
  ProvinceRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection(FirestorePaths.provinces);

  Future<List<Province>> getAll() async {
    try {
      final snapshot = await _collection.get();
      return snapshot.docs.map((d) => Province.fromMap(d.id, d.data())).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Province?> getById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) return null;
      return Province.fromMap(doc.id, doc.data()!);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Province>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      // Firestore whereIn supports at most 30 values per query.
      final chunks = <List<String>>[];
      for (var i = 0; i < ids.length; i += 30) {
        chunks.add(ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30));
      }
      final results = <Province>[];
      for (final chunk in chunks) {
        final snapshot = await _collection.where(FieldPath.documentId, whereIn: chunk).get();
        results.addAll(snapshot.docs.map((d) => Province.fromMap(d.id, d.data())));
      }
      return results;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Admin/LGU Portal write: updates a province's page content (overview,
  /// culture, budget, tips, hotlines, hero image) and flips [hasContent] to
  /// true — the in-app path that turns a "content coming soon" province
  /// into a real one, matching `firestore.rules`'s
  /// `hasAdminRole(['admin', 'lgu'])` update permission (no field
  /// restriction, so a plain field-map update is rules-compliant).
  Future<void> updateContent(
    String provinceId, {
    required String overview,
    required String localCulture,
    List<CultureNote> cultureNotes = const [],
    List<TransportNote> localTransport = const [],
    required String bestTimeToVisit,
    required double estimatedDailyBudgetMin,
    required double estimatedDailyBudgetMax,
    required List<String> travelTips,
    required List<EmergencyHotline> emergencyHotlines,
    required String heroImageUrl,
    required List<String> galleryImageUrls,
  }) async {
    try {
      await _collection.doc(provinceId).update({
        'hasContent': true,
        'overview': overview,
        'localCulture': localCulture,
        'cultureNotes': cultureNotes.map((n) => n.toMap()).toList(),
        'localTransport': localTransport.map((n) => n.toMap()).toList(),
        'bestTimeToVisit': bestTimeToVisit,
        'estimatedDailyBudgetMin': estimatedDailyBudgetMin,
        'estimatedDailyBudgetMax': estimatedDailyBudgetMax,
        'travelTips': travelTips,
        'emergencyHotlines': emergencyHotlines.map((h) => h.toMap()).toList(),
        'heroImageUrl': heroImageUrl,
        'galleryImageUrls': galleryImageUrls,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Upserts `provinces/{provinceId}/cities/{cityId}` — the on-demand path
  /// for registering a city the first time content references it, rather
  /// than pre-seeding the ~1,634 PH cities/municipalities upfront. Looks up
  /// the parent province to denormalize `regionId` onto the city doc, same
  /// as every content model does.
  Future<void> ensureCity(String provinceId, String cityId, String name) async {
    try {
      final province = await getById(provinceId);
      await _collection.doc(provinceId).collection(FirestorePaths.cities).doc(cityId).set(
        City(id: cityId, name: name, provinceId: provinceId, regionId: province?.regionId ?? '').toMap(),
        SetOptions(merge: true),
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
