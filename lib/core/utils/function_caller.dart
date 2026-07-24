import 'package:cloud_functions/cloud_functions.dart';

/// Invokes a named Cloud Function with [data] and returns its result as a
/// map. Abstracted away from [FirebaseFunctions] directly so services that
/// depend on it (`OpenAiService`, `PlacesService`) can be unit-tested with a
/// plain fake instead of the real `cloud_functions` plugin, which talks to
/// a platform channel that isn't available in `flutter test`.
typedef FunctionCaller = Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data);

/// The real implementation, backed by [functions] (defaults to the region
/// every Cloud Function in this project is deployed to).
///
/// Resolves [functions] lazily, on first actual call, rather than eagerly
/// in this function body: `FirebaseFunctions.instanceFor` throws
/// synchronously if `Firebase.initializeApp()` hasn't run yet, and a widget
/// test that never calls the returned closure (e.g. one that only
/// exercises a code path with no Places/AI involved) shouldn't have to
/// initialize Firebase just because `PlacesService()`/`OpenAiService()`
/// were constructed with no override.
FunctionCaller firebaseFunctionCaller([FirebaseFunctions? functions]) {
  FirebaseFunctions? resolved = functions;
  return (name, data) async {
    final instance = resolved ??= FirebaseFunctions.instanceFor(region: 'asia-southeast1');
    final result = await instance.httpsCallable(name).call<Map<String, dynamic>>(data);
    return result.data;
  };
}
