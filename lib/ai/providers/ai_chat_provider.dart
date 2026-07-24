import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/ai_message.dart';
import '../repositories/ai_repository.dart';
import '../services/openai_service.dart';

/// Drives the AI Travel Assistant Chat screen: message history (persisted
/// locally so it survives app restarts), sending, and a typing indicator.
/// Keeps only the most recent [_maxHistoryMessages] turns in the prompt sent
/// to the model to bound token usage while still supporting follow-ups.
class AiChatProvider extends ChangeNotifier {
  AiChatProvider({AiRepository? repository}) : _repository = repository ?? AiRepository() {
    _loadHistory();
  }

  static const String _prefsKey = 'ai_chat_history_v1';
  static const int _maxHistoryMessages = 12;
  static const int _maxStoredMessages = 60;
  static const _uuid = Uuid();

  final AiRepository _repository;

  final List<AiChatMessage> messages = [];
  bool isSending = false;
  String? errorMessage;

  int _requestVersion = 0;

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List;
      messages.addAll(decoded.map((m) => AiChatMessage.fromMap(Map<String, dynamic>.from(m as Map))));
      notifyListeners();
    } catch (_) {
      // Corrupt/old-format cache — start fresh rather than crash the chat.
    }
  }

  Future<void> _persistHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final toStore = messages.length > _maxStoredMessages
        ? messages.sublist(messages.length - _maxStoredMessages)
        : messages;
    await prefs.setString(_prefsKey, jsonEncode(toStore.map((m) => m.toMap()).toList()));
  }

  Future<void> sendMessage(String text, {String? userContext}) async {
    final trimmed = _sanitize(text);
    if (trimmed.isEmpty || isSending) return;

    errorMessage = null;
    messages.add(AiChatMessage(id: _uuid.v4(), role: AiMessageRole.user, content: trimmed, createdAt: DateTime.now()));
    isSending = true;
    notifyListeners();
    unawaited(_persistHistory());

    final version = ++_requestVersion;
    final recentHistory = messages.length > _maxHistoryMessages
        ? messages.sublist(messages.length - _maxHistoryMessages)
        : List<AiChatMessage>.from(messages);

    try {
      final reply = await _repository.sendChatMessage(recentHistory, userContext: userContext);
      if (version != _requestVersion) return;
      messages.add(AiChatMessage(id: _uuid.v4(), role: AiMessageRole.assistant, content: reply, createdAt: DateTime.now()));
    } catch (e) {
      if (version != _requestVersion) return;
      final message = e is AiException ? e.message : 'Something went wrong. Please try again.';
      errorMessage = message;
      messages.add(AiChatMessage(
        id: _uuid.v4(),
        role: AiMessageRole.assistant,
        content: message,
        createdAt: DateTime.now(),
        isError: true,
      ));
    } finally {
      if (version == _requestVersion) {
        isSending = false;
        notifyListeners();
        unawaited(_persistHistory());
      }
    }
  }

  /// Strips control characters and caps length so a runaway paste can't
  /// blow up the token budget or smuggle odd characters into the prompt.
  String _sanitize(String input) {
    final withoutControlChars = input.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
    final trimmed = withoutControlChars.trim();
    return trimmed.length > 2000 ? trimmed.substring(0, 2000) : trimmed;
  }

  Future<void> clearHistory() async {
    messages.clear();
    errorMessage = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
