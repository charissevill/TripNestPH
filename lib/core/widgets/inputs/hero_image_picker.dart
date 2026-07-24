import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/app_exception.dart';
import '../../utils/image_crop_helper.dart';

/// Admin Portal photo field: shows the current hero photo (or a placeholder),
/// and picking a new one uploads it to Firebase Storage and calls
/// [onChanged] with the resulting download URL — replaces the old
/// paste-a-URL text fields on every admin content form, matching the same
/// `ImagePicker` + `StorageService.uploadFile` pattern already used for
/// profile and review photos.
class HeroImagePicker extends StatefulWidget {
  const HeroImagePicker({
    super.key,
    required this.imageUrl,
    required this.folder,
    required this.ownerId,
    required this.onChanged,
    this.label = 'Photo',
    this.height = 160,
  });

  final String imageUrl;
  final String folder;
  final String ownerId;
  final ValueChanged<String> onChanged;
  final String label;
  final double height;

  @override
  State<HeroImagePicker> createState() => _HeroImagePickerState();
}

class _HeroImagePickerState extends State<HeroImagePicker> {
  final StorageService _storageService = StorageService();
  bool _uploading = false;
  String? _error;

  Future<void> _pick() async {
    final file = await pickAndCropImage();
    if (file == null || !mounted) return;

    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final url = await _storageService.uploadFile(folder: widget.folder, ownerId: widget.ownerId, file: file);
      widget.onChanged(url);
    } catch (e) {
      if (mounted) setState(() => _error = AppException.from(e).message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.labelLarge?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: _uploading ? null : _pick,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            height: widget.height,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.imageUrl.isNotEmpty) CachedNetworkImage(imageUrl: widget.imageUrl, fit: BoxFit.cover),
                if (widget.imageUrl.isEmpty && !_uploading)
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Symbols.add_photo_alternate_rounded, color: AppColors.textTertiary, size: 32),
                        SizedBox(height: AppSpacing.xs),
                        Text('Tap to upload a photo', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                      ],
                    ),
                  ),
                if (_uploading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(color: Colors.white),
                  )
                else if (widget.imageUrl.isNotEmpty)
                  Positioned(
                    right: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: const StadiumBorder(),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Symbols.edit_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
