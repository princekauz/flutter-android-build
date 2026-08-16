/// Tracks the most recently referenced entity in a chat conversation.
///
/// When the user says "delete it" or "mark it done", the AI looks at this
/// context to figure out what "it" is.
///
/// The AI itself signals which entity it referenced in its reply, via a
/// JSON block:
/// ```
/// ```json
/// [{"action": "CREATE_TASK", "title": "call mom"}]
/// ```
/// ```
///
/// For updates/deletes it references an existing entity by id (or title
/// resolved at the executor). The chat controller updates the
/// [ConversationContext] with the latest referenced entity id+title
/// after each assistant message.
class ConversationContext {
  final String? lastReferencedId;
  final String? lastReferencedTitle;
  final String? lastReferencedKind; // 'task' | 'reminder' | etc.

  const ConversationContext({
    this.lastReferencedId,
    this.lastReferencedTitle,
    this.lastReferencedKind,
  });

  static const empty = ConversationContext();

  bool get hasReference => lastReferencedId != null;

  ConversationContext referencing({
    required String id,
    required String title,
    required String kind,
  }) =>
      ConversationContext(
        lastReferencedId: id,
        lastReferencedTitle: title,
        lastReferencedKind: kind,
      );

  String toMarkdown() {
    if (!hasReference) return '';
    return 'Last referenced entity: $lastReferencedKind "$lastReferencedTitle" (id=$lastReferencedId)';
  }
}
