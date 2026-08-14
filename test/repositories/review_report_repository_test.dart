import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/data/repositories/review_report_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ReviewReportRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = ReviewReportRepository(firestore: firestore);
  });

  test('report() creates a report that streamAllForAdmin() picks up', () async {
    await repository.report(reviewId: 'review-1', userId: 'user-1', reason: 'Spam');

    final reports = await repository.streamAllForAdmin().first;
    expect(reports, hasLength(1));
    expect(reports.first.reviewId, 'review-1');
    expect(reports.first.userId, 'user-1');
  });

  test('report() from the same user against the same review a second time throws a clear "already reported" message', () async {
    await repository.report(reviewId: 'review-1', userId: 'user-1', reason: 'Spam');

    await expectLater(
      () => repository.report(reviewId: 'review-1', userId: 'user-1', reason: 'Still spam, changed my mind on why'),
      throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('already reported'))),
    );

    final reports = await repository.streamAllForAdmin().first;
    expect(reports, hasLength(1));
    expect(reports.first.reason, 'Spam');
  });

  test('report() from different users against the same review creates separate docs', () async {
    await repository.report(reviewId: 'review-1', userId: 'user-1', reason: 'Spam');
    await repository.report(reviewId: 'review-1', userId: 'user-2', reason: 'Offensive');

    final reports = await repository.streamAllForAdmin().first;
    expect(reports, hasLength(2));
  });

  test('dismiss() removes the report so streamAllForAdmin() no longer includes it', () async {
    await repository.report(reviewId: 'review-1', userId: 'user-1', reason: 'Spam');
    final reports = await repository.streamAllForAdmin().first;

    await repository.dismiss(reports.first.id);

    final remaining = await repository.streamAllForAdmin().first;
    expect(remaining, isEmpty);
  });
}
