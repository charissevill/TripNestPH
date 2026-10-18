import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tripnest_ph/ai/providers/ai_chat_provider.dart';
import 'package:tripnest_ph/ai/repositories/ai_repository.dart';
import 'package:tripnest_ph/ai/services/openai_service.dart';
import 'package:tripnest_ph/core/utils/function_caller.dart';

/// Answers each `aiComplete` call with the next reply in [replies] (or
/// waits on a [Completer] when the test needs a reply still in flight).
class _FakeAi {
  final List<FutureOr<String>> replies = [];
  final List<List<Map<String, dynamic>>> sentMessages = [];

  FunctionCaller get caller => (name, data) async {
        sentMessages.add(List<Map<String, dynamic>>.from((data['messages'] as List).map((m) => Map<String, dynamic>.from(m as Map))));
        return {'content': await replies.removeAt(0)};
      };
}

AiChatProvider _provider(_FakeAi ai) =>
    AiChatProvider(repository: AiRepository(openAiService: OpenAiService(caller: ai.caller)));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keeps each account\'s chats separate on the same device', () async {
    final ai = _FakeAi()..replies.addAll(['Hi traveler A', 'Hi traveler B']);
    final chat = _provider(ai);

    await chat.bindToUser('userA');
    await chat.sendMessage('Hello from A');
    expect(chat.sessions, hasLength(1));

    await chat.bindToUser(null);
    expect(chat.sessions, isEmpty);

    await chat.bindToUser('userB');
    expect(chat.sessions, isEmpty);
    await chat.sendMessage('Hello from B');

    await chat.bindToUser('userA');
    expect(chat.messages.map((m) => m.content), ['Hello from A', 'Hi traveler A']);
  });

  test('hands the old shared chat history to the first account only', () async {
    SharedPreferences.setMockInitialValues({
      'ai_chat_sessions_v1': jsonEncode([
        {
          'id': 's1',
          'title': 'Old chat',
          'updatedAt': DateTime(2026, 10, 1).toIso8601String(),
          'messages': [
            {'id': 'm1', 'role': 'user', 'content': 'Old question', 'createdAt': DateTime(2026, 10, 1).toIso8601String()},
          ],
        },
      ]),
    });
    final chat = _provider(_FakeAi());

    await chat.bindToUser('userA');
    expect(chat.sessions.single.title, 'Old chat');

    await chat.bindToUser('userB');
    expect(chat.sessions, isEmpty);
  });

  test('regenerate replaces an error reply with a fresh answer', () async {
    final ai = _FakeAi();
    final chat = _provider(ai);
    await chat.bindToUser('userA');

    ai.replies.add('');
    await chat.sendMessage('Beaches in Cebu?');
    expect(chat.messages.last.isError, isTrue);
    expect(chat.canRegenerate, isTrue);

    ai.replies.add('Try Moalboal.');
    await chat.regenerateLastReply();
    expect(chat.messages.map((m) => m.content), ['Beaches in Cebu?', 'Try Moalboal.']);
    // The error bubble isn't sent back as if the assistant had said it.
    expect(ai.sentMessages.last.where((m) => m['role'] == 'assistant'), isEmpty);
  });

  test('stop discards the reply in flight and keeps the question', () async {
    final ai = _FakeAi();
    final chat = _provider(ai);
    await chat.bindToUser('userA');

    final pending = Completer<String>();
    ai.replies.add(pending.future);
    final sending = chat.sendMessage('Food in Ilocos?');
    await Future<void>.delayed(Duration.zero);
    expect(chat.isSending, isTrue);

    chat.stopGenerating();
    expect(chat.isSending, isFalse);
    pending.complete('Too late');
    await sending;

    expect(chat.messages.map((m) => m.content), ['Food in Ilocos?']);
    expect(chat.lastUserMessage, 'Food in Ilocos?');
    expect(chat.canRegenerate, isTrue);
  });
}
