import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/ai_service.dart';

/// Phase 0 chat screen — mounts the hidden QuillBot WebView so the AI
/// service is initialized and ready, and shows a placeholder conversation
/// UI. Real message-sending arrives in Phase 1.
///
/// The WebView is intentionally kept off-screen but **mounted** because
/// `QuillBotService.webView` returns a `WebViewWidget` that must live in
/// the widget tree to function.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final QuillBotService _ai;

  @override
  void initState() {
    super.initState();
    _ai = ref.read(aiServiceProvider);
    // Kick off WebView initialization as soon as the screen is built.
    _ai.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            tooltip: 'About the AI backend',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showBackendInfo(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Hidden WebView — mounted but stacked off-screen with zero size.
          // It needs to exist in the tree so its JavaScript channel works.
          Positioned(
            left: -10000,
            top: -10000,
            width: 1,
            height: 1,
            child: _ai.webView,
          ),
          // Visible placeholder UI for Phase 0
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt_outlined,
                      size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'AI Assistant — Phase 0',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The assistant is warming up.\n'
                    'Conversational chat ships in Phase 1.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBackendInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('AI backend',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Uses QuillBot\'s web API through a hidden WebView. '
              'This is a reverse-engineered third-party endpoint — it can '
              'break without notice if QuillBot changes their site.',
            ),
            const SizedBox(height: 16),
            Text('Phase 0 status',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              '• WebView mounted (hidden, off-screen)\n'
              '• AI service initialized on screen open\n'
              '• No chat send/receive yet — Phase 1',
            ),
          ],
        ),
      ),
    );
  }
}
