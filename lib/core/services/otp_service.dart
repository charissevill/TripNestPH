import 'package:cloud_functions/cloud_functions.dart';

import '../utils/app_exception.dart';
import '../utils/function_caller.dart';

/// Thin wrapper around the four numeric-code Cloud Functions
/// (`requestPasswordResetCode`/`verifyPasswordResetCode`/
/// `requestEmailVerificationCode`/`verifyEmailVerificationCode` — see
/// `functions/index.js`) — same `firebaseFunctionCaller` pattern
/// `OpenAiService`/`PlacesService` already use, kept as its own service
/// (not folded into [AuthService]) since that class is scoped to direct
/// Firebase Auth SDK calls only, not Cloud Functions.
class OtpService {
  OtpService({FirebaseFunctions? functions, FunctionCaller? caller})
      : _call = caller ?? firebaseFunctionCaller(functions);

  final FunctionCaller _call;

  /// Codes whose message these functions author themselves as user-facing
  /// text ("Incorrect code. Please try again.", "This code has expired…").
  /// Every other code — including anything the platform or a dependency
  /// raises — is mapped to a generic message instead of echoing the server.
  static const _curatedMessageCodes = {'invalid-argument', 'resource-exhausted', 'failed-precondition'};

  AppException _friendly(FirebaseFunctionsException e) {
    logTechnicalError(e);
    final serverMessage = e.message?.trim();
    if (_curatedMessageCodes.contains(e.code) && serverMessage != null && serverMessage.isNotEmpty) {
      return AppException(serverMessage);
    }
    return AppException(functionsMessage(e.code));
  }

  Future<void> requestPasswordResetCode(String email) async {
    try {
      await _call('requestPasswordResetCode', {'email': email.trim()});
    } on FirebaseFunctionsException catch (e) {
      throw _friendly(e);
    }
  }

  Future<void> verifyPasswordResetCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _call('verifyPasswordResetCode', {
        'email': email.trim(),
        'code': code.trim(),
        'newPassword': newPassword,
      });
    } on FirebaseFunctionsException catch (e) {
      throw _friendly(e);
    }
  }

  /// Returns true if the account was already verified (nothing was sent —
  /// there's nothing to verify).
  Future<bool> requestEmailVerificationCode() async {
    try {
      final result = await _call('requestEmailVerificationCode', const {});
      return result['alreadyVerified'] == true;
    } on FirebaseFunctionsException catch (e) {
      throw _friendly(e);
    }
  }

  Future<void> verifyEmailVerificationCode(String code) async {
    try {
      await _call('verifyEmailVerificationCode', {'code': code.trim()});
    } on FirebaseFunctionsException catch (e) {
      throw _friendly(e);
    }
  }
}
