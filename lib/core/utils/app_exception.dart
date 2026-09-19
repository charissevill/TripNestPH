import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:http/http.dart' show ClientException;

const String _genericMessage = 'Something went wrong. Please try again.';
const String _networkMessage = 'No internet connection. Please check your network and try again.';
const String _timeoutMessage = 'This is taking longer than expected. Please check your connection and try again.';

/// A user-facing error message derived from whatever backend exception was
/// thrown, so screens never have to interpret raw Firebase error codes.
///
/// [message] is always safe to show directly in the UI — it is never built
/// from an exception's own `message`/`toString()`, since those routinely
/// carry Firebase error codes, API responses, or stack-trace fragments.
/// The underlying technical detail is only written to the debug log (see
/// [AppException.from]).
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;

  /// Converts any error (Firebase or otherwise) into an [AppException] with
  /// a short, friendly message safe to show directly in the UI.
  factory AppException.from(Object error) {
    if (error is AppException) return error;
    logTechnicalError(error);
    if (error is FirebaseAuthException) return AppException(_authMessage(error));
    if (error is FirebaseFunctionsException) return AppException(functionsMessage(error.code));
    if (error is FirebaseException) return AppException(_firestoreOrStorageMessage(error));
    // Google Sign-In (and image_picker, geolocator, etc.) throw this natively
    // rather than a Firebase exception. Its `message` is a raw platform
    // string (often a stack-trace fragment or an `ApiException: 10`), so
    // only the code is inspected, never the message.
    if (error is PlatformException) return AppException(_platformMessage(error));
    if (error is TimeoutException) return const AppException(_timeoutMessage);
    if (error is SocketException ||
        error is HandshakeException ||
        error is HttpException ||
        error is ClientException) {
      return const AppException(_networkMessage);
    }
    if (error is FormatException || error is TypeError) {
      return const AppException('We received an unexpected response. Please try again.');
    }
    return const AppException(_genericMessage);
  }

  static String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address doesn\'t look right.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'weak-password':
        return 'Please choose a stronger password (at least 8 characters).';
      case 'requires-recent-login':
        return 'Please sign in again to complete this action.';
      case 'user-token-expired':
      case 'invalid-user-token':
      case 'user-mismatch':
        return 'Your session has expired. Please sign in again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return _networkMessage;
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
        return 'This email is already linked to a different sign-in method.';
      case 'operation-not-allowed':
        return 'This sign-in method isn\'t available right now. Please try another way to sign in.';
      case 'invalid-verification-code':
      case 'invalid-action-code':
      case 'expired-action-code':
        return 'That link or code is invalid or has expired. Please request a new one.';
      case 'popup-closed-by-user':
      case 'canceled':
      case 'sign_in_canceled':
        return 'Sign-in was cancelled.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  static String _firestoreOrStorageMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
      case 'unauthorized':
      case 'unauthenticated':
        return 'You don\'t have permission to perform this action.';
      case 'unavailable':
      case 'network-request-failed':
        return _networkMessage;
      case 'deadline-exceeded':
      case 'retry-limit-exceeded':
        return _timeoutMessage;
      case 'not-found':
      case 'object-not-found':
        return 'That item could not be found.';
      case 'already-exists':
        return 'That already exists.';
      case 'resource-exhausted':
      case 'quota-exceeded':
        return 'We\'re a bit busy right now. Please try again in a moment.';
      case 'cancelled':
      case 'canceled':
        return 'The request was cancelled.';
      default:
        return _genericMessage;
    }
  }

  static String _platformMessage(PlatformException e) {
    switch (e.code) {
      case 'network_error':
        return _networkMessage;
      case 'sign_in_canceled':
      case 'canceled':
        return 'Sign-in was cancelled.';
      case 'photo_access_denied':
      case 'camera_access_denied':
      case 'permission-denied':
        return 'Permission was denied. Please allow access in your device settings and try again.';
      default:
        return _genericMessage;
    }
  }
}

/// Maps a Cloud Functions error [code] to a friendly message, for callers
/// that never want to echo the server's own message text back to the user
/// (some functions relay upstream API error bodies verbatim).
String functionsMessage(String code) {
  switch (code) {
    case 'unauthenticated':
      return 'Please sign in to continue.';
    case 'permission-denied':
      return 'You don\'t have permission to perform this action.';
    case 'resource-exhausted':
      return 'Too many requests right now. Please wait a moment and try again.';
    case 'unavailable':
      return _networkMessage;
    case 'deadline-exceeded':
      return _timeoutMessage;
    case 'not-found':
      return 'That item could not be found.';
    case 'invalid-argument':
      return 'That request couldn\'t be processed. Please check your input and try again.';
    case 'failed-precondition':
      return 'This feature isn\'t available right now. Please try again later.';
    case 'cancelled':
      return 'The request was cancelled.';
    default:
      return _genericMessage;
  }
}

/// Writes the raw error to the debug log only. Nothing here ever reaches the
/// UI; in release builds it is a no-op (crash reporting is handled
/// separately in `main.dart`).
void logTechnicalError(Object error, [StackTrace? stackTrace]) {
  if (!kDebugMode) return;
  debugPrint('[TripNest error] ${error.runtimeType}: $error');
  if (stackTrace != null) debugPrint('$stackTrace');
}

/// True for the specific Firestore "no connectivity" condition, so callers
/// can fall back to cached data instead of showing a hard error state.
bool isOfflineException(Object error) {
  if (error is FirebaseException) {
    return error.code == 'unavailable' || error.code == 'network-request-failed';
  }
  return false;
}
