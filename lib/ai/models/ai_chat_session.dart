import 'ai_message.dart';

/// One saved AI Travel Assistant conversation — travelers can keep several
/// of these ("New Chat") and switch between them, the same way [messages]
/// alone used to be the app's single, only conversation.
class AiChatSession {
  AiChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.updatedAt,
  });

  final String id;

  /// Derived from the first user message once it's sent (see
  /// `AiChatProvider._deriveTitle`) — stays "New Chat" until then.
  final String title;
  final List<AiChatMessage> messages;

  /// Last time this chat changed — [AiChatProvider] keeps [messages]
  /// sorted by this, most recent first, so it reads like a normal chat list.
  final DateTime updatedAt;

  factory AiChatSession.fromMap(Map<String, dynamic> map) {
    return AiChatSession(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'New Chat',
      messages: (map['messages'] as List? ?? const [])
          .map((m) => AiChatMessage.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((m) => m.toMap()).toList(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  AiChatSession copyWith({String? title, List<AiChatMessage>? messages, DateTime? updatedAt}) {
    return AiChatSession(
      id: id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
