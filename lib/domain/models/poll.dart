import 'package:cloud_firestore/cloud_firestore.dart';

/// A quick group decision on a saved itinerary — "Which restaurant for Day
/// 2?" — persisted at `saved_itineraries/{id}/polls/{pollId}`. Any trip
/// member (owner or collaborator) can create one and vote; [votes] maps a
/// voter's uid to the index they picked in [options], so re-voting just
/// overwrites that same key instead of creating a duplicate entry.
class Poll {
  const Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.votes,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String question;
  final List<String> options;

  /// Voter uid -> index into [options].
  final Map<String, int> votes;
  final String createdBy;
  final DateTime createdAt;

  /// Tally of votes per option, in the same order as [options] — the
  /// display's one recurring need, computed once here instead of by every
  /// call site.
  List<int> get voteCounts {
    final counts = List<int>.filled(options.length, 0);
    for (final optionIndex in votes.values) {
      if (optionIndex >= 0 && optionIndex < counts.length) {
        counts[optionIndex]++;
      }
    }
    return counts;
  }

  int get totalVotes => votes.length;

  factory Poll.fromMap(String id, Map<String, dynamic> map) {
    final timestamp = map['createdAt'];
    return Poll(
      id: id,
      question: map['question'] as String? ?? '',
      options: List<String>.from(map['options'] as List? ?? const []),
      votes: Map<String, int>.from(map['votes'] as Map? ?? const {}),
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'votes': votes,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
