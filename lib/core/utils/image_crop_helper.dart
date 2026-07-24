import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';

/// Picks an image from the gallery, then lets the admin crop it before it's
/// uploaded — used by every admin photo field ([HeroImagePicker],
/// [GalleryImagePicker]) instead of uploading whatever the OS gallery
/// picker returned as-is. Returns the final cropped file, or null if either
/// the picker or the cropper was cancelled.
Future<File?> pickAndCropImage() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 2000);
  if (picked == null) return null;

  final cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    compressQuality: 85,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Crop Photo',
        toolbarColor: AppColors.primary,
        toolbarWidgetColor: Colors.white,
        activeControlsWidgetColor: AppColors.primary,
        // Free-form by default — every admin photo field here (province
        // cover/gallery, tourist spot, festival) is displayed at a
        // different aspect ratio, so locking one in at crop time would be
        // wrong for some of them.
        lockAspectRatio: false,
      ),
      IOSUiSettings(title: 'Crop Photo'),
    ],
  );
  if (cropped == null) return null;
  return File(cropped.path);
}
