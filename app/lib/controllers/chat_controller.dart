import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../commands/command_executor.dart';
import '../commands/command_parser.dart';
import '../models/chat_message.dart';
import '../providers/entity_lists_provider.dart';
import '../providers/providers.dart';
import '../repositories/chat_repository.dart';
import '../repositories/entity_repositories.dart';
import '../services/ai_service.dart';
import '../storage/app_database.dart';
import '../utils/conversation_context.dart';
import '../utils/snapshot.dart';

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
///   3. Parsing any commands embedded in the AI reply
///   4. Executing commands against the database
///   5. Persisting user + assistant turns (with command summaries)
class ChatController extends StateNotifier<ChatState> {
  ChatController(
    this._ai,
    ChatRepository repo,
  )   : _parser = const CommandParser(),
        _repo = repo,
        super(const ChatState());

  final QuillBotService _ai;
  ChatRepository _repo;
  EntityRepositories? _entities;
  CommandExecutor? _executor;
  EntityListsRefresher? _entityListsRefresher;
  final CommandParser _parser;
  ConversationContext _conversation = ConversationContext.empty;

  void attachRepository(ChatRepository repo) {
    _repo = repo;
  }

  void attachEntities(EntityRepositories entities, CommandExecutor executor,
      EntityListsRefresher refresher) {
    _entities = entities;
    _executor = executor;
    _entityListsRefresher = refresher;
  }

  bool get isReady => _repo is! _NoopRepo && _entities != null;

  Future<void> load() async {
    try {
      final messages = await _repo.loadAll();
      state = state.copyWith(messages: messages, clearError: true);
    } catch (e) {
      state = state.copyWith(error: 'Failed to load history: $e');
    }
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;
    if (!isReady) {
      state = state.copyWith(error: 'Database is still opening. Try again in a second.');
      return;
    }

    state = state.copyWith(isSending: true, clearError: true);

    final userMsg = ChatMessage(
      id: _newId(),
      role: 'user',
      content: trimmed,
      createdAt: DateTime.now(),
    );
    await _persistAndAppend(userMsg);

    final systemContext = await _buildSystemContext();
    final fullPrompt = _buildPrompt(trimmed, systemContext);

    final String rawReply;
    try {
      rawReply = await _ai.chat(trimmed, systemContext: fullPrompt);
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        error:
            'AI request failed: $e\n\nThe QuillBot backend may be blocking '
            'headless requests. Tap Retry.',
      );
      return;
    }

    if (rawReply.trim().isEmpty) {
      state = state.copyWith(
        isSending: false,
        error: 'AI returned an empty response. Try again in a minute.',
      );
      return;
    }

    // Parse + execute any commands the AI embedded.
    final parsed = _parser.parse(rawReply);
    final results = parsed.hasCommands && _executor != null
        ? await _executor!.executeAll(parsed.commands)
        : <CommandResult>[];

    // Refresh the in-memory entity cache so the Lists screen rebuilds.
    if (results.any((r) => r.success) && _entityListsRefresher != null) {
      await _entityListsRefresher!();
    }

    // Update conversation context: the LAST successful command that
    // resolved an entity becomes "it" for the next turn.
    final lastResolved = results
        .where((r) => r.success && r.resolvedId != null)
        .lastOrNull;
    if (lastResolved != null) {
      _conversation = _conversation.referencing(
        id: lastResolved.resolvedId!,
        title: lastResolved.resolvedTitle ?? '',
        kind: lastResolved.resolvedKind ?? 'entity',
      );
    }

    // Compose the assistant message: user-facing text + command summary.
    final composed = _composeAssistantText(parsed, results);

    final assistantMsg = ChatMessage(
      id: _newId(),
      role: 'assistant',
      content: composed,
      contextSnapshot: systemContext,
      createdAt: DateTime.now(),
    );
    await _persistAndAppend(assistantMsg);

    state = state.copyWith(isSending: false, clearError: true);
  }

  Future<void> retryLast() async {
    final userMessages = state.messages.where((m) => m.isUser).toList();
    if (userMessages.isEmpty) return;
    await send(userMessages.last.content);
  }

  void dismissError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> clearHistory() async {
    await _repo.deleteAll();
    state = const ChatState();
  }

  // ─────────────────────────────────────────────────────────────────────
  // System prompt

  Future<String> _buildSystemContext() async {
    final repo = _entities!;
    // Read all entities to build both a structured snapshot AND a
    // pre-computed aggregate view (totals, upcoming, overdue).
    final tasks = await repo.listTasks();
    final habits = await repo.listHabits();
    final expenses = await repo.listExpenses();
    final recurring = await repo.listRecurringExpenses();
    final reminders = await repo.listReminders();
    final bills = await repo.listBills();
    final lists = await repo.listCustomLists();

    final snapshot = DataSnapshot(
      generatedAt: DateTime.now(),
      tasks: tasks,
      habits: habits,
      expenses: expenses,
      recurringExpenses: recurring,
      reminders: reminders,
      bills: bills,
    );

    final entities = await _snapshotEntities(
      tasks: tasks,
      habits: habits,
      expenses: expenses,
      recurring: recurring,
      reminders: reminders,
      bills: bills,
      lists: lists,
    );

    final snap = <String, dynamic>{
      'current_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'day_of_week': _dayName(DateTime.now().weekday),
      'entities': entities,
      'aggregate_view': snapshot.toMarkdown(),
      'conversation': {
        'last_referenced': _conversation.lastReferencedId == null
            ? null
            : {
                'id': _conversation.lastReferencedId,
                'title': _conversation.lastReferencedTitle,
                'kind': _conversation.lastReferencedKind,
              },
      },
    };
    return jsonEncode(snap);
  }

  Future<Map<String, dynamic>> _snapshotEntities({
    required List<dynamic> tasks,
    required List<dynamic> habits,
    required List<dynamic> expenses,
    required List<dynamic> recurring,
    required List<dynamic> reminders,
    required List<dynamic> bills,
    required List<dynamic> lists,
  }) async {
    return {
      'tasks': tasks
          .map((t) => {
                'id': t.id,
                'title': t.title,
                'due_date': t.dueDate?.toIso8601String().substring(0, 10),
                'is_complete': t.isComplete,
              })
          .toList(),
      'habits': habits
          .map((h) => {'id': h.id, 'title': h.title, 'recurrence': h.recurrence})
          .toList(),
      'expenses': expenses
          .map((e) => {
                'id': e.id,
                'label': e.label,
                'amount': e.amount,
                'spent_on':
                    DateFormat('yyyy-MM-dd').format(e.spentOn),
              })
          .toList(),
      'recurring_expenses': recurring
          .map((r) => {
                'id': r.id,
                'label': r.label,
                'amount': r.amount,
                'cadence': r.cadence,
                'next_due':
                    DateFormat('yyyy-MM-dd').format(r.nextDue),
              })
          .toList(),
      'reminders': reminders
          .map((r) => {
                'id': r.id,
                'title': r.title,
                'remind_at': r.remindAt.toIso8601String(),
              })
          .toList(),
      'bills': bills
          .map((b) => {
                'id': b.id,
                'title': b.title,
                'amount': b.amount,
                'due_on':
                    DateFormat('yyyy-MM-dd').format(b.dueOn),
                'is_paid': b.isPaid,
              })
          .toList(),
      'custom_lists': lists
          .map((l) => {'id': l.id, 'title': l.title})
          .toList(),
    };
  }

  String _buildPrompt(String userText, String systemContextJson) {
    return '''
You are a personal AI productivity assistant. You manage the user's tasks, habits, expenses, reminders, bills, and custom lists.

When the user wants to ADD, CHANGE, or REMOVE something, you return a JSON block of commands wrapped in ```json fences, optionally followed by a short friendly confirmation message. When the user just wants to chat or ask a question (no data changes), you reply in plain text only — no commands.

Available actions:
- CREATE_TASK {title, due_date?, due_time?, priority?, category?, notes?}
  UPDATE_TASK {id OR title, title?, due_date?, due_time?, priority?, category?, notes?, is_complete?, clear_due_date?, clear_due_time?}
  DELETE_TASK {id OR title}  MARK_TASK_COMPLETE {id OR title}
- CREATE_HABIT {title, recurrence: "daily"|"weekdays"|"weekends"|"custom"|"every_n_days", custom_days?, interval_days?, category?}
  UPDATE_HABIT {id OR title, title?, recurrence?, is_paused?, category?}
  DELETE_HABIT {id OR title}
- CREATE_EXPENSE {label OR title OR description, amount, spent_on?, category?}
  UPDATE_EXPENSE {id, label?, amount?, spent_on?, category?, notes?, is_planned?}
  DELETE_EXPENSE {id OR title OR label}
- CREATE_RECURRING_EXPENSE {label OR title, amount, cadence: "weekly"|"biweekly"|"monthly"|"quarterly"|"yearly", next_due, category?}
  UPDATE_RECURRING_EXPENSE {id, label?, amount?, cadence?, next_due?, category?}
  DELETE_RECURRING_EXPENSE {id OR title OR label}
- CREATE_REMINDER {title, remind_at, cadence?, priority?, category?}
  UPDATE_REMINDER {id OR title, title?, remind_at?, cadence?, priority?, category?, is_done?, clear_cadence?}
  DELETE_REMINDER {id OR title}
- CREATE_BILL {title, amount, due_on, cadence?, category?}
  UPDATE_BILL {id, title?, amount?, due_on?, cadence?, category?}
  DELETE_BILL {id OR title}
- CREATE_CUSTOM_LIST {title, emoji?}  UPDATE_CUSTOM_LIST {id, title?, emoji?, clear_emoji?}
  DELETE_CUSTOM_LIST {id OR title}
- ADD_CUSTOM_LIST_ITEM {list_id OR list_title, label OR text OR title OR name, position?}
  REMOVE_CUSTOM_LIST_ITEM {id OR (list_id AND label)}

Date fields accept ISO format: "YYYY-MM-DD" or full ISO datetimes.
- For "tomorrow" / "next Friday" / etc., resolve against `current_date` below.
- Times of day: use ISO datetime "YYYY-MM-DDTHH:MM:SS" (24h, local).

ID handling:
- For CREATE actions, omit `id` — the app generates one.
- For UPDATE / DELETE / MARK_COMPLETE, include either the `id` OR `title` of the target. Title matching is case-insensitive substring — prefer exact match when possible.
- If the user refers to something with "it" or "that", resolve using the `conversation.last_referenced` field below.
- For DELETE_EXPENSE / DELETE_RECURRING_EXPENSE, use either `title` or `label`.

Resolving references:
- When user says "delete it" / "mark it done" / "move it to Friday" after a prior command, use `conversation.last_referenced.id` or `.title`.
- When user says "delete the rent bill" / "remove Netflix", use title-based lookup with `title` field.
- For follow-up updates like "make it urgent", use `MARK_TASK_COMPLETE` no — use `UPDATE_TASK` with the priority field.

Query handling (no commands needed):
- "what's on my plate tomorrow?" → read the `aggregate_view` "Upcoming" section.
- "how much did I spend this week?" → read `aggregate_view` "Expenses" → "This week".
- "what bills are due?" → read `aggregate_view` "Upcoming" → filter `[bill]` entries.
- "what's overdue?" → read `aggregate_view` "Overdue" section.
- Just answer from the snapshot; no JSON block needed.

Format your reply as either:
1. Plain text only (when no data changes needed — answers, conversation).
2. A JSON block followed by a short confirmation:
```json
[
  {"action": "CREATE_TASK", "title": "Call mom", "due_date": "2026-08-17"}
]
```
Added "Call mom" for Sunday. Anything else?

Current app state (includes aggregate view + full entity list + conversation context):
$systemContextJson

User: $userText
''';
  }

  String _composeAssistantText(ParseResult parsed, List<CommandResult> results) {
    final parts = <String>[];
    if (parsed.userFacingText.isNotEmpty && parsed.userFacingText != 'Done.') {
      parts.add(parsed.userFacingText);
    }
    if (results.isNotEmpty) {
      final successes = results.where((r) => r.success).toList();
      if (successes.isNotEmpty) {
        parts.add(successes.map((r) => '✓ ${r.summary}').join('\n'));
      }
      final failures = results.where((r) => !r.success).toList();
      if (failures.isNotEmpty) {
        parts.add(failures.map((r) => '✗ ${r.summary}').join('\n'));
      }
    }
    if (parsed.warnings.isNotEmpty) {
      parts.add('⚠ ${parsed.warnings.join('\n⚠ ')}');
    }
    if (parts.isEmpty) return 'Done.';
    return parts.join('\n\n');
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

  Future<void> _persistAndAppend(ChatMessage msg) async {
    await _repo.insert(msg);
    state = state.copyWith(messages: [...state.messages, msg]);
  }
}

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

class _NoopDb implements AppDatabase {
  @override
  Database get raw => throw StateError('Database not ready');

  @override
  Future<void> close() async => throw StateError('Database not ready');
}
