import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/chat_controller.dart';
import '../providers/providers.dart';
import '../services/ai_service.dart';
import '../widgets/message_bubble.dart';

/// Phase 1 chat screen.
///
/// - Mounts the hidden QuillBot WebView so the AI service is initialized.
/// - Shows a scrollable list of past messages + the current conversation.
/// - Input box at the bottom, send button, loading spinner while waiting.
/// - Error banner with Retry when the AI call fails.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  QuillBotService? _ai;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _aiInitStarted = false;
  bool _dbWaitStarted = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _ensureAiInitialized() {
    if (_aiInitStarted) return;
    _aiInitStarted = true;
    _ai = ref.read(aiServiceProvider);
    _ai!.initialize();
  }

  /// Called once the database provider resolves — attach the real repo
  /// to the controller and load history.
  void _attachRepoIfReady(ChatController controller, bool isReady) {
    if (!isReady || _dbWaitStarted) return;
    _dbWaitStarted = true;
    Future.microtask(() async {
      final repo = await ref.read(chatRepositoryProvider.future);
      controller.attachRepository(repo);
      await controller.load();
      if (mounted) _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the DB provider so we know when the controller can switch over.
    final dbReady = ref.watch(chatRepositoryProvider).hasValue;
    final controller = ref.watch(chatControllerProvider.notifier);
    final state = ref.watch(chatControllerProvider);

    _ensureAiInitialized();
    _attachRepoIfReady(controller, dbReady);

    // Scroll on new messages
    ref.listen(chatControllerProvider, (_, __) {
      _scrollToBottom();
    });

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            tooltip: 'Clear conversation',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmClear(context, controller),
          ),
          IconButton(
            tooltip: 'About the AI backend',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showBackendInfo(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                if (!dbReady)
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: scheme.secondaryContainer,
                    child: Text(
                      'Opening local database…',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                Expanded(child: _buildMessageList(state)),
                if (state.error != null)
                  _buildErrorBanner(theme, state, controller),
                _buildInputRow(theme, scheme, controller, state),
              ],
            ),
            // Hidden WebView — mounted but off-screen so the JS channel works.
            if (_ai != null)
              Positioned(
                left: -10000,
                top: -10000,
                width: 1,
                height: 1,
                child: _ai!.webView,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ChatState state) {
    if (state.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                'Start the conversation',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Ask about today, tomorrow, or anything else.\n'
                'The assistant answers — it does not yet create or modify '
                'tasks (that arrives in Phase 2).',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: state.messages.length,
      itemBuilder: (ctx, i) => MessageBubble(message: state.messages[i]),
    );
  }

  Widget _buildErrorBanner(
      ThemeData theme, ChatState state, ChatController controller) {
    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline,
              color: theme.colorScheme.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () => controller.retryLast(),
            child: const Text('Retry'),
          ),
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close, size: 18),
            color: theme.colorScheme.onErrorContainer,
            onPressed: () => controller.dismissError(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(ThemeData theme, ColorScheme scheme,
      ChatController controller, ChatState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                enabled: !state.isSending && controller.isReady,
                decoration: const InputDecoration(
                  hintText: 'Type a message…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _send(controller),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: state.isSending
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : FilledButton(
                      onPressed:
                          controller.isReady ? () => _send(controller) : null,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                      ),
                      child: const Icon(Icons.send, size: 20),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _send(ChatController controller) {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    _inputController.clear();
    controller.send(text);
  }

  void _confirmClear(BuildContext context, ChatController controller) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text('This permanently deletes all chat history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () {
              controller.clearHistory();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
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
            Text('AI backend', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Uses QuillBot\'s web API through a hidden WebView. '
              'Reverse-engineered third-party endpoint — can break without '
              'notice if QuillBot changes their site.',
            ),
            const SizedBox(height: 16),
            Text('Phase 1 status', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              '• WebView mounted (hidden, off-screen)\n'
              '• Chat send/receive works\n'
              '• Conversation persists across app restarts\n'
              '• AI receives current date\n'
              '• AI is read-only — cannot create tasks/habits/etc. yet',
            ),
            const SizedBox(height: 16),
            Text('Troubleshooting', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'If the AI doesn\'t reply, QuillBot may be blocking the '
              'headless WebView. Wait a minute and try again. Errors appear '
              'as a banner above the input with a Retry button.',
            ),
          ],
        ),
      ),
    );
  }
}

