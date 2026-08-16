import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/data/repositories/poll_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late PollRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = PollRepository(firestore: firestore);
  });

  test('create() creates a poll that streamForItinerary() picks up, with no votes yet', () async {
    await repository.create(
      itineraryId: 'trip-1',
      question: 'Which restaurant for Day 2?',
      options: ['Restaurant A', 'Restaurant B'],
      createdBy: 'user-1',
    );

    final polls = await repository.streamForItinerary('trip-1').first;

    expect(polls, hasLength(1));
    expect(polls.first.question, 'Which restaurant for Day 2?');
    expect(polls.first.options, ['Restaurant A', 'Restaurant B']);
    expect(polls.first.votes, isEmpty);
    expect(polls.first.createdBy, 'user-1');
  });

  test('streamForItinerary() only returns polls under that itinerary', () async {
    await repository.create(itineraryId: 'trip-1', question: 'Q1', options: ['A', 'B'], createdBy: 'user-1');
    await repository.create(itineraryId: 'trip-2', question: 'Q2', options: ['C', 'D'], createdBy: 'user-1');

    final polls = await repository.streamForItinerary('trip-1').first;

    expect(polls, hasLength(1));
    expect(polls.first.question, 'Q1');
  });

  test('vote() records a voter\'s pick, and a second vote() from the same voter overwrites it', () async {
    await repository.create(itineraryId: 'trip-1', question: 'Q1', options: ['A', 'B'], createdBy: 'user-1');
    final pollId = (await repository.streamForItinerary('trip-1').first).first.id;

    await repository.vote(itineraryId: 'trip-1', pollId: pollId, uid: 'user-2', optionIndex: 0);
    var polls = await repository.streamForItinerary('trip-1').first;
    expect(polls.first.votes, {'user-2': 0});
    expect(polls.first.voteCounts, [1, 0]);

    await repository.vote(itineraryId: 'trip-1', pollId: pollId, uid: 'user-2', optionIndex: 1);
    polls = await repository.streamForItinerary('trip-1').first;
    expect(polls.first.votes, {'user-2': 1});
    expect(polls.first.voteCounts, [0, 1]);
  });

  test('vote() from different voters tallies independently', () async {
    await repository.create(itineraryId: 'trip-1', question: 'Q1', options: ['A', 'B'], createdBy: 'user-1');
    final pollId = (await repository.streamForItinerary('trip-1').first).first.id;

    await repository.vote(itineraryId: 'trip-1', pollId: pollId, uid: 'user-1', optionIndex: 0);
    await repository.vote(itineraryId: 'trip-1', pollId: pollId, uid: 'user-2', optionIndex: 0);
    await repository.vote(itineraryId: 'trip-1', pollId: pollId, uid: 'user-3', optionIndex: 1);

    final polls = await repository.streamForItinerary('trip-1').first;
    expect(polls.first.totalVotes, 3);
    expect(polls.first.voteCounts, [2, 1]);
  });

  test('delete() removes the poll so streamForItinerary() no longer includes it', () async {
    await repository.create(itineraryId: 'trip-1', question: 'Q1', options: ['A', 'B'], createdBy: 'user-1');
    final pollId = (await repository.streamForItinerary('trip-1').first).first.id;

    await repository.delete(itineraryId: 'trip-1', pollId: pollId);

    final remaining = await repository.streamForItinerary('trip-1').first;
    expect(remaining, isEmpty);
  });
}
