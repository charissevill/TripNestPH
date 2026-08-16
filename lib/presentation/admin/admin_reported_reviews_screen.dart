import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/content_report_repository.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/festival_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/review_repository.dart';
import '../../data/repositories/review_report_repository.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/content_report.dart';
import '../../domain/models/review.dart';
import '../../domain/models/review_report.dart';

/// Admin-only moderation queue: every traveler-filed report, split into two
/// tabs — reported Reviews (the original screen, unchanged), and reported
/// Listings ([ContentReport]s on a destination/restaurant/festival itself,
/// e.g. outdated info or a permanently-closed business). Closes the
/// loophole where `isHidden` existed in the data model with no UI ever able
/// to set it outside direct Firestore access.
class AdminReportedReviewsScreen extends StatefulWidget {
  const AdminReportedReviewsScreen({super.key});

  @override
  State<AdminReportedReviewsScreen> createState() =>
      _AdminReportedReviewsScreenState();
}

class _AdminReportedReviewsScreenState
    extends State<AdminReportedReviewsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  final ReviewReportRepository _reportRepository = ReviewReportRepository();
  final ReviewRepository _reviewRepository = ReviewRepository();
  final NotificationRepository _notificationRepository = NotificationRepository();
  final ContentReportRepository _contentReportRepository = ContentReportRepository();
  final DestinationRepository _destinationRepository = DestinationRepository();
  final RestaurantRepository _restaurantRepository = RestaurantRepository();
  final FestivalRepository _festivalRepository = FestivalRepository();

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _dismiss(ReviewReport report) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Dismiss this report?',
      message: 'The review stays visible as-is.',
      confirmLabel: 'Dismiss',
    );
    if (!confirmed || !mounted) return;
    try {
      await _reportRepository.dismiss(report.id);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Future<void> _setHidden(
    ReviewReport report,
    Review review,
    bool hidden,
  ) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: hidden ? 'Hide this review?' : 'Restore this review?',
      message: hidden
          ? 'Travelers will no longer see it, and it won\'t count toward the rating.'
          : 'It becomes visible to travelers again.',
      confirmLabel: hidden ? 'Hide' : 'Restore',
      isDestructive: hidden,
    );
    if (!confirmed || !mounted) return;
    try {
      await _reviewRepository.setHidden(review, hidden);
      if (hidden) {
        await _reportRepository.dismiss(report.id);
        // The review otherwise just vanished from the listing's page with
        // no trace back to the person who wrote it — no notification, no
        // "My Reviews" flag, nothing.
        try {
          await _notificationRepository.createForUser(
            userId: review.userId,
            title: 'Your review was hidden',
            body: 'A review you wrote didn\'t meet our community guidelines and is no longer visible to other travelers.',
            category: NotificationCategory.general,
            relatedId: review.targetId,
          );
        } catch (_) {
          // Best-effort — the review is hidden either way; a failed
          // notification shouldn't undo the moderation action itself.
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Future<void> _dismissContentReport(ContentReport report) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Dismiss this report?',
      message: 'The listing stays as-is.',
      confirmLabel: 'Dismiss',
    );
    if (!confirmed || !mounted) return;
    try {
      await _contentReportRepository.dismiss(report.id);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  void _openTarget(ContentReport report) {
    switch (report.targetType) {
      case ContentTargetType.destination:
        context.push(RoutePaths.destinationDetails(report.targetId));
      case ContentTargetType.restaurant:
        context.push(RoutePaths.restaurantDetails(report.targetId));
      case ContentTargetType.festival:
        context.push(RoutePaths.festivalDetails(report.targetId));
    }
  }

  Future<_TargetInfo?> _loadTarget(ContentReport report) async {
    switch (report.targetType) {
      case ContentTargetType.destination:
        final d = await _destinationRepository.getById(report.targetId);
        return d == null ? null : _TargetInfo(name: d.name, subtitle: d.provinceName);
      case ContentTargetType.restaurant:
        final r = await _restaurantRepository.getById(report.targetId);
        return r == null ? null : _TargetInfo(name: r.name, subtitle: r.provinceName);
      case ContentTargetType.festival:
        final f = await _festivalRepository.getById(report.targetId);
        return f == null ? null : _TargetInfo(name: f.name, subtitle: f.provinceName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Reviews'), Tab(text: 'Listings')],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [_buildReviewReports(), _buildContentReports()],
        ),
      ),
    );
  }

  Widget _buildReviewReports() {
    return StreamBuilder<List<ReviewReport>>(
      stream: _reportRepository.streamAllForAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            children: List.generate(4, (_) => LoadingWidget.cardBlock()),
          );
        }
        final reports = snapshot.data ?? const [];
        if (reports.isEmpty) {
          return const EmptyStateWidget(
            icon: Symbols.flag_rounded,
            title: 'No reports',
            message: 'Reviews travelers flag will show up here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.huge,
          ),
          itemCount: reports.length,
          itemBuilder: (context, i) {
            final report = reports[i];
            return FutureBuilder<Review?>(
              future: _reviewRepository.getById(report.reviewId),
              builder: (context, reviewSnapshot) {
                if (reviewSnapshot.connectionState !=
                    ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: LinearProgressIndicator(),
                  );
                }
                final review = reviewSnapshot.data;
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reason: ${ReportReason.label(report.reason)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (review == null)
                          const Text(
                            'This review no longer exists.',
                            style: TextStyle(color: AppColors.textTertiary),
                          )
                        else ...[
                          Text(
                            '${review.authorName} · ${review.rating.toStringAsFixed(1)}★',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            review.comment.isEmpty
                                ? '(no comment)'
                                : review.comment,
                          ),
                          if (review.isHidden)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'Currently hidden',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            if (review != null && !review.isHidden)
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                ),
                                onPressed: () =>
                                    _setHidden(report, review, true),
                                child: const Text('Hide'),
                              ),
                            if (review != null && review.isHidden)
                              OutlinedButton(
                                onPressed: () =>
                                    _setHidden(report, review, false),
                                child: const Text('Restore'),
                              ),
                            OutlinedButton(
                              onPressed: () => _dismiss(report),
                              child: const Text('Dismiss report'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildContentReports() {
    return StreamBuilder<List<ContentReport>>(
      stream: _contentReportRepository.streamAllForAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            children: List.generate(4, (_) => LoadingWidget.cardBlock()),
          );
        }
        final reports = snapshot.data ?? const [];
        if (reports.isEmpty) {
          return const EmptyStateWidget(
            icon: Symbols.flag_rounded,
            title: 'No reports',
            message: 'Listings travelers flag as outdated, closed, or inappropriate will show up here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.huge,
          ),
          itemCount: reports.length,
          itemBuilder: (context, i) {
            final report = reports[i];
            return FutureBuilder<_TargetInfo?>(
              future: _loadTarget(report),
              builder: (context, targetSnapshot) {
                if (targetSnapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: LinearProgressIndicator(),
                  );
                }
                final target = targetSnapshot.data;
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reason: ${ContentReportReason.label(report.reason)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        if (target == null)
                          const Text(
                            'This listing no longer exists.',
                            style: TextStyle(color: AppColors.textTertiary),
                          )
                        else
                          InkWell(
                            onTap: () => _openTarget(report),
                            child: Text(
                              '${target.name} · ${target.subtitle}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(decoration: TextDecoration.underline),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            if (target != null)
                              OutlinedButton(
                                onPressed: () => _openTarget(report),
                                child: const Text('View listing'),
                              ),
                            OutlinedButton(
                              onPressed: () => _dismissContentReport(report),
                              child: const Text('Dismiss report'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _TargetInfo {
  const _TargetInfo({required this.name, required this.subtitle});

  final String name;
  final String subtitle;
}
