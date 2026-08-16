import 'package:intl/intl.dart';

import '../models/bill.dart';
import '../models/custom_list.dart';
import '../models/expense.dart';
import '../models/habit.dart';
import '../models/recurring_expense.dart';
import '../models/reminder.dart';
import '../models/task.dart';
import '../repositories/entity_repositories.dart';
import 'command.dart';

/// Result of executing a single command.
class CommandResult {
  final bool success;
  final String summary;
  final Command command;
  final String? error;
  /// Set when a delete/update resolved an entity by title (or the
  /// conversation context). Lets the chat controller update its
  /// "last referenced entity" memory for follow-up turns like "delete it".
  final String? resolvedId;
  final String? resolvedTitle;
  final String? resolvedKind;

  const CommandResult({
    required this.success,
    required this.summary,
    required this.command,
    this.error,
    this.resolvedId,
    this.resolvedTitle,
    this.resolvedKind,
  });
}

/// Runs parsed Commands against the database.
///
/// Each command type maps to a repository call. UPDATE commands fetch
/// the existing entity first, apply the partial updates, and save back.
/// DELETE commands accept either an `id` OR a `title` — when title is
/// given, the executor fuzzy-matches against the current entity list.
/// The summary is short and human-readable — the chat controller prepends
/// it to the assistant message.
class CommandExecutor {
  CommandExecutor(this._repo);

  final EntityRepositories _repo;

  Future<List<CommandResult>> executeAll(List<Command> commands) async {
    final results = <CommandResult>[];
    for (final cmd in commands) {
      try {
        results.add(await _execute(cmd));
      } catch (e) {
        results.add(CommandResult(
          success: false,
          summary: 'Failed to ${cmd.actionName}: $e',
          command: cmd,
          error: e.toString(),
        ));
      }
    }
    return results;
  }

  Future<CommandResult> _execute(Command cmd) async {
    final now = DateTime.now();

    // ── Tasks ────────────────────────────────────────────────────────────
    if (cmd is CreateTask) {
      final task = cmd.toTask(now: now);
      await _repo.upsertTask(task);
      return CommandResult(
        success: true,
        summary: 'Created task "${task.title}".',
        command: cmd,
        resolvedId: task.id,
        resolvedTitle: task.title,
        resolvedKind: 'task',
      );
    }
    if (cmd is UpdateTask) {
      final resolved = await _resolveTask(cmd.id, cmd.title);
      if (resolved == null) {
        return CommandResult(
          success: false,
          summary: 'Task not found.',
          command: cmd,
        );
      }
      final updated = resolved.copyWith(
        title: cmd.title,
        notes: cmd.notes,
        dueDate: cmd.dueDate,
        dueTime: cmd.dueTime,
        isComplete: cmd.isComplete,
        priority: cmd.priority,
        category: cmd.category,
        recurrence: cmd.recurrence,
        clearDueDate: cmd.clearDueDate,
        clearDueTime: cmd.clearDueTime,
        clearRecurrence: cmd.clearRecurrence,
        updatedAt: now,
      );
      await _repo.upsertTask(updated);
      return CommandResult(
        success: true,
        summary: 'Updated task "${updated.title}".',
        command: cmd,
        resolvedId: updated.id,
        resolvedTitle: updated.title,
        resolvedKind: 'task',
      );
    }
    if (cmd is DeleteTask) {
      final resolved = await _resolveTask(cmd.id, cmd.title);
      if (resolved == null) {
        return CommandResult(
          success: false,
          summary: cmd.title == null
              ? 'Task not found.'
              : 'No task matching "${cmd.title}".',
          command: cmd,
        );
      }
      await _repo.deleteTask(resolved.id);
      return CommandResult(
        success: true,
        summary: 'Deleted task "${resolved.title}".',
        command: cmd,
        resolvedId: resolved.id,
        resolvedTitle: resolved.title,
        resolvedKind: 'task',
      );
    }
    if (cmd is MarkTaskComplete) {
      final resolved = await _resolveTask(cmd.id, cmd.title);
      if (resolved == null) {
        return CommandResult(
          success: false,
          summary: 'Task not found.',
          command: cmd,
        );
      }
      final updated = resolved.copyWith(isComplete: true, updatedAt: now);
      await _repo.upsertTask(updated);
      return CommandResult(
        success: true,
        summary: 'Marked "${updated.title}" done.',
        command: cmd,
        resolvedId: updated.id,
        resolvedTitle: updated.title,
        resolvedKind: 'task',
      );
    }

    // ── Habits ───────────────────────────────────────────────────────────
    if (cmd is CreateHabit) {
      final habit = cmd.toHabit(now: now);
      await _repo.upsertHabit(habit);
      return CommandResult(
        success: true,
        summary: 'Created habit "${habit.title}".',
        command: cmd,
        resolvedId: habit.id,
        resolvedTitle: habit.title,
        resolvedKind: 'habit',
      );
    }
    if (cmd is UpdateHabit) {
      final resolved = await _resolveHabit(cmd.id, cmd.title);
      if (resolved == null) {
        return CommandResult(
          success: false,
          summary: 'Habit not found.',
          command: cmd,
        );
      }
      final updated = resolved.copyWith(
        title: cmd.title,
        recurrence: cmd.recurrence,
        isPaused: cmd.isPaused,
        updatedAt: now,
      );
      await _repo.upsertHabit(updated);
      return CommandResult(
        success: true,
        summary: 'Updated habit "${updated.title}".',
        command: cmd,
        resolvedId: updated.id,
        resolvedTitle: updated.title,
        resolvedKind: 'habit',
      );
    }
    if (cmd is DeleteHabit) {
      final resolved = await _resolveHabit(cmd.id, cmd.title);
      if (resolved == null) {
        return CommandResult(
          success: false,
          summary: 'Habit not found.',
          command: cmd,
        );
      }
      await _repo.deleteHabit(resolved.id);
      return CommandResult(
        success: true,
        summary: 'Deleted habit "${resolved.title}".',
        command: cmd,
        resolvedId: resolved.id,
        resolvedTitle: resolved.title,
        resolvedKind: 'habit',
      );
    }

    // ── Expenses ─────────────────────────────────────────────────────────
    if (cmd is CreateExpense) {
      final expense = cmd.toExpense(now: now);
      await _repo.upsertExpense(expense);
      return CommandResult(
        success: true,
        summary: 'Added expense "${expense.label}" '
            '(\$${expense.amount.toStringAsFixed(2)}) '
            'on ${DateFormat('MMM d').format(expense.spentOn)}.',
        command: cmd,
        resolvedId: expense.id,
        resolvedTitle: expense.label,
        resolvedKind: 'expense',
      );
    }
    if (cmd is UpdateExpense) {
      final existing = await _repo.getExpense(cmd.id);
      if (existing == null) {
        return CommandResult(
          success: false,
          summary: 'Expense not found.',
          command: cmd,
        );
      }
      final updated = existing.copyWith(
        label: cmd.label,
        amount: cmd.amount,
        spentOn: cmd.spentOn,
        category: cmd.category,
        notes: cmd.notes,
        isPlanned: cmd.isPlanned,
        updatedAt: now,
      );
      await _repo.upsertExpense(updated);
      return CommandResult(
        success: true,
        summary: 'Updated expense "${updated.label}".',
        command: cmd,
        resolvedId: updated.id,
        resolvedTitle: updated.label,
        resolvedKind: 'expense',
      );
    }
    if (cmd is DeleteExpense) {
      final resolved = await _resolveExpense(cmd.id, cmd.title ?? cmd.label);
      if (resolved == null) {
        return CommandResult(
          success: false,
          summary: 'Expense not found.',
          command: cmd,
        );
      }
      await _repo.deleteExpense(resolved.id);
      return CommandResult(
        success: true,
        summary: 'Deleted expense "${resolved.label}".',
        command: cmd,
        resolvedId: resolved.id,
        resolvedTitle: resolved.label,
        resolvedKind: 'expense',
      );
    }

    // ── Recurring expenses ───────────────────────────────────────────────
    if (cmd is CreateRecurringExpense) {
      final r = cmd.toRecurringExpense(now: now);
      await _repo.upsertRecurring(r);
      return CommandResult(
        success: true,
        summary: 'Added recurring expense "${r.label}" '
            '(\$${r.amount.toStringAsFixed(2)}, ${r.cadence}).',
        command: cmd,
        resolvedId: r.id,
        resolvedTitle: r.label,
        resolvedKind: 'recurring_expense',
      );
    }
    if (cmd is UpdateRecurringExpense) {
      final existing = await _repo.getRecurring(cmd.id);
      if (existing == null) {
        return CommandResult(
          success: false,
          summary: 'Recurring expense not found.',
          command: cmd,
        );
      }
      final updated = existing.copyWith(
        label: cmd.label,
        amount: cmd.amount,
        cadence: cmd.cadence,
        nextDue: cmd.nextDue,
        category: cmd.category,
        updatedAt: now,
      );
      await _repo.upsertRecurring(updated);
      return CommandResult(
        success: true,
        summary: 'Updated recurring expense "${updated.label}".',
        command: cmd,
        resolvedId: updated.id,
        resolvedTitle: updated.label,
        resolvedKind: 'recurring_expense',
      );
    }
    if (cmd is DeleteRecurringExpense) {
      final resolved =
          await _resolveRecurring(cmd.id, cmd.title ?? cmd.label);
      if (resolved == null) {
        return CommandResult(
          success: false,
          summary: 'Recurring expense not found.',
          command: cmd,
        );
      }
      await _repo.deleteRecurring(resolved.id);
      return CommandResult(
        success: true,
        summary: 'Deleted recurring expense "${resolved.label}".',
        command: cmd,
        resolvedId: resolved.id,
        resolvedTitle: resolved.label,
        resolvedKind: 'recurring_expense',
      );
    }

    // ── Reminders ────────────────────────────────────────────────────────
    if (cmd is CreateReminder) {
      final r = cmd.toReminder(now: now);
      await _repo.upsertReminder(r);
      return CommandResult(
        success: true,
        summary: 'Reminder "${r.title}" set for '
            '${DateFormat('MMM d, HH:mm').format(r.remindAt)}.',
        command: cmd,
        resolvedId: r.id,
        resolvedTitle: r.title,
        resolvedKind: 'reminder',
      );
    }
    if (cmd is UpdateReminder) {
      final existing = await _repo.getReminder(cmd.id);
      if (existing == null) {
        return CommandResult(
          success: false,
          summary: 'Reminder not found.',
          command: cmd,
        );
      }
      final updated = existing.copyWith(
        title: cmd.title,
        remindAt: cmd.remindAt,
        cadence: cmd.cadence,
        priority: cmd.priority,
        category: cmd.category,
        isDone: cmd.isDone,
        clearCadence: cmd.clearCadence,
        updatedAt: now,
      );
      await _repo.upsertReminder(updated);
      return CommandResult(
        success: true,
        summary: 'Updated reminder "${updated.title}".',
        command: cmd,
        resolvedId: updated.id,
        resolvedTitle: updated.title,
        resolvedKind: 'reminder',
      );
    }
    if (cmd is DeleteReminder) {
      final resolved = await _resolveReminder(cmd.id, cmd.title);
      if (resolved == null) {
        return CommandResult(
          success: false,
          summary: 'Reminder not found.',
          command: cmd,
        );
      }
      await _repo.deleteReminder(resolved.id);
      return CommandResult(
        success: true,
        summary: 'Deleted reminder "${resolved.title}".',
        command: cmd,
        resolvedId: resolved.id,
        resolvedTitle: resolved.title,
        resolvedKind: 'reminder',
      );
    }

    // ── Bills ────────────────────────────────────────────────────────────
    if (cmd is CreateBill) {
      final bill = cmd.toBill(now: now);
      await _repo.upsertBill(bill);
      return CommandResult(
        success: true,
        summary: 'Added bill "${bill.title}" '
            '(\$${bill.amount.toStringAsFixed(2)}) '
            'due ${DateFormat('MMM d').format(bill.dueOn)}.',
        command: cmd,
        resolvedId: bill.id,
        resolvedTitle: bill.title,
        resolvedKind: 'bill',
      );
    }
    if (cmd is UpdateBill) {
      final existing = await _repo.getBill(cmd.id);
      if (existing == null) {
        return CommandResult(
          success: false,
          summary: 'Bill not found.',
          command: cmd,
        );
      }
      final updated = existing.copyWith(
        title: cmd.title,
        amount: cmd.amount,
        dueOn: cmd.dueOn,
        cadence: cmd.cadence,
        category: cmd.category,
        updatedAt: now,
      );
      await _repo.upsertBill(updated);
      return CommandResult(
        success: true,
        summary: 'Updated bill "${updated.title}".',
        command: cmd,
        resolvedId: updated.id,
        resolvedTitle: updated.title,
        resolvedKind: 'bill',
      );
    }
    if (cmd is DeleteBill) {
      final resolved = await _resolveBill(cmd.id, cmd.title);
      if (resolved == null) {
        return CommandResult(
          success: false,
          summary: 'Bill not found.',
          command: cmd,
        );
      }
      await _repo.deleteBill(resolved.id);
      return CommandResult(
        success: true,
        summary: 'Deleted bill "${resolved.title}".',
        command: cmd,
        resolvedId: resolved.id,
        resolvedTitle: resolved.title,
        resolvedKind: 'bill',
      );
    }

    // ── Custom lists ─────────────────────────────────────────────────────
    if (cmd is CreateCustomList) {
      final list = cmd.toList(now: now);
      await _repo.upsertList(list);
      return CommandResult(
        success: true,
        summary: 'Created list "${list.title}".',
        command: cmd,
        resolvedId: list.id,
        resolvedTitle: list.title,
        resolvedKind: 'list',
      );
    }
    if (cmd is UpdateCustomList) {
      final existing = await _repo.getList(cmd.id);
      if (existing == null) {
        return CommandResult(
          success: false,
          summary: 'List not found.',
          command: cmd,
        );
      }
      final updated = existing.copyWith(
        title: cmd.title,
        emoji: cmd.emoji,
        clearEmoji: cmd.clearEmoji,
        updatedAt: now,
      );
      await _repo.upsertList(updated);
      return CommandResult(
        success: true,
        summary: 'Updated list "${updated.title}".',
        command: cmd,
        resolvedId: updated.id,
        resolvedTitle: updated.title,
        resolvedKind: 'list',
      );
    }
    if (cmd is DeleteCustomList) {
      final resolved = await _resolveList(cmd.id, cmd.title);
      if (resolved == null) {
        return CommandResult(
          success: false,
          summary: 'List not found.',
          command: cmd,
        );
      }
      await _repo.deleteList(resolved.id);
      return CommandResult(
        success: true,
        summary: 'Deleted list "${resolved.title}".',
        command: cmd,
        resolvedId: resolved.id,
        resolvedTitle: resolved.title,
        resolvedKind: 'list',
      );
    }
    if (cmd is AddCustomListItem) {
      final item = cmd.toItem(now: now);
      await _repo.upsertItem(item);
      return CommandResult(
        success: true,
        summary: 'Added "${item.label}".',
        command: cmd,
      );
    }
    if (cmd is RemoveCustomListItem) {
      // Resolve by id first, then by label+listTitle.
      Item? item;
      if (cmd.id != null) {
        final all = await _repo.listItems();
        for (final it in all) {
          if (it.id == cmd.id) {
            item = it;
            break;
          }
        }
      }
      item ??= await _resolveItemByLabel(cmd.label, cmd.listTitle);
      if (item == null) {
        return CommandResult(
          success: false,
          summary: 'Item not found.',
          command: cmd,
        );
      }
      await _repo.deleteItem(item.id);
      return CommandResult(
        success: true,
        summary: 'Removed "${item.label}".',
        command: cmd,
      );
    }

    return CommandResult(
      success: false,
      summary: 'Unknown command: ${cmd.actionName}',
      command: cmd,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Resolution helpers — turn an id-or-title into the actual entity.

  Future<Task?> _resolveTask(String? id, String? title) async {
    if (id != null) return _repo.getTask(id);
    if (title == null) return null;
    return _findByTitle<Task>(
      await _repo.listTasks(),
      title,
      (t) => t.title,
    );
  }

  Future<Habit?> _resolveHabit(String? id, String? title) async {
    if (id != null) return _repo.getHabit(id);
    if (title == null) return null;
    return _findByTitle<Habit>(
      await _repo.listHabits(),
      title,
      (h) => h.title,
    );
  }

  Future<Expense?> _resolveExpense(String? id, String? labelOrTitle) async {
    if (id != null) return _repo.getExpense(id);
    if (labelOrTitle == null) return null;
    return _findByTitle<Expense>(
      await _repo.listExpenses(),
      labelOrTitle,
      (e) => e.label,
    );
  }

  Future<RecurringExpense?> _resolveRecurring(
      String? id, String? labelOrTitle) async {
    if (id != null) return _repo.getRecurring(id);
    if (labelOrTitle == null) return null;
    return _findByTitle<RecurringExpense>(
      await _repo.listRecurringExpenses(),
      labelOrTitle,
      (r) => r.label,
    );
  }

  Future<Reminder?> _resolveReminder(String? id, String? title) async {
    if (id != null) return _repo.getReminder(id);
    if (title == null) return null;
    return _findByTitle<Reminder>(
      await _repo.listReminders(),
      title,
      (r) => r.title,
    );
  }

  Future<Bill?> _resolveBill(String? id, String? title) async {
    if (id != null) return _repo.getBill(id);
    if (title == null) return null;
    return _findByTitle<Bill>(
      await _repo.listBills(),
      title,
      (b) => b.title,
    );
  }

  Future<CustomList?> _resolveList(String? id, String? title) async {
    if (id != null) return _repo.getList(id);
    if (title == null) return null;
    return _findByTitle<CustomList>(
      await _repo.listCustomLists(),
      title,
      (l) => l.title,
    );
  }

  Future<Item?> _resolveItemByLabel(String? label, String? listTitle) async {
    if (label == null) return null;
    final lists = await _repo.listCustomLists();
    CustomList? target;
    if (listTitle != null) {
      target = await _resolveList(null, listTitle);
    }
    target ??= lists.isNotEmpty ? lists.first : null;
    if (target == null) return null;
    final items = await _repo.listItemsForList(target.id);
    return _findByTitle<Item>(items, label, (i) => i.label);
  }

  /// Case-insensitive substring match. Prefers exact match, falls back to
  /// contains. Returns the most recently created (last in list).
  T? _findByTitle<T>(List<T> items, String query, String Function(T) getTitle) {
    final q = query.toLowerCase();
    T? exact;
    T? partial;
    for (final item in items) {
      final title = getTitle(item).toLowerCase();
      if (title == q) {
        exact = item;
      } else if (partial == null && title.contains(q)) {
        partial = item;
      }
    }
    return exact ?? partial;
  }
}

// Local alias to avoid importing the model in the public surface.
typedef Item = CustomListItem;
