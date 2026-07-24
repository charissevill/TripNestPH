/// Who authored a chat turn. [system] messages are never rendered — they
/// only steer the model — but are kept in the enum so persisted history
/// round-trips cleanly.
enum AiMessageRole { user, assistant, system }

/// A single turn in the AI Travel Assistant conversation.
class AiChatMessage {
  AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isError = false,
  });

  final String id;
  final AiMessageRole role;
  final String content;
  final DateTime createdAt;

  /// True when this assistant message is actually a friendly error string
  /// (rate limit, no internet, etc.) rather than a real answer — lets the
  /// bubble widget style it differently without a separate message type.
  final bool isError;

  bool get isUser => role == AiMessageRole.user;

  /// The role name OpenAI's chat completions API expects.
  String get apiRole => switch (role) {
        AiMessageRole.user => 'user',
        AiMessageRole.assistant => 'assistant',
        AiMessageRole.system => 'system',
      };

  factory AiChatMessage.fromMap(Map<String, dynamic> map) {
    return AiChatMessage(
      id: map['id'] as String? ?? '',
      role: AiMessageRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => AiMessageRole.user,
      ),
      content: map['content'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      isError: map['isError'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role.name,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'isError': isError,
    };
  }
}
