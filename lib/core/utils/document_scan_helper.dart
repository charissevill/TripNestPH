import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/foundation.dart';

import 'app_exception.dart';
import 'image_crop_helper.dart';

/// Opens the native document scanner (ML Kit on Android, VisionKit on iOS),
/// which finds the paper's edges, straightens the perspective, and crops out
/// the background — so a permit photographed on a desk comes back as just the
/// permit. The scanner's own gallery shortcut covers owners who already have
/// a photo of it. Returns the scanned page, or null if cancelled.
///
/// Falls back to [pickAndCropImage] on platforms the scanner doesn't support.
Future<File?> scanDocument() async {
  final supported =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  if (!supported) return pickAndCropImage();

  try {
    final pages = await CunningDocumentScanner.getPictures(
      noOfPages: 1,
      scannerSource: ScannerSource.cameraAndGallery,
      // JPEG rather than the PNG default — a full-page PNG scan can exceed
      // the upload size limit in storage.rules. Android always returns JPEG.
      iosScannerOptions: IosScannerOptions(imageFormat: IosImageFormat.jpg, jpgCompressionQuality: 0.85),
    );
    if (pages == null) return null;
    return File(pages.first);
  } on CunningDocumentScannerException catch (e) {
    logTechnicalError(e);
    if (e.code == 'permission_denied') {
      throw const AppException(
        'Camera permission was denied. Please allow access in your device settings and try again.',
      );
    }
    throw const AppException('The scanner couldn\'t be opened. Please try again.');
  }
}
