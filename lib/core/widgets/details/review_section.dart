import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/review_report_repository.dart';
import '../../../data/repositories/review_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../domain/models/review.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_spacing.dart';
import '../../utils/app_exception.dart';
import '../dialogs/confirmation_dialog.dart';
import '../dialogs/report_review_dialog.dart';
import 'review_form_sheet.dart';
import 'review_list.dart';

/// Live reviews for a destination/restaurant/festival: a stream of
/// [ReviewList] rows plus a "Write a Review" CTA, with inline edit/delete
/// for the current user's own review. Drop this into any Details screen.
class ReviewSection extends StatefulWidget {
  const ReviewSection({super.key, required this.targetId, required this.targetType, required this.reviewCount});

  final String targetId;
  final ReviewTargetType targetType;
  final int reviewCount;

  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  final ReviewRepository _repository = ReviewRepository();
  final ReviewReportRepository _reportRepository = ReviewReportRepository();
  final UserRepository _userRepository = UserRepository();

  Future<void> _writeReview(BuildContext context, {Review? existing}) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to leave a review.')));
      return;
    }

    final result = await showReviewFormSheet(
      context,
      initialRating: existing?.rating ?? 5,
      initialComment: existing?.comment ?? '',
      initialPhotoUrls: existing?.photoUrls ?? const [],
      isEditing: existing != null,
    );
    if (result == null || !context.mounted) return;

    try {
      if (existing != null) {
        await _repository.updateReview(
          Review(
            id: existing.id,
            userId: existing.userId,
            targetId: existing.targetId,
            targetType: existing.targetType,
            authorName: existing.authorName,
            authorAvatarUrl: existing.authorAvatarUrl,
            rating: result.rating,
            comment: result.comment,
            createdAt: existing.createdAt,
            photoUrls: existing.photoUrls,
          ),
          keptPhotoUrls: result.keptPhotoUrls,
          newPhotos: result.newPhotos,
        );
      } else {
        final user = auth.currentUser;
        final uid = auth.firebaseUser!.uid;
        // Best-effort: a failed visit-history lookup should never block
        // submitting the review itself — it just misses out on the badge.
        var verified = false;
        try {
          verified = await _userRepository.hasVisited(uid: uid, targetType: widget.targetType.name, targetId: widget.targetId);
        } catch (_) {}
        await _repository.addReview(
          review: Review(
            id: '',
            userId: uid,
            targetId: widget.targetId,
            targetType: widget.targetType,
            authorName: user?.name.isNotEmpty == true ? user!.name : 'Traveler',
            authorAvatarUrl: user?.photoUrl ?? '',
            rating: result.rating,
            comment: result.comment,
            createdAt: DateTime.now(),
            verified: verified,
          ),
          photos: result.newPhotos,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Future<void> _reportReview(BuildContext context, Review review) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to report a review.')));
      return;
    }
    final reason = await showReportReviewDialog(context);
    if (reason == null || !context.mounted) return;
    try {
      await _reportRepository.report(reviewId: review.id, userId: auth.firebaseUser!.uid, reason: reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks — our team will take a look.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Future<void> _deleteReview(BuildContext context, Review review) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete this review?',
      message: 'This can\'t be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await _repository.deleteReview(review);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUid = context.watch<AuthProvider>().firebaseUser?.uid;

    return StreamBuilder<List<Review>>(
      stream: _repository.streamForTarget(widget.targetId, widget.targetType),
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? const [];
        // Live, from the same stream the list below renders — not the
        // parent screen's one-time initial load, which used to sit frozen
        // above a list that had already moved on (e.g. right after
        // submitting a review, the count here used to lag until the whole
        // screen was pulled to refresh).
        final count = snapshot.connectionState == ConnectionState.waiting ? widget.reviewCount : reviews.length;
        Review? ownReview;
        for (final r in reviews) {
          if (r.userId == currentUid) {
            ownReview = r;
            break;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Reviews ($count)', style: theme.textTheme.titleLarge)),
                TextButton.icon(
                  onPressed: () => _writeReview(context, existing: ownReview),
                  icon: const Icon(Symbols.edit_rounded, size: 18),
                  label: Text(ownReview == null ? 'Write a Review' : 'Edit Your Review'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
              )
            else if (reviews.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'No reviews yet — be the first to share your experience.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              ReviewList(
                reviews: reviews,
                currentUserId: currentUid,
                onEdit: (r) => _writeReview(context, existing: r),
                onDelete: (r) => _deleteReview(context, r),
                onReport: (r) => _reportReview(context, r),
              ),
          ],
        );
      },
    );
  }
}
