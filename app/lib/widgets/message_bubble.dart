import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/chat_message.dart';

/// Renders a single chat message as a bubble aligned to the side of the
/// speaker (user → right, assistant → left).
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final scheme = theme.colorScheme;

    final bg = isUser ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = isUser ? scheme.onPrimary : scheme.onSurface;

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
      ),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      child: SelectableText(
        message.content,
        style: theme.textTheme.bodyMedium?.copyWith(color: fg, height: 1.4),
      ),
    );

    final timestamp = Padding(
      padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
      child: Text(
        DateFormat('HH:mm').format(message.createdAt),
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [bubble, timestamp],
      ),
    );
  }
}
