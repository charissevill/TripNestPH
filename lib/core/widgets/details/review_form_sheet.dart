import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/validators.dart';
import '../buttons/animated_button.dart';

/// The bottom sheet used to write or edit a review: star rating, comment
/// and up to three photos. Returns a [ReviewFormResult] via `Navigator.pop`,
/// or null if the user dismissed it without submitting.
class ReviewFormResult {
  const ReviewFormResult({
    required this.rating,
    required this.comment,
    required this.keptPhotoUrls,
    required this.newPhotos,
  });

  final double rating;
  final String comment;

  /// The subset of the review's existing remote photos the traveler chose
  /// to keep — anything from the original list NOT in here was removed.
  final List<String> keptPhotoUrls;

  /// Freshly picked local files to upload and append to [keptPhotoUrls].
  final List<File> newPhotos;
}

Future<ReviewFormResult?> showReviewFormSheet(
  BuildContext context, {
  double initialRating = 5,
  String initialComment = '',
  List<String> initialPhotoUrls = const [],
  bool isEditing = false,
}) {
  return showModalBottomSheet<ReviewFormResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ReviewFormSheet(
      initialRating: initialRating,
      initialComment: initialComment,
      initialPhotoUrls: initialPhotoUrls,
      isEditing: isEditing,
    ),
  );
}

class _ReviewFormSheet extends StatefulWidget {
  const _ReviewFormSheet({
    required this.initialRating,
    required this.initialComment,
    required this.initialPhotoUrls,
    required this.isEditing,
  });

  final double initialRating;
  final String initialComment;
  final List<String> initialPhotoUrls;
  final bool isEditing;

  @override
  State<_ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends State<_ReviewFormSheet> {
  static const int _maxPhotos = 3;

  final _formKey = GlobalKey<FormState>();
  late double _rating = widget.initialRating;
  late final TextEditingController _commentController = TextEditingController(
    text: widget.initialComment,
  );
  late final List<String> _keptPhotoUrls = [...widget.initialPhotoUrls];
  final List<File> _newPhotos = [];
  final ImagePicker _picker = ImagePicker();

  int get _totalPhotoCount => _keptPhotoUrls.length + _newPhotos.length;

  Future<void> _pickPhoto() async {
    if (_totalPhotoCount >= _maxPhotos) return;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) setState(() => _newPhotos.add(File(picked.path)));
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text(
                    widget.isEditing ? 'Edit Your Review' : 'Write a Review',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) {
                        final starValue = i + 1.0;
                        return IconButton(
                          onPressed: () => setState(() => _rating = starValue),
                          icon: Icon(
                            _rating >= starValue
                                ? Symbols.star_rounded
                                : Symbols.star_outline_rounded,
                            color: AppColors.accent,
                            fill: _rating >= starValue ? 1 : 0,
                            size: 34,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _commentController,
                    maxLines: 4,
                    minLines: 3,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Comment',
                      hintText: 'Share your experience...',
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      prefixIcon: Icon(Symbols.rate_review_rounded, size: 20),
                    ),
                    validator: (v) => Validators.required(v, label: 'Comment'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      ..._keptPhotoUrls.map(
                        (url) => Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: -6,
                                right: -6,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _keptPhotoUrls.remove(url)),
                                  child: const CircleAvatar(
                                    radius: 10,
                                    backgroundColor: AppColors.error,
                                    child: Icon(
                                      Symbols.close_rounded,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ..._newPhotos.map(
                        (file) => Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                child: Image.file(
                                  file,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: -6,
                                right: -6,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _newPhotos.remove(file)),
                                  child: const CircleAvatar(
                                    radius: 10,
                                    backgroundColor: AppColors.error,
                                    child: Icon(
                                      Symbols.close_rounded,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_totalPhotoCount < _maxPhotos)
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
                            child: const Icon(
                              Symbols.add_a_photo_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AnimatedButton(
                    label: widget.isEditing ? 'Update Review' : 'Submit Review',
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;
                      Navigator.of(context).pop(
                        ReviewFormResult(
                          rating: _rating,
                          comment: _commentController.text.trim(),
                          keptPhotoUrls: _keptPhotoUrls,
                          newPhotos: _newPhotos,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
