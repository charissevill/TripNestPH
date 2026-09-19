import 'package:cloud_functions/cloud_functions.dart';

import '../utils/app_exception.dart';
import '../utils/function_caller.dart';

/// A resolved map pin — [name] for display, [countryCode] (ISO 3166-1
/// alpha-2, e.g. "PH") for [MapDestinationPicker] to reject a pin dropped
/// outside the Philippines. [countryCode] is empty when Google's own
/// address data didn't include a country component for that point (rare,
/// but real) — never fabricated, so a caller that needs certainty should
/// treat empty as "unknown," not "not the Philippines."
class GeocodeResult {
  const GeocodeResult({required this.name, required this.countryCode});

  final String name;
  final String countryCode;
}

/// Resolves a dropped map pin's coordinates to a readable place name, via
/// the `reverseGeocode` Cloud Function — never throws for "no result found
/// at that point," only for real failures (not signed in, rate limited).
class GeocodeService {
  GeocodeService({FirebaseFunctions? functions, FunctionCaller? caller})
      : _call = caller ?? firebaseFunctionCaller(functions);

  final FunctionCaller _call;

  Future<GeocodeResult> reverseGeocode({required double latitude, required double longitude}) async {
    try {
      final result = await _call('reverseGeocode', {'latitude': latitude, 'longitude': longitude});
      return GeocodeResult(
        name: result['name'] as String? ?? '',
        countryCode: result['countryCode'] as String? ?? '',
      );
    } on FirebaseFunctionsException catch (e) {
      throw AppException.from(e);
    }
  }
}
