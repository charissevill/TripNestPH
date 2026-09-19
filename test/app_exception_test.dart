import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripnest_ph/ai/services/openai_service.dart';
import 'package:tripnest_ph/core/utils/app_exception.dart';

/// Technical text that must never reach a traveler.
const _rawLeaks = [
  'cloud_firestore/',
  'firebase_auth/',
  '[core/',
  'FirebaseException',
  'PlatformException',
  'SocketException',
  'Groq',
  'API key',
  'ApiException',
  'stack',
];

void expectFriendly(Object error) {
  final message = AppException.from(error).message;
  expect(message, isNotEmpty);
  for (final leak in _rawLeaks) {
    expect(message.toLowerCase(), isNot(contains(leak.toLowerCase())), reason: 'leaked "$leak" for ${error.runtimeType}');
  }
}

void main() {
  group('AppException.from never exposes raw error text', () {
    test('Firestore errors with a raw message', () {
      final e = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: '[cloud_firestore/permission-denied] Missing or insufficient permissions.',
      );
      expect(AppException.from(e).message, 'You don\'t have permission to perform this action.');
    });

    test('unknown Firestore/Auth codes fall back to a generic message', () {
      expectFriendly(FirebaseException(plugin: 'cloud_firestore', code: 'weird-new-code', message: '[cloud_firestore/weird-new-code] boom'));
      expectFriendly(FirebaseAuthException(code: 'weird-new-code', message: '[firebase_auth/weird-new-code] boom'));
    });

    test('Cloud Functions errors ignore the server message', () {
      final e = FirebaseFunctionsException(message: 'The Groq API key is invalid.', code: 'failed-precondition');
      expectFriendly(e);
    });

    test('platform errors ignore the native message', () {
      expectFriendly(PlatformException(code: 'sign_in_failed', message: 'com.google.android.gms.common.api.ApiException: 10'));
      expect(
        AppException.from(PlatformException(code: 'network_error', message: 'ApiException: 7')).message,
        contains('internet'),
      );
    });

    test('timeouts, network failures and bad data', () {
      expect(AppException.from(TimeoutException('x')).message, contains('longer than expected'));
      expect(AppException.from(const SocketException('Failed host lookup')).message, contains('internet'));
      expectFriendly(const FormatException('Unexpected character at 0'));
      expectFriendly(StateError('Bad state: no element'));
      expectFriendly(Exception('anything at all'));
    });

    test('AppException and AiException pass through unchanged', () {
      const own = AppException('You\'ve already reported this review.');
      expect(AppException.from(own), same(own));
      const ai = AiException('Too many requests right now.', retryable: true);
      expect(AppException.from(ai).message, 'Too many requests right now.');
    });
  });

  group('functionsMessage', () {
    test('maps every common code to a non-technical sentence', () {
      for (final code in ['unauthenticated', 'permission-denied', 'resource-exhausted', 'unavailable', 'deadline-exceeded', 'invalid-argument', 'internal', 'unknown']) {
        expect(functionsMessage(code), isNot(contains(code)));
      }
    });
  });
}
