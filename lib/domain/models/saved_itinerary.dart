import 'package:cloud_firestore/cloud_firestore.dart';

import 'itinerary.dart';
import 'packing_item.dart';

/// A user-saved trip plan, persisted at `saved_itineraries/{id}`.
class SavedItinerary {
  const SavedItinerary({
    required this.id,
    required this.userId,
    required this.title,
    required this.itinerary,
    required this.savedAt,
    this.collaboratorIds = const [],
    this.memberNames = const {},
    this.packingItems = const [],
    this.startDate,
  });

  final String id;
  final String userId;
  final String title;
  final Itinerary itinerary;
  final DateTime savedAt;

  /// Other users' uids who joined this trip via its share code. They can
  /// view the itinerary, contribute expenses, and edit the packing list —
  /// but never the itinerary content or budget itself.
  final List<String> collaboratorIds;

  /// Display name for the owner and each collaborator, keyed by uid —
  /// captured at save/join time since a traveler can't read another
  /// traveler's `users/{uid}` profile directly (see firestore.rules). Used
  /// to label who paid/split what in the Budget Tracker rather than showing
  /// raw uids. A uid missing here (an older trip saved before this existed)
  /// just falls back to a generic label in the UI.
  final Map<String, String> memberNames;
  final List<PackingItem> packingItems;

  /// Every uid with access to this trip: the owner plus every collaborator.
  List<String> get memberIds => [userId, ...collaboratorIds];

  /// The traveler's actual first day of the trip, set (or later edited) by
  /// the owner — separate from [savedAt], which is just when they bookmarked
  /// it. Null until they pick a date; the trip still works fine without one.
  final DateTime? startDate;

  /// The calendar date [dayNumber] (1-indexed, matching [ItineraryDay])
  /// falls on, or null if no [startDate] has been set yet.
  DateTime? dateForDay(int dayNumber) => startDate?.add(Duration(days: dayNumber - 1));

  DateTime? get endDate => startDate?.add(Duration(days: itinerary.totalDays - 1));

  SavedItinerary copyWith({
    List<String>? collaboratorIds,
    Map<String, String>? memberNames,
    List<PackingItem>? packingItems,
    DateTime? startDate,
    bool clearStartDate = false,
  }) {
    return SavedItinerary(
      id: id,
      userId: userId,
      title: title,
      itinerary: itinerary,
      savedAt: savedAt,
      collaboratorIds: collaboratorIds ?? this.collaboratorIds,
      memberNames: memberNames ?? this.memberNames,
      packingItems: packingItems ?? this.packingItems,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
    );
  }

  factory SavedItinerary.fromMap(String id, Map<String, dynamic> map) {
    final timestamp = map['savedAt'];
    final startTimestamp = map['startDate'];
    return SavedItinerary(
      id: id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      itinerary: Itinerary.fromMap(Map<String, dynamic>.from(map['itinerary'] as Map? ?? const {})),
      savedAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      collaboratorIds: List<String>.from(map['collaboratorIds'] as List? ?? const []),
      memberNames: Map<String, String>.from(map['memberNames'] as Map? ?? const {}),
      packingItems: (map['packingItems'] as List?)
              ?.map((p) => PackingItem.fromMap(Map<String, dynamic>.from(p as Map)))
              .toList() ??
          PackingItem.defaults(),
      startDate: startTimestamp is Timestamp ? startTimestamp.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'itinerary': itinerary.toMap(),
      'savedAt': FieldValue.serverTimestamp(),
      'collaboratorIds': collaboratorIds,
      'memberNames': memberNames,
      'packingItems': packingItems.map((p) => p.toMap()).toList(),
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
    };
  }
}
