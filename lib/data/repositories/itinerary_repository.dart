import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/itinerary.dart';
import '../../domain/models/packing_item.dart';
import '../../domain/models/saved_itinerary.dart';

/// Firestore access for the `saved_itineraries` collection — the trips a
/// user has saved from the AI/trip planner.
class ItineraryRepository {
  ItineraryRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection(FirestorePaths.savedItineraries);

  /// Trips [userId] owns, plus trips they joined as a collaborator, merged
  /// and sorted newest-first. Either side updating in real time refreshes
  /// the merged list. Waits for both the owned and shared queries to report
  /// at least once before emitting, so the first value is always the full
  /// picture rather than momentarily missing whichever side loads slower.
  Stream<List<SavedItinerary>> streamForUser(String userId) {
    final owned = _collection.where('userId', isEqualTo: userId).snapshots();
    final shared = _collection.where('collaboratorIds', arrayContains: userId).snapshots();

    var ownedDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    var sharedDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    var hasOwned = false;
    var hasShared = false;

    late StreamController<List<SavedItinerary>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? ownedSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sharedSub;

    void emit() {
      if (!hasOwned || !hasShared) return;
      final merged = {...ownedDocs, ...sharedDocs};
      final list = merged.values.map((d) => SavedItinerary.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
      controller.add(list);
    }

    controller = StreamController<List<SavedItinerary>>(
      onListen: () {
        ownedSub = owned.listen((snapshot) {
          ownedDocs = {for (final d in snapshot.docs) d.id: d};
          hasOwned = true;
          emit();
        }, onError: controller.addError);
        sharedSub = shared.listen((snapshot) {
          sharedDocs = {for (final d in snapshot.docs) d.id: d};
          hasShared = true;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await ownedSub?.cancel();
        await sharedSub?.cancel();
      },
    );
    return controller.stream;
  }

  Future<SavedItinerary?> getById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) return null;
      return SavedItinerary.fromMap(doc.id, doc.data()!);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<String> save({
    required String userId,
    required String title,
    required Itinerary itinerary,
    DateTime? startDate,
    String ownerName = '',
  }) async {
    try {
      final doc = await _collection.add(
        SavedItinerary(
          id: '',
          userId: userId,
          title: title,
          itinerary: itinerary,
          savedAt: DateTime.now(),
          memberNames: ownerName.isEmpty ? const {} : {userId: ownerName},
          packingItems: PackingItem.defaults(),
          startDate: startDate,
        ).toMap(),
      );
      return doc.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Sets or clears (pass `null`) the trip's actual travel start date —
  /// separate from when it was bookmarked. Owner-only, enforced by rules.
  Future<void> updateStartDate(String itineraryId, DateTime? startDate) async {
    try {
      await _collection.doc(itineraryId).update({
        'startDate': startDate != null ? Timestamp.fromDate(startDate) : null,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Clones [sourceId] into a brand-new saved trip for [userId] — same
  /// itinerary content, a fresh id/savedAt, no collaborators or start date
  /// carried over (a plain `save()`, just sourced from an existing trip
  /// instead of a freshly generated one). Returns the new trip's id.
  Future<String> duplicate(String sourceId, String userId, {String ownerName = ''}) async {
    final source = await getById(sourceId);
    if (source == null) {
      throw const AppException('This trip is no longer available.');
    }
    return save(userId: userId, title: '${source.title} (Copy)', itinerary: source.itinerary, ownerName: ownerName);
  }

  Future<void> delete(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Joins a shared trip using its id as the share code. Only ever adds the
  /// caller's own uid — enforced again server-side by Firestore rules. Also
  /// tags the joiner's own display name into `memberNames` (their own entry
  /// only) so the owner can see who's who in the Budget Tracker without
  /// needing read access to anyone else's `users/{uid}` profile.
  Future<void> joinAsCollaborator({required String itineraryId, required String userId, String userName = ''}) async {
    try {
      final update = <String, dynamic>{
        'collaboratorIds': FieldValue.arrayUnion([userId]),
      };
      if (userName.isNotEmpty) update['memberNames.$userId'] = userName;
      await _collection.doc(itineraryId).update(update);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Leaves a shared trip. Owners can't leave their own trip — they delete
  /// it instead.
  Future<void> leaveTrip({required String itineraryId, required String userId}) async {
    try {
      await _collection.doc(itineraryId).update({
        'collaboratorIds': FieldValue.arrayRemove([userId]),
        'memberNames.$userId': FieldValue.delete(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> updatePackingItems(String itineraryId, List<PackingItem> items) async {
    try {
      await _collection.doc(itineraryId).update({'packingItems': items.map((p) => p.toMap()).toList()});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Removes every itinerary [userId] has saved — part of the
  /// account-deletion flow.
  Future<void> deleteAllForUser(String userId) async {
    try {
      final snapshot = await _collection.where('userId', isEqualTo: userId).get();
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
