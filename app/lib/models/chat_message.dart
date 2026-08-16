/// A single message in the chat conversation.
///
/// Pure Dart class — no Drift/sqflite types. Used across the UI, the
/// repository, and (in future phases) the AI command parser.
class ChatMessage {
  /// Stable UUID. Survives app restarts.
  final String id;

  /// Who said this. One of: 'user' | 'assistant' | 'system'.
  final String role;

  /// Plain text content.
  final String content;

  /// JSON blob of structured context the AI was given for this turn.
  /// Phase 1: null for user turns, contains `{ "current_date": ... }` for
  /// assistant turns. Phase 2+: full structured app context.
  final String? contextSnapshot;

  /// When this message was created.
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.contextSnapshot,
    required this.createdAt,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    String? contextSnapshot,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      contextSnapshot: contextSnapshot ?? this.contextSnapshot,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'role': role,
        'content': content,
        'context_snapshot': contextSnapshot,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory ChatMessage.fromRow(Map<String, Object?> row) {
    return ChatMessage(
      id: row['id'] as String,
      role: row['role'] as String,
      content: row['content'] as String,
      contextSnapshot: row['context_snapshot'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    );
  }
}
