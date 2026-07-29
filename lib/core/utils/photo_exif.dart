import 'dart:io';

import 'package:exif/exif.dart';

/// A photo's GPS coordinate and capture time read from its own EXIF
/// metadata — the only source `photo_place_matcher.dart` is ever handed a
/// coordinate from. Both fields are null for a photo with no EXIF data at
/// all (screenshots, images downloaded from chat apps, etc.) — never a
/// fabricated fallback.
typedef PhotoExifData = ({double? latitude, double? longitude, DateTime? takenAt});

/// Reads [file]'s EXIF tags for its GPS coordinate and original capture
/// time. Best-effort, matching this codebase's existing "a supplementary
/// lookup is never worth failing the whole action over" services
/// (`PlacesService`, `WeatherService`): any parse failure — a corrupt file,
/// an unsupported format, no EXIF block at all — just returns all-null
/// fields rather than throwing, so the upload itself always proceeds.
Future<PhotoExifData> readPhotoExif(File file) async {
  try {
    final tags = await readExifFromFile(file);
    final latitude = _decimalFromDmsTag(tags['GPS GPSLatitude'], tags['GPS GPSLatitudeRef']?.printable);
    final longitude = _decimalFromDmsTag(tags['GPS GPSLongitude'], tags['GPS GPSLongitudeRef']?.printable);
    final takenAt = _parseExifDateTime(
      tags['EXIF DateTimeOriginal']?.printable ?? tags['Image DateTime']?.printable,
    );
    return (latitude: latitude, longitude: longitude, takenAt: takenAt);
  } catch (_) {
    return (latitude: null, longitude: null, takenAt: null);
  }
}

double? _decimalFromDmsTag(IfdTag? tag, String? ref) {
  if (tag == null) return null;
  final values = tag.values.toList();
  if (values.length < 3 || values.any((v) => v is! Ratio)) return null;
  return decimalDegreesFromDms(values.cast<Ratio>(), ref);
}

/// Converts a GPS EXIF degrees/minutes/seconds triple (as stored in the
/// `GPS GPSLatitude`/`GPS GPSLongitude` tags) plus its hemisphere reference
/// (`GPS GPSLatitudeRef`/`GPS GPSLongitudeRef` — `'N'`/`'S'`/`'E'`/`'W'`)
/// into a single signed decimal-degrees value. Pulled out as its own
/// function (rather than inlined in [readPhotoExif]) so the conversion math
/// is unit-testable without needing a real JPEG file.
double? decimalDegreesFromDms(List<Ratio> dms, String? ref) {
  if (dms.length < 3) return null;
  final decimal = dms[0].toDouble() + dms[1].toDouble() / 60 + dms[2].toDouble() / 3600;
  return (ref == 'S' || ref == 'W') ? -decimal : decimal;
}

/// EXIF's `DateTimeOriginal`/`DateTime` tags use `"YYYY:MM:DD HH:MM:SS"` —
/// colons in the date portion mean `DateTime.parse` can't read it directly.
DateTime? _parseExifDateTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final match = RegExp(r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})').firstMatch(raw);
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  );
}
