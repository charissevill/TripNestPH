import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/app_exception.dart';
import '../../utils/image_crop_helper.dart';

/// Admin Portal multi-photo field for a swipeable gallery (see
/// `DetailsGalleryAppBar`, the shared widget that renders these as an
/// actual `PageView` slideshow on a details screen) — a horizontal strip of
/// uploaded photos plus an "Add" tile, each removable. Sibling to
/// [HeroImagePicker], which is for the single cover photo.
class GalleryImagePicker extends StatefulWidget {
  const GalleryImagePicker({
    super.key,
    required this.imageUrls,
    required this.folder,
    required this.ownerId,
    required this.onChanged,
    this.label = 'Gallery Photos',
  });

  final List<String> imageUrls;
  final String folder;
  final String ownerId;
  final ValueChanged<List<String>> onChanged;
  final String label;

  @override
  State<GalleryImagePicker> createState() => _GalleryImagePickerState();
}

class _GalleryImagePickerState extends State<GalleryImagePicker> {
  final StorageService _storageService = StorageService();
  bool _uploading = false;
  String? _error;

  Future<void> _addPhoto() async {
    final file = await pickAndCropImage();
    if (file == null || !mounted) return;

    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final url = await _storageService.uploadFile(folder: widget.folder, ownerId: widget.ownerId, file: file);
      widget.onChanged([...widget.imageUrls, url]);
    } catch (e) {
      if (mounted) setState(() => _error = AppException.from(e).message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removeAt(int index) {
    final updated = [...widget.imageUrls]..removeAt(index);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.labelLarge?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < widget.imageUrls.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: _Thumbnail(url: widget.imageUrls[i], onRemove: () => _removeAt(i)),
                ),
              InkWell(
                onTap: _uploading ? null : _addPhoto,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: _uploading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                      : const Icon(Symbols.add_photo_alternate_rounded, color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
        ],
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url, required this.onRemove});

  final String url;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: CachedNetworkImage(imageUrl: url, width: 90, height: 90, fit: BoxFit.cover),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                child: const Icon(Symbols.close_rounded, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
