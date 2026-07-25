import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../domain/models/review.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../indicators/rating_widget.dart';

/// Vertical list of traveler reviews shown near the bottom of every Details
/// screen. Falls back to an initials avatar when no photo is provided, and
/// shows an edit/delete menu on reviews the current user authored.
class ReviewList extends StatelessWidget {
  const ReviewList({
    super.key,
    required this.reviews,
    this.currentUserId,
    this.onEdit,
    this.onDelete,
    this.onReport,
  });

  final List<Review> reviews;
  final String? currentUserId;
  final ValueChanged<Review>? onEdit;
  final ValueChanged<Review>? onDelete;

  /// Only offered on someone else's review — reporting your own would be
  /// pointless, so [_ReviewTile] hides this whenever [isOwn] is true.
  final ValueChanged<Review>? onReport;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: reviews
          .map(
            (review) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: _ReviewTile(
                review: review,
                isOwn: currentUserId != null && currentUserId == review.userId,
                onEdit: onEdit,
                onDelete: onDelete,
                onReport: onReport,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.isOwn, this.onEdit, this.onDelete, this.onReport});

  final Review review;
  final bool isOwn;
  final ValueChanged<Review>? onEdit;
  final ValueChanged<Review>? onDelete;
  final ValueChanged<Review>? onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = review.authorName.trim().isEmpty
        ? '?'
        : review.authorName.trim().split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          child: Text(initials, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(child: Text(review.authorName, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
                        if (review.verified) ...[
                          const SizedBox(width: 6),
                          const Tooltip(
                            message: 'Verified Visit — viewed this listing before reviewing',
                            child: Icon(Symbols.verified_rounded, size: 15, color: AppColors.success),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(review.date, style: theme.textTheme.bodySmall),
                  if (isOwn) _OwnReviewMenu(onEdit: () => onEdit?.call(review), onDelete: () => onDelete?.call(review))
                  else if (onReport != null)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Symbols.flag_rounded, size: 18, color: AppColors.textTertiary),
                      tooltip: 'Report',
                      onPressed: () => onReport!(review),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              RatingWidget(rating: review.rating, starSize: 14),
              const SizedBox(height: AppSpacing.xs),
              Text(review.comment, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
              if (review.photoUrls.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: review.photoUrls.length,
                    separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
                    itemBuilder: (context, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: CachedNetworkImage(imageUrl: review.photoUrls[i], width: 64, height: 64, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OwnReviewMenu extends StatelessWidget {
  const _OwnReviewMenu({required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Symbols.more_vert_rounded, size: 18, color: AppColors.textTertiary),
      onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}
