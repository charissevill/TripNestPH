import 'package:cloud_functions/cloud_functions.dart';

import '../utils/app_exception.dart';
import '../utils/function_caller.dart';

/// Reads text out of an uploaded business permit via the
/// `extractPermitText` Cloud Function, which proxies Google Cloud Vision's
/// TEXT_DETECTION. Purely a reading aid — never throws for "no text found,"
/// only for real failures (not signed in, rate limited, service down).
///
/// Takes only [businessId], never an image URL — the function reads the
/// permit URL itself from `businesses/{businessId}/private/permit` after
/// verifying ownership, and writes `permitOcrText` back there directly
/// (Admin SDK). This is also the only way that field is ever set — see
/// firestore.rules, which forbids a client from writing it.
class OcrService {
  OcrService({FirebaseFunctions? functions, FunctionCaller? caller})
      : _call = caller ?? firebaseFunctionCaller(functions);

  final FunctionCaller _call;

  Future<String> extractText(String businessId) async {
    try {
      final result = await _call('extractPermitText', {'businessId': businessId});
      return result['text'] as String? ?? '';
    } on FirebaseFunctionsException catch (e) {
      throw AppException.from(e);
    }
  }

  /// Same thing for the permit on a Business Owner application
  /// (`extractApplicationPermitText`) — an applicant has no business doc
  /// yet, so this keys off their own [applicationId] instead.
  Future<String> extractApplicationText(String applicationId) async {
    try {
      final result = await _call('extractApplicationPermitText', {'applicationId': applicationId});
      return result['text'] as String? ?? '';
    } on FirebaseFunctionsException catch (e) {
      throw AppException.from(e);
    }
  }
}
