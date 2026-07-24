import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../utils/app_exception.dart';

/// Thin wrapper around Firebase Storage for uploading profile photos and
/// review photos. Destination photos are admin-managed and uploaded the
/// same way once an admin console exists.
class StorageService {
  StorageService({FirebaseStorage? storage}) : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  static const Uuid _uuid = Uuid();

  Future<String> uploadFile({required String folder, required String ownerId, required File file}) async {
    try {
      final extension = file.path.split('.').last;
      final ref = _storage.ref().child(folder).child(ownerId).child('${_uuid.v4()}.$extension');
      // Explicit, not inferred: image_picker's compressed/resized temp files
      // don't always carry an extension Firebase Storage's own contentType
      // auto-detection can resolve, and every write rule in storage.rules
      // requires `contentType.matches('image/.*')` — an unset/undetected
      // contentType silently fails that check and denies the whole upload,
      // surfacing as a generic "unauthorized" error with nothing to point at.
      final task = await ref.putFile(file, SettableMetadata(contentType: _contentTypeFor(extension)));
      return await task.ref.getDownloadURL();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// image_picker re-encodes every picked/compressed image as JPEG
  /// regardless of source format when `imageQuality`/`maxWidth` is set (the
  /// pattern every picker call in this app uses), so that's the safe
  /// default for any extension this map doesn't recognize.
  String _contentTypeFor(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  Future<List<String>> uploadFiles({required String folder, required String ownerId, required List<File> files}) async {
    final urls = <String>[];
    for (final file in files) {
      urls.add(await uploadFile(folder: folder, ownerId: ownerId, file: file));
    }
    return urls;
  }

  Future<void> deleteByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // Best-effort cleanup — a missing/already-deleted file isn't fatal.
    }
  }
}
