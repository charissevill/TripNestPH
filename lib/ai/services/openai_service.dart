import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../../core/utils/function_caller.dart';

/// Thrown for every AI-call failure mode so callers can show one friendly
/// message without inspecting error codes themselves.
class AiException implements Exception {
  const AiException(this.message, {this.isConfigError = false, this.retryable = false});

  final String message;

  /// True when the problem is a missing/invalid API key — the app should
  /// point the user at a graceful fallback (see [AiRepository]) rather than
  /// "try again".
  final bool isConfigError;

  /// True for transient failures (rate limits, 5xx) — [OpenAiService.complete]
  /// retries these automatically before giving up and surfacing them.
  final bool retryable;

  @override
  String toString() => message;
}

/// A single request superseded by a newer one (cancellation-by-versioning,
/// see [AiPlannerProvider]/[AiChatProvider]). Never shown to the user.
class AiRequestCancelled implements Exception {
  const AiRequestCancelled();
}

/// Thin wrapper around the `aiComplete` Cloud Function, which itself proxies
/// OpenAI's Chat Completions REST API. Holds no conversation or app state —
/// that's the repository/provider layers' job.
///
/// Deliberately routed through a Cloud Function rather than calling OpenAI
/// directly from the client: `flutter_dotenv` loads `.env` as a plain app
/// asset, so a client-embedded `OPENAI_API_KEY` would ship inside the
/// APK/web build in cleartext — extractable by anyone who unzips it. The
/// Cloud Function holds the real key in Secret Manager instead; the client
/// only ever holds a signed-in user's Firebase Auth token, which is exactly
/// what every other screen already requires to reach the AI Planner or
/// Trip Assistant in the first place (see `app_router.dart`'s redirect).
class OpenAiService {
  OpenAiService({FirebaseFunctions? functions, FunctionCaller? caller})
      : _call = caller ?? firebaseFunctionCaller(functions);

  final FunctionCaller _call;

  /// Sends a chat-completions request and returns the assistant's text.
  ///
  /// [messages] is the full `[{role, content}, ...]` list including any
  /// system prompt. [jsonMode] requests a guaranteed-JSON response (used by
  /// the itinerary generator). Throws [AiException] for every failure mode.
  Future<String> complete({
    required List<Map<String, String>> messages,
    double temperature = 0.7,
    int maxTokens = 1200,
    bool jsonMode = false,
  }) async {
    // Retries transient failures — timeouts, dropped connections, rate
    // limits, and 5xx responses — with a short backoff, so a traveler
    // doesn't have to manually tap "try again" for a blip that resolves
    // itself half a second later. Config errors and bad requests are never
    // retried; retrying those would just fail the same way three times
    // slower.
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final isLastAttempt = attempt == maxAttempts;
      try {
        final result = await _call('aiComplete', {
          'messages': messages,
          'temperature': temperature,
          'maxTokens': maxTokens,
          'jsonMode': jsonMode,
        });
        final content = result['content'] as String?;
        if (content == null || content.trim().isEmpty) {
          throw const AiException('The AI returned an empty response. Please try again.');
        }
        return content;
      } on FirebaseFunctionsException catch (e) {
        final mapped = _mapException(e);
        if (!mapped.retryable || isLastAttempt) throw mapped;
      } on AiException {
        rethrow;
      } catch (_) {
        if (isLastAttempt) throw const AiException('Something went wrong reaching the AI service. Please try again.');
      }
      await Future.delayed(Duration(seconds: attempt));
    }
    // Unreachable — the loop above always returns or throws on its last
    // attempt — but required so every code path has a return value.
    throw const AiException('Something went wrong reaching the AI service. Please try again.');
  }

  AiException _mapException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return AiException(e.message ?? 'Sign in to use AI features.', isConfigError: true);
      case 'failed-precondition':
        return AiException(e.message ?? 'AI features aren\'t set up yet.', isConfigError: true);
      case 'resource-exhausted':
        return const AiException('Too many requests right now. Please wait a moment and try again.', retryable: true);
      case 'invalid-argument':
        return AiException(e.message ?? 'The AI could not process that request.');
      case 'unavailable':
        return const AiException('The AI service is temporarily unavailable. Please try again shortly.', retryable: true);
      default:
        return AiException(e.message ?? 'The AI service returned an unexpected error.');
    }
  }
}
