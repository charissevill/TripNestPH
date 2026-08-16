import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/data/repositories/content_report_repository.dart';
import 'package:tripnest_ph/domain/models/content_report.dart';
import 'package:tripnest_ph/presentation/admin/admin_reported_reviews_screen.dart';

// AdminReportedReviewsScreen constructs its own repositories with no
// firestore/override params — this suite exercises the pieces that do
// accept one directly (the repositories), rather than pumping the full
// screen against a real Firebase app.
void main() {
  group('ContentReportRepository (Listings tab data source)', () {
    late FakeFirebaseFirestore firestore;
    late ContentReportRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = ContentReportRepository(firestore: firestore);
    });

    test('report() then streamAllForAdmin() surfaces it for moderation', () async {
      await repository.report(
        targetId: 'dest-1',
        targetType: ContentTargetType.destination,
        userId: 'user-1',
        reason: ContentReportReason.outdated,
      );

      final reports = await repository.streamAllForAdmin().first;
      expect(reports, hasLength(1));
      expect(reports.single.targetId, 'dest-1');
      expect(reports.single.targetType, ContentTargetType.destination);
      expect(reports.single.reason, ContentReportReason.outdated);
    });

    test('report() twice from the same user on the same listing throws instead of duplicating', () async {
      await repository.report(
        targetId: 'rest-1',
        targetType: ContentTargetType.restaurant,
        userId: 'user-1',
        reason: ContentReportReason.closed,
      );

      expect(
        () => repository.report(
          targetId: 'rest-1',
          targetType: ContentTargetType.restaurant,
          userId: 'user-1',
          reason: ContentReportReason.other,
        ),
        throwsA(anything),
      );
    });

    test('dismiss() removes the report from the queue', () async {
      await repository.report(
        targetId: 'fest-1',
        targetType: ContentTargetType.festival,
        userId: 'user-1',
        reason: ContentReportReason.inappropriatePhoto,
      );
      final report = (await repository.streamAllForAdmin().first).single;

      await repository.dismiss(report.id);

      expect(await repository.streamAllForAdmin().first, isEmpty);
    });

    test('the same listing can be reported by two different users independently', () async {
      await repository.report(
        targetId: 'dest-2',
        targetType: ContentTargetType.destination,
        userId: 'user-1',
        reason: ContentReportReason.outdated,
      );
      await repository.report(
        targetId: 'dest-2',
        targetType: ContentTargetType.destination,
        userId: 'user-2',
        reason: ContentReportReason.closed,
      );

      expect(await repository.streamAllForAdmin().first, hasLength(2));
    });
  });

  test('AdminReportedReviewsScreen constructs without throwing', () {
    // A cheap guard against a wiring mistake (e.g. a bad import) breaking
    // the widget tree at construction time — the full screen needs a real
    // Firebase app to actually pump (it builds its own un-overridable
    // repositories), which this suite deliberately doesn't attempt.
    expect(() => const AdminReportedReviewsScreen(), returnsNormally);
  });
}
