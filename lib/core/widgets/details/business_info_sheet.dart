import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/favorites_provider.dart';
import '../../../data/repositories/business_repository.dart';
import '../../../data/repositories/favorites_repository.dart';
import '../../../data/repositories/review_repository.dart';
import '../../../domain/models/business.dart';
import '../../../domain/models/review.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/app_exception.dart';
import '../../utils/maps_launcher.dart';
import '../../utils/safe_launch.dart';
import '../buttons/animated_button.dart';
import '../cards/tag_chip.dart';
import '../indicators/rating_widget.dart';
import '../media/image_error_placeholder.dart';

/// Opens the full, untruncated detail sheet for an approved business
/// listing — shared by [ProvinceDetailsScreen]'s "Local Businesses" section
/// and Explore's "Local Finds" tab, so both get real tap-to-call/tap-to-open
/// actions a plain card's text can't offer.
void showBusinessInfoSheet(BuildContext context, Business business) {
  // Best-effort, fire-and-forget — a failed count shouldn't block opening
  // the sheet itself.
  BusinessRepository().incrementViewCount(business.id).catchError((_) {});
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // See trip_calendar_screen.dart's showModalBottomSheet for why this
    // matters — without it, the floating AI Chat FAB floats visibly on
    // top of this sheet instead of being covered by it.
    useRootNavigator: true,
    builder: (context) => _BusinessInfoSheet(business: business),
  );
}

/// A [BusinessCategory.foodAndDining] listing already has its own
/// `restaurants` mirror (see the class doc on [Business]) — favoriting/
/// reviewing that instead of the raw business doc keeps a single rating/
/// review history per real-world place, rather than splitting it across two
/// parallel records a traveler could otherwise leave two separate reviews
/// on for the exact same cafe. Every other category has no such mirror, so
/// it favorites/reviews the business doc itself.
(FavoriteType, ReviewTargetType, String) businessFavoriteAndReviewTarget(
  Business business,
) {
  if (business.isFoodAndDining && business.restaurantId.isNotEmpty) {
    return (
      FavoriteType.restaurant,
      ReviewTargetType.restaurant,
      business.restaurantId,
    );
  }
  return (FavoriteType.business, ReviewTargetType.business, business.id);
}

class _BusinessInfoSheet extends StatelessWidget {
  const _BusinessInfoSheet({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (favoriteType, reviewTargetType, targetId) =
        businessFavoriteAndReviewTarget(business);
    final favorites = context.watch<FavoritesProvider>();
    final isSaved = favoriteType == FavoriteType.restaurant
        ? favorites.isRestaurantSaved(targetId)
        : favorites.isBusinessSaved(targetId);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              if (business.heroImageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: CachedNetworkImage(
                    imageUrl: business.heroImageUrl,
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) =>
                        const ImageErrorPlaceholder(
                          width: double.infinity,
                          height: 160,
                        ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      business.name,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isSaved
                          ? Symbols.bookmark_rounded
                          : Symbols.bookmark_border_rounded,
                      color: isSaved
                          ? AppColors.accentDark
                          : theme.colorScheme.onSurfaceVariant,
                      fill: isSaved ? 1 : 0,
                    ),
                    onPressed: () => favoriteType == FavoriteType.restaurant
                        ? favorites.toggleRestaurant(targetId)
                        : favorites.toggleBusiness(targetId),
                  ),
                ],
              ),
              TagChip(
                label: BusinessCategory.label(business.category),
                color: theme.colorScheme.primary,
              ),
              if (business.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  business.description,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
              if (business.openingHours.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _InfoRow(
                  icon: Symbols.schedule_rounded,
                  text: business.openingHours,
                ),
              ],
              if (business.address.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: InkWell(
                    onTap: () => MapsLauncher.openPlaceSearch(business.address),
                    child: _InfoRow(
                      icon: Symbols.location_on_rounded,
                      text: business.address,
                    ),
                  ),
                ),
              if (business.contactNumber.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: InkWell(
                    onTap: () => callNumber(business.contactNumber),
                    child: _InfoRow(
                      icon: Symbols.call_rounded,
                      text: business.contactNumber,
                    ),
                  ),
                ),
              if (business.websiteUrl.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                AnimatedButton(
                  label: 'Visit Website',
                  icon: Symbols.open_in_new_rounded,
                  filled: false,
                  onPressed: () => MapsLauncher.openUrl(business.websiteUrl),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              _ReviewsSection(
                business: business,
                targetId: targetId,
                targetType: reviewTargetType,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

/// Live reviews for [targetId]/[targetType] — the average/count shown here
/// is computed straight from this same stream rather than trusting
/// [Business.rating]/[Business.reviewCount] (which can lag very briefly
/// after a write, same as every other listing type's aggregate fields), so
/// what a traveler sees always matches the list right below it.
class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.business,
    required this.targetId,
    required this.targetType,
  });

  final Business business;
  final String targetId;
  final ReviewTargetType targetType;

  Future<void> _writeReview(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final uid = auth.firebaseUser?.uid;
    if (uid == null) return;
    final result = await showDialog<(double rating, String comment)>(
      context: context,
      builder: (context) => const _WriteReviewDialog(),
    );
    if (result == null) return;
    final (rating, comment) = result;
    try {
      await ReviewRepository().addReview(
        review: Review(
          id: '',
          userId: uid,
          targetId: targetId,
          targetType: targetType,
          authorName: auth.currentUser?.name.isNotEmpty == true
              ? auth.currentUser!.name
              : 'Traveler',
          authorAvatarUrl: auth.currentUser?.photoUrl ?? '',
          rating: rating,
          comment: comment,
          createdAt: DateTime.now(),
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Review posted.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Review>>(
      stream: ReviewRepository().streamForTarget(targetId, targetType),
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? const <Review>[];
        final rating = reviews.isEmpty
            ? 0.0
            : reviews.map((r) => r.rating).reduce((a, b) => a + b) /
                  reviews.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text('Reviews', style: theme.textTheme.titleMedium),
                      if (reviews.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.sm),
                        RatingWidget(rating: rating),
                        const SizedBox(width: 4),
                        Text(
                          '(${reviews.length})',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _writeReview(context),
                  icon: const Icon(Symbols.rate_review_rounded, size: 18),
                  label: const Text('Write a Review'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (reviews.isEmpty)
              Text(
                'No reviews yet — be the first to share your experience.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...reviews.map((r) => _ReviewTile(review: r)),
          ],
        );
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    review.authorName,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                RatingWidget(rating: review.rating),
              ],
            ),
            const SizedBox(height: 2),
            Text(review.date, style: theme.textTheme.bodySmall),
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(review.comment, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// A star picker (tap 1-5) + comment field — pops `(rating, comment)`, or
/// null if cancelled. No photo attachment here (unlike
/// [ReviewRepository.addReview]'s own support for one) — kept to the two
/// fields every review fundamentally needs, since this is the first "write
/// a review" UI built anywhere in the app and a simple v1 beats a stalled
/// attempt at a fully-loaded one.
class _WriteReviewDialog extends StatefulWidget {
  const _WriteReviewDialog();

  @override
  State<_WriteReviewDialog> createState() => _WriteReviewDialogState();
}

class _WriteReviewDialogState extends State<_WriteReviewDialog> {
  final _commentController = TextEditingController();
  double _rating = 0;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_rating < 1) {
      setState(() => _error = 'Please pick a star rating.');
      return;
    }
    Navigator.of(context).pop((_rating, _commentController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Scrolls on a short viewport (landscape, keyboard open) instead of overflowing.
      scrollable: true,
      title: const Text('Write a Review'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starValue = i + 1;
              return IconButton(
                onPressed: () => setState(() {
                  _rating = starValue.toDouble();
                  _error = null;
                }),
                icon: Icon(
                  _rating >= starValue
                      ? Symbols.star_rounded
                      : Symbols.star_outline_rounded,
                  color: AppColors.accentDark,
                  size: 32,
                ),
              );
            }),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _commentController,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Your experience (optional)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Post')),
      ],
    );
  }
}
