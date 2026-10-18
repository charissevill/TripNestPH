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

  test('a reply in flight belongs to its own chat, not whichever one is open', () async {
    final ai = _FakeAi();
    final chat = _provider(ai);
    await chat.bindToUser('userA');

    final pending = Completer<String>();
    ai.replies.add(pending.future);
    final sending = chat.sendMessage('Chat A question');
    final chatA = chat.currentSessionId!;
    await Future<void>.delayed(Duration.zero);

    chat.startNewChat();
    // Chat B's composer isn't locked by A's reply, and its Stop can't stop it.
    expect(chat.isSending, isFalse);
    chat.stopGenerating();

    pending.complete('Answer for A');
    await sending;
    expect(chat.messages, isEmpty);
    chat.switchToSession(chatA);
    expect(chat.messages.map((m) => m.content), ['Chat A question', 'Answer for A']);
  });

  test('the message shows, and the chat counts as sending, while its real-data context loads', () async {
    final ai = _FakeAi()..replies.add('Try Vigan.');
    final chat = _provider(ai);
    await chat.bindToUser('userA');

    final context = Completer<String?>();
    final sending = chat.sendMessage('Where in Ilocos?', loadUserContext: () => context.future);
    final askedFrom = chat.currentSessionId!;
    expect(chat.messages.single.content, 'Where in Ilocos?');
    expect(chat.isSending, isTrue);

    // Switching chats before the context arrives doesn't move the reply.
    chat.startNewChat();
    context.complete('CTX-near-Laoag');
    await sending;

    expect(ai.sentMessages.single.first['content'], contains('CTX-near-Laoag'));
    expect(chat.messages, isEmpty);
    chat.switchToSession(askedFrom);
    expect(chat.messages.map((m) => m.content), ['Where in Ilocos?', 'Try Vigan.']);
  });

  test('stopping while the context still loads never calls the AI', () async {
    final ai = _FakeAi();
    final chat = _provider(ai);
    await chat.bindToUser('userA');

    final context = Completer<String?>();
    final sending = chat.sendMessage('Food in Ilocos?', loadUserContext: () => context.future);
    chat.stopGenerating();
    context.complete(null);
    await sending;

    expect(ai.sentMessages, isEmpty);
    expect(chat.messages.map((m) => m.content), ['Food in Ilocos?']);
  });

  group('regenerating a real answer', () {
    Future<AiChatProvider> answered(_FakeAi ai) async {
      final chat = _provider(ai);
      await chat.bindToUser('userA');
      ai.replies.add('Try Moalboal.');
      await chat.sendMessage('Beaches in Cebu?');
      return chat;
    }

    test('keeps the old answer when the redo fails', () async {
      final ai = _FakeAi();
      final chat = await answered(ai);

      ai.replies.add('');
      await chat.regenerateLastReply();

      expect(chat.messages.map((m) => m.content).take(2), ['Beaches in Cebu?', 'Try Moalboal.']);
      expect(chat.messages, hasLength(3));
      expect(chat.messages.last.isError, isTrue);
    });

    test('puts the old answer back when the redo is stopped', () async {
      final ai = _FakeAi();
      final chat = await answered(ai);

      final pending = Completer<String>();
      ai.replies.add(pending.future);
      final redo = chat.regenerateLastReply();
      expect(chat.messages.map((m) => m.content), ['Beaches in Cebu?']);

      chat.stopGenerating();
      expect(chat.messages.map((m) => m.content), ['Beaches in Cebu?', 'Try Moalboal.']);
      pending.complete('Too late');
      await redo;
      expect(chat.messages.map((m) => m.content), ['Beaches in Cebu?', 'Try Moalboal.']);
    });

    test('still saves the old answer while the redo is in flight', () async {
      final ai = _FakeAi();
      final chat = await answered(ai);

      ai.replies.add(Completer<String>().future);
      unawaited(chat.regenerateLastReply());
      await Future<void>.delayed(Duration.zero);

      // e.g. the app closed mid-regenerate and was opened again.
      final reopened = _provider(_FakeAi());
      await reopened.bindToUser('userA');
      expect(reopened.messages.map((m) => m.content), ['Beaches in Cebu?', 'Try Moalboal.']);
    });
  });

  group('chats saved before they were per account', () {
    Map<String, Object> oldChat(String title) => {
          'id': 'id-$title',
          'title': title,
          'updatedAt': DateTime(2026, 10, 1).toIso8601String(),
          'messages': [
            {'id': 'm-$title', 'role': 'user', 'content': title, 'createdAt': DateTime(2026, 10, 1).toIso8601String()},
          ],
        };
    final legacyHistory = jsonEncode([
      {'id': 'l1', 'role': 'user', 'content': 'Legacy question', 'createdAt': DateTime(2026, 9, 1).toIso8601String()},
    ]);

    test('aren\'t claimed by an account that signs in after starting signed out', () async {
      SharedPreferences.setMockInitialValues({
        'ai_chat_sessions_v1': jsonEncode([oldChat('Old chat')]),
        'ai_chat_history_v1': legacyHistory,
      });
      final chat = _provider(_FakeAi());

      await chat.bindToUser(null);
      await chat.bindToUser('userB');

      expect(chat.sessions, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ai_chat_sessions_v1'), isNull);
      expect(prefs.getString('ai_chat_history_v1'), isNull);
    });

    test('the oldest single-chat history is retired even when the account has chats of its own', () async {
      SharedPreferences.setMockInitialValues({
        'ai_chat_sessions_v1_userA': jsonEncode([oldChat('Own chat')]),
        'ai_chat_history_v1': legacyHistory,
      });
      final chat = _provider(_FakeAi());

      await chat.bindToUser('userA');
      expect(chat.sessions.single.title, 'Own chat');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ai_chat_history_v1'), isNull);

      await chat.bindToUser('userB');
      expect(chat.sessions, isEmpty);
    });
  });

  test('a chat started while saved chats are still loading keeps both', () async {
    SharedPreferences.setMockInitialValues({
      'ai_chat_sessions_v1_userA': jsonEncode([
        {
          'id': 'old',
          'title': 'Old chat',
          'updatedAt': DateTime(2026, 10, 1).toIso8601String(),
          'messages': [
            {'id': 'm1', 'role': 'user', 'content': 'Old question', 'createdAt': DateTime(2026, 10, 1).toIso8601String()},
          ],
        },
      ]),
    });
    final ai = _FakeAi()..replies.add('Sure!');
    final chat = _provider(ai);

    final binding = chat.bindToUser('userA');
    final sending = chat.sendMessage('New question');
    await binding;
    await sending;

    expect(chat.sessions.map((s) => s.title), ['New question', 'Old chat']);
    final reopened = _provider(_FakeAi());
    await reopened.bindToUser('userA');
    expect(reopened.sessions.map((s) => s.title), ['New question', 'Old chat']);
  });
}
