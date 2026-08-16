import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/poll.dart';

/// Firestore access for a saved itinerary's `polls` subcollection — quick
/// group votes ("Which restaurant for Day 2?") among the trip's owner and
/// collaborators.
class PollRepository {
  PollRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _collection(String itineraryId) => _db
      .collection(FirestorePaths.savedItineraries)
      .doc(itineraryId)
      .collection(FirestorePaths.polls);

  Stream<List<Poll>> streamForItinerary(String itineraryId) {
    return _collection(itineraryId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Poll.fromMap(d.id, d.data())).toList());
  }

  Future<void> create({
    required String itineraryId,
    required String question,
    required List<String> options,
    required String createdBy,
  }) async {
    try {
      await _collection(itineraryId).add(
        Poll(
          id: '',
          question: question,
          options: options,
          votes: const {},
          createdBy: createdBy,
          createdAt: DateTime.now(),
        ).toMap(),
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Casts (or changes) [uid]'s vote — a targeted `votes.{uid}` field write
  /// so two members voting at nearly the same moment can't clobber each
  /// other's choice, same reasoning as `ItineraryRepository.togglePackingItem`.
  Future<void> vote({
    required String itineraryId,
    required String pollId,
    required String uid,
    required int optionIndex,
  }) async {
    try {
      await _collection(itineraryId).doc(pollId).update({'votes.$uid': optionIndex});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> delete({required String itineraryId, required String pollId}) async {
    try {
      await _collection(itineraryId).doc(pollId).delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
