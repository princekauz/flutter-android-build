import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../models/chat_message.dart';
import '../providers/providers.dart';
import '../repositories/chat_repository.dart';
import '../services/ai_service.dart';
import '../storage/app_database.dart';

/// State of the chat screen.
class ChatState {
  final List<ChatMessage> messages;
  final bool isSending;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isSending = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for the chat screen. Orchestrates:
///   1. Loading existing messages from the repository
///   2. Sending a user message → calling the AI service
///   3. Persisting both user + assistant turns
///   4. Surfacing errors clearly to the UI
class ChatController extends StateNotifier<ChatState> {
  ChatController(this._ai, ChatRepository repo)
      : _repo = repo,
        super(const ChatState());

  final QuillBotService _ai;
  ChatRepository _repo;

  /// Replace the repository once the database opens.
  void attachRepository(ChatRepository repo) {
    _repo = repo;
  }

  bool get isReady => _repo is! _NoopRepo;

  /// Load existing messages on screen open.
  Future<void> load() async {
    try {
      final messages = await _repo.loadAll();
      state = state.copyWith(messages: messages, clearError: true);
    } catch (e) {
      state = state.copyWith(error: 'Failed to load history: $e');
    }
  }

  /// Send a user message and store the assistant's reply.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;
    if (_repo is _NoopRepo) {
      state = state.copyWith(error: 'Database is still opening. Try again in a second.');
      return;
    }

    state = state.copyWith(isSending: true, clearError: true);

    // 1. Persist + render the user message
    final userMsg = ChatMessage(
      id: _newId(),
      role: 'user',
      content: trimmed,
      createdAt: DateTime.now(),
    );
    await _persistAndAppend(userMsg);

    // 2. Build the system context. Phase 1 = just the current date.
    final systemContext = _buildSystemContext();

    // 3. Call the AI service.
    final String replyText;
    try {
      replyText = await _ai.chat(trimmed, systemContext: systemContext);
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        error:
            'AI request failed: $e\n\nThe QuillBot backend may be blocking '
            'headless requests or may be temporarily down. Tap Retry to try '
            'again, or check the info icon for backend details.',
      );
      return;
    }

    if (replyText.trim().isEmpty) {
      state = state.copyWith(
        isSending: false,
        error: 'AI returned an empty response. Try again in a minute.',
      );
      return;
    }

    // 4. Persist + render the assistant message
    final assistantMsg = ChatMessage(
      id: _newId(),
      role: 'assistant',
      content: replyText.trim(),
      contextSnapshot: systemContext,
      createdAt: DateTime.now(),
    );
    await _persistAndAppend(assistantMsg);

    state = state.copyWith(isSending: false, clearError: true);
  }

  /// Retry the last user message after an error.
  Future<void> retryLast() async {
    final userMessages = state.messages.where((m) => m.isUser).toList();
    if (userMessages.isEmpty) return;
    await send(userMessages.last.content);
  }

  /// Clear the current error banner without retrying.
  void dismissError() {
    state = state.copyWith(clearError: true);
  }

  /// Clear all messages (debug helper for Phase 1).
  Future<void> clearHistory() async {
    await _repo.deleteAll();
    state = const ChatState();
  }

  // ─────────────────────────────────────────────────────────────────────
  // Internals

  Future<void> _persistAndAppend(ChatMessage msg) async {
    await _repo.insert(msg);
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  String _buildSystemContext() {
    final now = DateTime.now();
    return jsonEncode({
      'current_date': DateFormat('yyyy-MM-dd').format(now),
      'day_of_week': _dayName(now.weekday),
      'phase': '1 — read-only chat. The assistant answers questions but does '
          'not yet create/update/delete tasks, habits, or expenses.',
    });
  }

  String _dayName(int weekday) => const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ][weekday - 1];

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
}

/// Provider for the chat controller. Always available; the controller
/// starts with a no-op repository and the chat screen attaches the real one
/// once the database opens.
final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  final ai = ref.watch(aiServiceProvider);
  return ChatController(ai, _NoopRepo());
});

/// Repository stand-in used while the real one is still loading.
class _NoopRepo extends ChatRepository {
  _NoopRepo() : super(_NoopDb());

  @override
  Future<List<ChatMessage>> loadAll() async =>
      throw StateError('Database not ready');

  @override
  Future<void> insert(ChatMessage msg) async =>
      throw StateError('Database not ready');

  @override
  Future<void> deleteAll() async =>
      throw StateError('Database not ready');
}

/// Sentinel database. We never call methods on it (the repository overrides
/// them), so a real SQLiteAppDatabase instance is not needed.
class _NoopDb implements AppDatabase {
  @override
  Database get raw => throw StateError('Database not ready');

  @override
  Future<void> close() async => throw StateError('Database not ready');
}
