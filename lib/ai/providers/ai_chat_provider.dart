import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/ai_chat_session.dart';
import '../models/ai_message.dart';
import '../repositories/ai_repository.dart';
import '../services/openai_service.dart';

/// Drives the AI Travel Assistant Chat screen: multiple saved conversations
/// ("chats") the traveler can switch between (persisted locally so they
/// survive app restarts), the active one's message history, sending, and a
/// typing indicator. Keeps only the most recent [_maxHistoryMessages] turns
/// of the active chat in the prompt sent to the model to bound token usage
/// while still supporting follow-ups.
class AiChatProvider extends ChangeNotifier {
  AiChatProvider({AiRepository? repository}) : _repository = repository ?? AiRepository() {
    _loadSessions();
  }

  static const String _sessionsPrefsKey = 'ai_chat_sessions_v1';

  /// Where a single, flat conversation used to live before multiple chats
  /// existed — [_loadSessions] migrates it into this traveler's first chat
  /// once, rather than silently discarding their history.
  static const String _legacyPrefsKey = 'ai_chat_history_v1';

  static const int _maxHistoryMessages = 12;
  static const int _maxStoredMessages = 60;

  /// Caps how many past chats are kept around — old ones beyond this just
  /// age out, the same way [_maxStoredMessages] bounds a single chat.
  static const int _maxSessions = 30;

  static const String _newChatTitle = 'New Chat';
  static const _uuid = Uuid();

  final AiRepository _repository;

  final List<AiChatSession> _sessions = [];
  String? _currentSessionId;
  bool isSending = false;
  String? errorMessage;

  int _requestVersion = 0;

  /// Every saved chat, most recently updated first.
  List<AiChatSession> get sessions => List.unmodifiable(_sessions);

  String? get currentSessionId => _currentSessionId;

  /// The active chat's messages — empty until the traveler sends a first
  /// message (a session is only created then, or via [startNewChat]).
  List<AiChatMessage> get messages => _currentSession?.messages ?? const [];

  AiChatSession? get _currentSession {
    final id = _currentSessionId;
    if (id == null) return null;
    for (final session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionsPrefsKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List;
        _sessions.addAll(decoded.map((s) => AiChatSession.fromMap(Map<String, dynamic>.from(s as Map))));
        _currentSessionId = _sessions.isNotEmpty ? _sessions.first.id : null;
        notifyListeners();
        return;
      } catch (_) {
        // Corrupt — fall through and try the legacy key below.
      }
    }

    final legacyRaw = prefs.getString(_legacyPrefsKey);
    if (legacyRaw != null) {
      try {
        final decoded = jsonDecode(legacyRaw) as List;
        final legacyMessages = decoded
            .map((m) => AiChatMessage.fromMap(Map<String, dynamic>.from(m as Map)))
            .toList();
        if (legacyMessages.isNotEmpty) {
          final firstUserMessage = legacyMessages.firstWhere(
            (m) => m.isUser,
            orElse: () => legacyMessages.first,
          );
          final session = AiChatSession(
            id: _uuid.v4(),
            title: _deriveTitle(firstUserMessage.content),
            messages: legacyMessages,
            updatedAt: DateTime.now(),
          );
          _sessions.add(session);
          _currentSessionId = session.id;
          await prefs.setString(_sessionsPrefsKey, jsonEncode([session.toMap()]));
        }
      } catch (_) {
        // Corrupt legacy data — nothing worth migrating.
      }
      await prefs.remove(_legacyPrefsKey);
    }
    notifyListeners();
  }

  Future<void> _persistSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final bounded = _sessions.length > _maxSessions ? _sessions.sublist(0, _maxSessions) : _sessions;
    final toStore = bounded.map((session) {
      final messages = session.messages.length > _maxStoredMessages
          ? session.messages.sublist(session.messages.length - _maxStoredMessages)
          : session.messages;
      return session.copyWith(messages: messages).toMap();
    }).toList();
    await prefs.setString(_sessionsPrefsKey, jsonEncode(toStore));
  }

  /// A short label for the chat list, taken from the traveler's first
  /// message — same idea as every other chat app, without an extra AI call
  /// just to name a conversation.
  String _deriveTitle(String firstMessage) {
    final singleLine = firstMessage.replaceAll('\n', ' ').trim();
    return singleLine.length > 40 ? '${singleLine.substring(0, 40).trimRight()}…' : singleLine;
  }

  /// Moves [updated] to the front of [_sessions] (most-recently-updated
  /// first), replacing the session with the same id.
  void _upsertSession(AiChatSession updated) {
    _sessions.removeWhere((s) => s.id == updated.id);
    _sessions.insert(0, updated);
  }

  void _ensureCurrentSession() {
    if (_currentSession != null) return;
    final session = AiChatSession(id: _uuid.v4(), title: _newChatTitle, messages: const [], updatedAt: DateTime.now());
    _sessions.insert(0, session);
    _currentSessionId = session.id;
  }

  /// Starts a fresh, empty chat and makes it the active one. A no-op beyond
  /// switching to it if the current chat is already empty, so repeatedly
  /// tapping "New Chat" doesn't pile up empty duplicates in the list.
  void startNewChat() {
    final current = _currentSession;
    if (current != null && current.messages.isEmpty) return;
    final session = AiChatSession(id: _uuid.v4(), title: _newChatTitle, messages: const [], updatedAt: DateTime.now());
    _sessions.insert(0, session);
    _currentSessionId = session.id;
    errorMessage = null;
    notifyListeners();
  }

  void switchToSession(String id) {
    if (id == _currentSessionId) return;
    _currentSessionId = id;
    errorMessage = null;
    notifyListeners();
  }

  /// Deletes a chat entirely (its own confirmation dialog lives in the UI
  /// layer, same as every other destructive action in this app). Falls back
  /// to the next most recent chat — or no active chat at all, same as a
  /// fresh install — when the deleted one was the active one.
  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    if (_currentSessionId == id) {
      _currentSessionId = _sessions.isNotEmpty ? _sessions.first.id : null;
    }
    notifyListeners();
    await _persistSessions();
  }

  Future<void> sendMessage(String text, {String? userContext}) async {
    final trimmed = _sanitize(text);
    if (trimmed.isEmpty || isSending) return;

    errorMessage = null;
    _ensureCurrentSession();
    final session = _currentSession!;
    final sessionId = session.id;
    final isFirstMessage = session.messages.isEmpty;
    final userMessage = AiChatMessage(id: _uuid.v4(), role: AiMessageRole.user, content: trimmed, createdAt: DateTime.now());
    _upsertSession(
      session.copyWith(
        messages: [...session.messages, userMessage],
        title: isFirstMessage ? _deriveTitle(trimmed) : session.title,
        updatedAt: DateTime.now(),
      ),
    );
    isSending = true;
    notifyListeners();
    unawaited(_persistSessions());

    final version = ++_requestVersion;
    final history = _currentSession!.messages;
    final recentHistory = history.length > _maxHistoryMessages
        ? history.sublist(history.length - _maxHistoryMessages)
        : history;

    try {
      final reply = await _repository.sendChatMessage(recentHistory, userContext: userContext);
      if (version != _requestVersion) return;
      _appendToSession(
        sessionId,
        AiChatMessage(id: _uuid.v4(), role: AiMessageRole.assistant, content: reply, createdAt: DateTime.now()),
      );
    } catch (e) {
      if (version != _requestVersion) return;
      final message = e is AiException ? e.message : 'Something went wrong. Please try again.';
      errorMessage = message;
      _appendToSession(
        sessionId,
        AiChatMessage(
          id: _uuid.v4(),
          role: AiMessageRole.assistant,
          content: message,
          createdAt: DateTime.now(),
          isError: true,
        ),
      );
    } finally {
      if (version == _requestVersion) {
        isSending = false;
        notifyListeners();
        unawaited(_persistSessions());
      }
    }
  }

  /// Appends to [sessionId] specifically (not just "whichever chat is
  /// current") — the traveler may have switched to a different chat while
  /// this reply was in flight, and it belongs to the one that asked for it.
  void _appendToSession(String sessionId, AiChatMessage message) {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return;
    final updated = _sessions[index].copyWith(messages: [..._sessions[index].messages, message], updatedAt: DateTime.now());
    _upsertSession(updated);
  }

  /// Strips control characters and caps length so a runaway paste can't
  /// blow up the token budget or smuggle odd characters into the prompt.
  String _sanitize(String input) {
    final withoutControlChars = input.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
    final trimmed = withoutControlChars.trim();
    return trimmed.length > 2000 ? trimmed.substring(0, 2000) : trimmed;
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
