import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show PlatformException;

/// A user-facing error message derived from whatever backend exception was
/// thrown, so screens never have to interpret raw Firebase error codes.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;

  /// Converts any error (Firebase or otherwise) into an [AppException] with
  /// a short, friendly message safe to show directly in the UI.
  factory AppException.from(Object error) {
    if (error is AppException) return error;
    if (error is FirebaseAuthException) return AppException(_authMessage(error));
    if (error is FirebaseException) return AppException(_firestoreOrStorageMessage(error));
    // Google Sign-In throws this natively (Play Services unavailable,
    // account picker error, native network failure) rather than a
    // FirebaseAuthException — surfacing its message beats the generic
    // fallback, since it's usually specific enough to point at a fix (e.g.
    // "Play Services is out of date").
    if (error is PlatformException) {
      return AppException(error.message ?? 'Something went wrong. Please try again.');
    }
    return const AppException('Something went wrong. Please try again.');
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
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      case 'account-exists-with-different-credential':
        return 'This email is already linked to a different sign-in method.';
      case 'popup-closed-by-user':
      case 'canceled':
      case 'sign_in_canceled':
        return 'Sign-in was cancelled.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  static String _firestoreOrStorageMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You don\'t have permission to do that.';
      case 'unavailable':
      case 'network-request-failed':
        return 'No internet connection. Showing the latest saved data.';
      case 'not-found':
        return 'That item could not be found.';
      case 'cancelled':
      case 'canceled':
        return 'The request was cancelled.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}

/// True for the specific Firestore "no connectivity" condition, so callers
/// can fall back to cached data instead of showing a hard error state.
bool isOfflineException(Object error) {
  if (error is FirebaseException) {
    return error.code == 'unavailable' || error.code == 'network-request-failed';
  }
  return false;
}
