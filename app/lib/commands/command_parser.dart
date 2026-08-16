import 'dart:convert';

import 'command.dart';

/// Result of parsing an AI reply.
class ParseResult {
  final String userFacingText; // the reply minus any JSON blocks
  final List<Command> commands;
  final List<String> warnings; // non-fatal issues (e.g. unknown action)

  const ParseResult({
    required this.userFacingText,
    required this.commands,
    this.warnings = const [],
  });

  bool get hasCommands => commands.isNotEmpty;
}

/// Parses an AI reply into user-facing text and a list of Commands.
///
/// The AI is instructed to embed commands as a JSON array inside a
/// fenced ```json block, optionally followed by plain text. This parser:
///   1. Strips all ```json ... ``` blocks from the reply
///   2. Parses each block as a JSON array of command objects
///   3. Maps each object to a typed Command via [parseCommand]
///   4. Returns the remaining text + the typed commands + any warnings
class CommandParser {
  const CommandParser();

  ParseResult parse(String aiReply) {
    if (aiReply.trim().isEmpty) {
      return const ParseResult(userFacingText: '', commands: []);
    }

    final jsonBlocks = _extractJsonBlocks(aiReply);
    final allCommands = <Command>[];
    final warnings = <String>[];

    for (final block in jsonBlocks) {
      try {
        final dynamic decoded = jsonDecode(block);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final cmd = parseCommand(item);
              if (cmd != null) {
                allCommands.add(cmd);
              } else {
                warnings.add('Unknown action: ${item['action']}');
              }
            } else {
              warnings.add('Skipped non-object command entry: $item');
            }
          }
        } else if (decoded is Map<String, dynamic>) {
          // Single command, not in an array — be permissive.
          final cmd = parseCommand(decoded);
          if (cmd != null) {
            allCommands.add(cmd);
          } else {
            warnings.add('Unknown action: ${decoded['action']}');
          }
        }
      } catch (e) {
        warnings.add('Failed to parse JSON block: $e');
      }
    }

    final cleanText = _stripJsonBlocks(aiReply).trim();
    return ParseResult(
      userFacingText: cleanText.isEmpty ? 'Done.' : cleanText,
      commands: allCommands,
      warnings: warnings,
    );
  }

  /// Public for testing. Maps a single JSON object to a typed Command.
  /// Returns null for unknown actions.
  Command? parseCommand(Map<String, dynamic> json) {
    final action = json['action'] as String?;
    if (action == null) return null;
    final id = (json['id'] as String?) ?? _genId();

    try {
      switch (action) {
        // Tasks
        case 'CREATE_TASK':
          return CreateTask(
            id: id,
            title: (json['title'] as String?) ?? '(untitled)',
            notes: json['notes'] as String?,
            dueDate: _parseDate(json['due_date']),
            dueTime: _parseDate(json['due_time']),
            priority: (json['priority'] as int?) ?? 0,
            category: json['category'] as String?,
            recurrence: json['recurrence'] as String?,
          );
        case 'UPDATE_TASK':
          return UpdateTask(
            id: id,
            title: json['title'] as String?,
            notes: json['notes'] as String?,
            dueDate: _parseDate(json['due_date']),
            dueTime: _parseDate(json['due_time']),
            isComplete: json['is_complete'] as bool?,
            priority: json['priority'] as int?,
            category: json['category'] as String?,
            recurrence: json['recurrence'] as String?,
            clearDueDate: json['due_date'] == null && json.containsKey('due_date'),
            clearDueTime: json['due_time'] == null && json.containsKey('due_time'),
            clearRecurrence:
                json['recurrence'] == null && json.containsKey('recurrence'),
          );
        case 'DELETE_TASK':
          return DeleteTask(
            id: (json['id'] as String?),
            title: json['title'] as String?,
          );
        case 'MARK_TASK_COMPLETE':
          return MarkTaskComplete(
            id: (json['id'] as String?),
            title: json['title'] as String?,
          );

        // Habits
        case 'CREATE_HABIT':
          return CreateHabit(
            id: id,
            title: (json['title'] as String?) ?? '(untitled)',
            recurrence: (json['recurrence'] as Map<String, dynamic>?) ??
                const {'type': 'daily'},
          );
        case 'UPDATE_HABIT':
          return UpdateHabit(
            id: id,
            title: json['title'] as String?,
            recurrence: json['recurrence'] as Map<String, dynamic>?,
            isPaused: json['is_paused'] as bool?,
          );
        case 'DELETE_HABIT':
          return DeleteHabit(
            id: (json['id'] as String?),
            title: json['title'] as String?,
          );

        // Expenses
        case 'CREATE_EXPENSE':
          return CreateExpense(
            id: id,
            label: (json['label'] as String?) ?? '(untitled)',
            amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
            spentOn: _parseDate(json['spent_on']) ?? DateTime.now(),
            category: json['category'] as String?,
            notes: json['notes'] as String?,
            isPlanned: (json['is_planned'] as bool?) ?? true,
          );
        case 'UPDATE_EXPENSE':
          return UpdateExpense(
            id: id,
            label: json['label'] as String?,
            amount: (json['amount'] as num?)?.toDouble(),
            spentOn: _parseDate(json['spent_on']),
            category: json['category'] as String?,
            notes: json['notes'] as String?,
            isPlanned: json['is_planned'] as bool?,
          );
        case 'DELETE_EXPENSE':
          return DeleteExpense(
            id: (json['id'] as String?),
            title: json['title'] as String?,
            label: json['label'] as String?,
          );

        // Recurring expenses
        case 'CREATE_RECURRING_EXPENSE':
          return CreateRecurringExpense(
            id: id,
            label: (json['label'] as String?) ?? '(untitled)',
            amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
            cadence: (json['cadence'] as String?) ?? 'monthly',
            nextDue: _parseDate(json['next_due']) ?? DateTime.now(),
            category: json['category'] as String?,
          );
        case 'UPDATE_RECURRING_EXPENSE':
          return UpdateRecurringExpense(
            id: id,
            label: json['label'] as String?,
            amount: (json['amount'] as num?)?.toDouble(),
            cadence: json['cadence'] as String?,
            nextDue: _parseDate(json['next_due']),
            category: json['category'] as String?,
          );
        case 'DELETE_RECURRING_EXPENSE':
          return DeleteRecurringExpense(
            id: (json['id'] as String?),
            label: json['label'] as String?,
            title: json['title'] as String?,
          );

        // Reminders
        case 'CREATE_REMINDER':
          return CreateReminder(
            id: id,
            title: (json['title'] as String?) ?? '(untitled)',
            remindAt: _parseDate(json['remind_at']) ?? DateTime.now(),
            cadence: json['cadence'] as String?,
            priority: (json['priority'] as int?) ?? 0,
            category: json['category'] as String?,
          );
        case 'UPDATE_REMINDER':
          return UpdateReminder(
            id: id,
            title: json['title'] as String?,
            remindAt: _parseDate(json['remind_at']),
            cadence: json['cadence'] as String?,
            priority: json['priority'] as int?,
            category: json['category'] as String?,
            isDone: json['is_done'] as bool?,
            clearCadence:
                json['cadence'] == null && json.containsKey('cadence'),
          );
        case 'DELETE_REMINDER':
          return DeleteReminder(
            id: (json['id'] as String?),
            title: json['title'] as String?,
          );

        // Bills
        case 'CREATE_BILL':
          return CreateBill(
            id: id,
            title: (json['title'] as String?) ?? '(untitled)',
            amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
            dueOn: _parseDate(json['due_on']) ?? DateTime.now(),
            cadence: json['cadence'] as String?,
            category: json['category'] as String?,
          );
        case 'UPDATE_BILL':
          return UpdateBill(
            id: id,
            title: json['title'] as String?,
            amount: (json['amount'] as num?)?.toDouble(),
            dueOn: _parseDate(json['due_on']),
            cadence: json['cadence'] as String?,
            category: json['category'] as String?,
          );
        case 'DELETE_BILL':
          return DeleteBill(
            id: (json['id'] as String?),
            title: json['title'] as String?,
          );

        // Custom lists
        case 'CREATE_CUSTOM_LIST':
          return CreateCustomList(
            id: id,
            title: (json['title'] as String?) ?? '(untitled)',
            emoji: json['emoji'] as String?,
          );
        case 'UPDATE_CUSTOM_LIST':
          return UpdateCustomList(
            id: id,
            title: json['title'] as String?,
            emoji: json['emoji'] as String?,
            clearEmoji: json['emoji'] == null && json.containsKey('emoji'),
          );
        case 'DELETE_CUSTOM_LIST':
          return DeleteCustomList(
            id: (json['id'] as String?),
            title: json['title'] as String?,
          );
        case 'ADD_CUSTOM_LIST_ITEM':
          return AddCustomListItem(
            id: id,
            listId: (json['list_id'] as String?) ?? '',
            label: (json['label'] as String?) ?? '(item)',
            position: (json['position'] as int?) ?? 0,
          );
        case 'REMOVE_CUSTOM_LIST_ITEM':
          return RemoveCustomListItem(
            id: (json['id'] as String?),
            label: json['label'] as String?,
            listTitle: json['list_title'] as String?,
          );
      }
    } catch (e) {
      // Field type mismatch etc.
      return null;
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────
  // Internals

  /// Find all ```json ... ``` blocks in the reply.
  List<String> _extractJsonBlocks(String reply) {
    final blocks = <String>[];
    final regex = RegExp(
      r'```json\s*([\s\S]*?)\s*```',
      multiLine: true,
    );
    for (final m in regex.allMatches(reply)) {
      final content = m.group(1);
      if (content != null) blocks.add(content);
    }
    // Also accept un-fenced JSON if it's the only content — some AIs
    // forget the fences. Detect an array or object starting at line start.
    if (blocks.isEmpty) {
      final trimmed = reply.trim();
      if ((trimmed.startsWith('[') && trimmed.endsWith(']')) ||
          (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
        blocks.add(trimmed);
      }
    }
    return blocks;
  }

  /// Remove all ```json ... ``` blocks (and any surrounding blank lines).
  String _stripJsonBlocks(String reply) {
    return reply
        .replaceAll(RegExp(r'```json\s*[\s\S]*?\s*```', multiLine: true), '')
        .replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), '')
        .trim();
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) {
      // Accept ISO dates ("2026-08-17") and ISO datetimes ("2026-08-17T15:00:00")
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _genId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
}
