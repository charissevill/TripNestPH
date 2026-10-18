import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/app_exception.dart';
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
///
/// Chats are stored per signed-in account (see [bindToUser]) — the
/// provider outlives sign-out/sign-in in `main.dart`, so a single shared
/// key used to show one traveler's conversations to whoever signed in next
/// on the same device.
class AiChatProvider extends ChangeNotifier {
  AiChatProvider({AiRepository? repository}) : _repository = repository ?? AiRepository();

  static const String _sessionsPrefsKeyPrefix = 'ai_chat_sessions_v1';

  /// Where every account's chats used to live together before they were
  /// scoped per user — [_readSessions] hands it to the account already
  /// signed in when the app starts (the one using the app right before the
  /// update), then deletes it so no later account can inherit it.
  static const String _unscopedSessionsPrefsKey = 'ai_chat_sessions_v1';

  /// Where a single, flat conversation used to live before multiple chats
  /// existed — [_readSessions] migrates it into this traveler's first chat
  /// once (same rule as [_unscopedSessionsPrefsKey]), rather than silently
  /// discarding their history.
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
  String? _userId;
  bool _hasBound = false;
  String? errorMessage;

  /// Replies being waited on, by chat id → that request's version. Per chat
  /// rather than one flag for the whole provider, so a reply still in flight
  /// for one chat doesn't lock the composer (or get stopped by the Stop
  /// button) in a different chat the traveler switched to meanwhile.
  final Map<String, int> _inFlight = {};
  int _requestCounter = 0;

  /// The reply [regenerateLastReply] took off screen while a fresh one is
  /// generated, by chat id — put back if the redo fails or is stopped, so
  /// regenerating never costs the traveler an answer they already had.
  /// Saved along with the chat while the redo is in flight (see
  /// [_persistSessions]), so closing the app mid-regenerate can't lose it
  /// either.
  final Map<String, List<AiChatMessage>> _replacedReplies = {};

  /// Bumped on every [bindToUser] so a slow prefs read for the previous
  /// account can't land after the switch and repopulate its chats.
  int _loadVersion = 0;

  /// True while [bindToUser] is still reading this account's saved chats —
  /// [_persistSessions] holds off until then, or a chat started in that
  /// window would overwrite everything saved with just itself.
  bool _loading = false;

  String _sessionsPrefsKey(String userId) => '${_sessionsPrefsKeyPrefix}_$userId';

  /// True while the active chat is waiting on a reply.
  bool get isSending {
    final id = _currentSessionId;
    return id != null && _inFlight.containsKey(id);
  }

  /// Swaps in [userId]'s saved chats (or none, when signed out), dropping
  /// any reply still in flight for the previous account. Called from
  /// `main.dart` on every auth change, including the first one at startup
  /// (signed out or not).
  Future<void> bindToUser(String? userId) async {
    if (_hasBound && userId == _userId) return;
    // Chats saved before they were scoped per account only go to an account
    // that was already signed in when the app started — whoever was using
    // the app right before the update. A later sign-in, on a shared phone,
    // may be someone else entirely.
    final mayClaimUnscoped = !_hasBound;
    _hasBound = true;
    _userId = userId;
    final loadVersion = ++_loadVersion;
    _inFlight.clear();
    _replacedReplies.clear();
    errorMessage = null;
    _sessions.clear();
    _currentSessionId = null;
    _loading = userId != null;
    notifyListeners();
    if (userId == null) return;

    List<AiChatSession> loaded;
    try {
      loaded = await _readSessions(userId, mayClaimUnscoped: mayClaimUnscoped);
    } catch (e) {
      logTechnicalError(e);
      loaded = const [];
    }
    if (loadVersion != _loadVersion) return;
    _loading = false;
    // A chat started while the read was in flight stays, in front — it's
    // newer than anything saved.
    final startedMeanwhile = _sessions.map((s) => s.id).toSet();
    _sessions.addAll(loaded.where((s) => !startedMeanwhile.contains(s.id)));
    _currentSessionId ??= _sessions.isNotEmpty ? _sessions.first.id : null;
    notifyListeners();
    if (startedMeanwhile.isNotEmpty) await _persistSessions();
  }

  /// Every saved chat, most recently updated first.
  List<AiChatSession> get sessions => List.unmodifiable(_sessions);

  String? get currentSessionId => _currentSessionId;

  /// The active chat's messages — empty until the traveler sends a first
  /// message (a session is only created then, or via [startNewChat]).
  List<AiChatMessage> get messages => _currentSession?.messages ?? const [];

  AiChatSession? get _currentSession {
    final id = _currentSessionId;
    return id == null ? null : _sessionById(id);
  }

  AiChatSession? _sessionById(String id) {
    for (final session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  /// [userId]'s saved chats. Also retires the two pre-per-account keys: on
  /// [mayClaimUnscoped] they're migrated to this account when it has
  /// nothing saved of its own, and either way they're deleted — left in
  /// place, whichever account signed in next without chats would inherit
  /// them.
  Future<List<AiChatSession>> _readSessions(String userId, {required bool mayClaimUnscoped}) async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = _sessionsPrefsKey(userId);
    final unscopedRaw = prefs.getString(_unscopedSessionsPrefsKey);
    final legacyRaw = prefs.getString(_legacyPrefsKey);
    final ownRaw = prefs.getString(userKey);
    var sessions = <AiChatSession>[];

    final raw = ownRaw ?? (mayClaimUnscoped ? unscopedRaw : null);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List;
        sessions = decoded.map((s) => AiChatSession.fromMap(Map<String, dynamic>.from(s as Map))).toList();
        if (ownRaw == null) await prefs.setString(userKey, raw);
      } catch (_) {
        // Corrupt — fall through and try the legacy key below.
      }
    }

    if (sessions.isEmpty && mayClaimUnscoped && legacyRaw != null) {
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
          sessions = [session];
          await prefs.setString(userKey, jsonEncode([session.toMap()]));
        }
      } catch (_) {
        // Corrupt legacy data — nothing worth migrating.
      }
    }

    // Only after the migrated copy above is written, so closing the app
    // mid-migration can't lose it.
    if (unscopedRaw != null) await prefs.remove(_unscopedSessionsPrefsKey);
    if (legacyRaw != null) await prefs.remove(_legacyPrefsKey);
    return sessions;
  }

  Future<void> _persistSessions() async {
    // Snapshotted before the await below, so an account switch mid-write
    // can't save one traveler's chats under the other's key.
    final userId = _userId;
    if (userId == null || _loading) return;
    final bounded = _sessions.length > _maxSessions ? _sessions.sublist(0, _maxSessions) : _sessions;
    final toStore = bounded.map((session) {
      final all = [...session.messages, ...?_replacedReplies[session.id]];
      final messages = all.length > _maxStoredMessages ? all.sublist(all.length - _maxStoredMessages) : all;
      return session.copyWith(messages: messages).toMap();
    }).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionsPrefsKey(userId), jsonEncode(toStore));
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
    _inFlight.remove(id);
    _replacedReplies.remove(id);
    if (_currentSessionId == id) {
      _currentSessionId = _sessions.isNotEmpty ? _sessions.first.id : null;
    }
    notifyListeners();
    await _persistSessions();
  }

  /// Posts [text] to the active chat right away, then asks for a reply.
  /// [loadUserContext] (when set, in place of [userContext]) is awaited
  /// *after* the message is on screen and the chat counts as sending — so
  /// a slow real-data lookup shows the typing indicator and locks the
  /// composer instead of leaving a window where a second message can be
  /// sent and silently dropped, and the reply is pinned to this chat even
  /// if the traveler switches to another one while it loads.
  Future<void> sendMessage(
    String text, {
    String? userContext,
    Future<String?> Function()? loadUserContext,
  }) async {
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
    await _requestReply(sessionId, userContext: userContext, loadUserContext: loadUserContext);
  }

  /// The traveler's most recent message in the active chat — what
  /// [regenerateLastReply] answers again, so the screen can rebuild the
  /// same real-data context for it that [sendMessage] got.
  String? get lastUserMessage {
    final messages = this.messages;
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].isUser) return messages[i].content;
    }
    return null;
  }

  /// True when the active chat has a question to answer again — after an
  /// error, a reply the traveler didn't like, or one they stopped.
  bool get canRegenerate => !isSending && lastUserMessage != null;

  /// Takes every reply after the traveler's last message off screen (an
  /// error bubble, or a real answer they want redone) and asks for a fresh
  /// one. A real answer taken off is kept aside and put back if the redo
  /// fails or is stopped (see [_replacedReplies]); error bubbles are just
  /// dropped. Also covers a chat whose last turn never got a reply at all
  /// — stopped via [stopGenerating], or the app closed mid-request.
  Future<void> regenerateLastReply({
    String? userContext,
    Future<String?> Function()? loadUserContext,
  }) async {
    if (!canRegenerate) return;
    final session = _currentSession!;
    final lastUserIndex = session.messages.lastIndexWhere((m) => m.isUser);
    final replaced = session.messages.sublist(lastUserIndex + 1).where((m) => !m.isError).toList();
    if (replaced.isEmpty) {
      _replacedReplies.remove(session.id);
    } else {
      _replacedReplies[session.id] = replaced;
    }
    errorMessage = null;
    _upsertSession(
      session.copyWith(messages: session.messages.sublist(0, lastUserIndex + 1), updatedAt: DateTime.now()),
    );
    await _requestReply(session.id, userContext: userContext, loadUserContext: loadUserContext);
  }

  /// Stops waiting on the active chat's reply. The Cloud Function call
  /// itself can't be aborted, so its answer is simply discarded when it
  /// lands (same versioning as a superseded request); the traveler's
  /// message stays, ready for [regenerateLastReply], and a reply a stopped
  /// regenerate was replacing comes back.
  void stopGenerating() {
    final id = _currentSessionId;
    if (id == null || _inFlight.remove(id) == null) return;
    _restoreReplacedReplies(id);
    notifyListeners();
    unawaited(_persistSessions());
  }

  /// Puts back whatever [regenerateLastReply] took off [sessionId], in
  /// place — not moved to the front of the chat list like a new reply.
  void _restoreReplacedReplies(String sessionId) {
    final replaced = _replacedReplies.remove(sessionId);
    if (replaced == null) return;
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return;
    _sessions[index] = _sessions[index].copyWith(messages: [..._sessions[index].messages, ...replaced]);
  }

  Future<void> _requestReply(
    String sessionId, {
    String? userContext,
    Future<String?> Function()? loadUserContext,
  }) async {
    final version = ++_requestCounter;
    _inFlight[sessionId] = version;
    notifyListeners();
    unawaited(_persistSessions());
    // False once this request is stopped, superseded, its chat deleted, or
    // the account switched — its answer then belongs nowhere.
    bool stillWanted() => _inFlight[sessionId] == version;

    try {
      var context = userContext;
      if (loadUserContext != null) {
        try {
          context = await loadUserContext();
        } catch (e) {
          // Real-data grounding is a bonus — still answer without it.
          logTechnicalError(e);
        }
        if (!stillWanted()) return;
      }
      final session = _sessionById(sessionId);
      if (session == null) return;
      // Error bubbles ("Something went wrong. Please try again.") are UI
      // feedback, not a real assistant reply — sending them back as context
      // used to make the model treat its own past failure message as if it
      // had actually said that, for every turn until it aged out of the
      // history window.
      final history = session.messages.where((m) => !m.isError).toList();
      final recentHistory = history.length > _maxHistoryMessages
          ? history.sublist(history.length - _maxHistoryMessages)
          : history;

      final reply = await _repository.sendChatMessage(recentHistory, userContext: context);
      if (!stillWanted()) return;
      _replacedReplies.remove(sessionId);
      _appendToSession(
        sessionId,
        AiChatMessage(id: _uuid.v4(), role: AiMessageRole.assistant, content: reply, createdAt: DateTime.now()),
      );
    } catch (e) {
      if (!stillWanted()) return;
      logTechnicalError(e);
      final message = e is AiException ? e.message : 'Something went wrong. Please try again.';
      errorMessage = message;
      // A failed redo puts back the answer it was replacing first, so the
      // error reads as "couldn't regenerate" rather than a lost reply.
      _restoreReplacedReplies(sessionId);
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
      if (stillWanted()) {
        _inFlight.remove(sessionId);
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
