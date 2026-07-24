import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../buttons/animated_button.dart';

/// The bottom sheet used to write or edit a review: star rating, comment
/// and up to three photos. Returns a [ReviewFormResult] via `Navigator.pop`,
/// or null if the user dismissed it without submitting.
class ReviewFormResult {
  const ReviewFormResult({required this.rating, required this.comment, required this.newPhotos});

  final double rating;
  final String comment;
  final List<File> newPhotos;
}

Future<ReviewFormResult?> showReviewFormSheet(
  BuildContext context, {
  double initialRating = 5,
  String initialComment = '',
  bool isEditing = false,
}) {
  return showModalBottomSheet<ReviewFormResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ReviewFormSheet(
      initialRating: initialRating,
      initialComment: initialComment,
      isEditing: isEditing,
    ),
  );
}

class _ReviewFormSheet extends StatefulWidget {
  const _ReviewFormSheet({required this.initialRating, required this.initialComment, required this.isEditing});

  final double initialRating;
  final String initialComment;
  final bool isEditing;

  @override
  State<_ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends State<_ReviewFormSheet> {
  late double _rating = widget.initialRating;
  late final TextEditingController _commentController = TextEditingController(text: widget.initialComment);
  final List<File> _photos = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickPhoto() async {
    if (_photos.length >= 3) return;
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _photos.add(File(picked.path)));
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(AppRadius.pill)),
                ),
              ),
              Text(widget.isEditing ? 'Edit Your Review' : 'Write a Review', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final starValue = i + 1.0;
                    return IconButton(
                      onPressed: () => setState(() => _rating = starValue),
                      icon: Icon(
                        _rating >= starValue ? Symbols.star_rounded : Symbols.star_outline_rounded,
                        color: AppColors.accent,
                        fill: _rating >= starValue ? 1 : 0,
                        size: 34,
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _commentController,
                maxLines: 4,
                minLines: 3,
                maxLength: 2000,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Comment',
                  hintText: 'Share your experience...',
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  ..._photos.map(
                    (file) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Image.file(file, width: 64, height: 64, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: GestureDetector(
                              onTap: () => setState(() => _photos.remove(file)),
                              child: const CircleAvatar(
                                radius: 10,
                                backgroundColor: AppColors.error,
                                child: Icon(Symbols.close_rounded, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_photos.length < 3)
                    InkWell(
                      onTap: _pickPhoto,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Symbols.add_a_photo_rounded, color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AnimatedButton(
                label: widget.isEditing ? 'Update Review' : 'Submit Review',
                onPressed: _commentController.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                          ReviewFormResult(rating: _rating, comment: _commentController.text.trim(), newPhotos: _photos),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
