import 'package:intl/intl.dart';

import '../repositories/entity_repositories.dart';
import 'command.dart';

/// Result of executing a single command.
class CommandResult {
  final bool success;
  final String summary;
  final Command command;
  final String? error;

  const CommandResult({
    required this.success,
    required this.summary,
    required this.command,
    this.error,
  });
}

/// Runs parsed Commands against the database.
///
/// Each command type maps to a repository call. UPDATE commands fetch
/// the existing entity first, apply the partial updates, and save back.
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
      );
    }
    if (cmd is UpdateTask) {
      final existing = await _repo.getTask(cmd.id);
      if (existing == null) {
        return CommandResult(
          success: false,
          summary: 'Task not found.',
          command: cmd,
        );
      }
      final updated = existing.copyWith(
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
      );
    }
    if (cmd is DeleteTask) {
      await _repo.deleteTask(cmd.id);
      return CommandResult(
        success: true,
        summary: 'Deleted task.',
        command: cmd,
      );
    }
    if (cmd is MarkTaskComplete) {
      final existing = await _repo.getTask(cmd.id);
      if (existing == null) {
        return CommandResult(
          success: false,
          summary: 'Task not found.',
          command: cmd,
        );
      }
      await _repo.upsertTask(existing.copyWith(isComplete: true, updatedAt: now));
      return CommandResult(
        success: true,
        summary: 'Marked task "${existing.title}" complete.',
        command: cmd,
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
      );
    }
    if (cmd is UpdateHabit) {
      final habit = await _repo.getHabit(cmd.id);
      if (habit == null) {
        return CommandResult(
          success: false,
          summary: 'Habit not found.',
          command: cmd,
        );
      }
      final updated = habit.copyWith(
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
      );
    }
    if (cmd is DeleteHabit) {
      await _repo.deleteHabit(cmd.id);
      return CommandResult(
        success: true,
        summary: 'Deleted habit.',
        command: cmd,
      );
    }

    // ── Expenses ─────────────────────────────────────────────────────────
    if (cmd is CreateExpense) {
      final expense = cmd.toExpense(now: now);
      await _repo.upsertExpense(expense);
      return CommandResult(
        success: true,
        summary:
            'Added expense "${expense.label}" (\$${expense.amount.toStringAsFixed(2)}) on ${_fmtDate(expense.spentOn)}.',
        command: cmd,
      );
    }
    if (cmd is UpdateExpense) {
      // UpdateExpense fetches via id — Phase 2 keeps it simple.
      // Phase 5 will add title-based lookup.
      final all = await _repo.listExpenses();
      final existing = all.where((e) => e.id == cmd.id).firstOrNull;
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
      );
    }
    if (cmd is DeleteExpense) {
      await _repo.deleteExpense(cmd.id);
      return CommandResult(
        success: true,
        summary: 'Deleted expense.',
        command: cmd,
      );
    }

    // ── Recurring expenses ───────────────────────────────────────────────
    if (cmd is CreateRecurringExpense) {
      final r = cmd.toRecurringExpense(now: now);
      await _repo.upsertRecurringExpense(r);
      return CommandResult(
        success: true,
        summary:
            'Added recurring expense "${r.label}" (\$${r.amount.toStringAsFixed(2)}, ${r.cadence}).',
        command: cmd,
      );
    }
    if (cmd is DeleteRecurringExpense) {
      await _repo.deleteRecurringExpense(cmd.id);
      return CommandResult(
        success: true,
        summary: 'Deleted recurring expense.',
        command: cmd,
      );
    }

    // ── Reminders ────────────────────────────────────────────────────────
    if (cmd is CreateReminder) {
      final r = cmd.toReminder(now: now);
      await _repo.upsertReminder(r);
      return CommandResult(
        success: true,
        summary: 'Reminder "${r.title}" set for ${_fmtDateTime(r.remindAt)}.',
        command: cmd,
      );
    }
    if (cmd is UpdateReminder) {
      // Fetch, mutate, save
      final all = await _repo.listReminders();
      final existing = all.where((r) => r.id == cmd.id).firstOrNull;
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
      );
    }
    if (cmd is DeleteReminder) {
      await _repo.deleteReminder(cmd.id);
      return CommandResult(
        success: true,
        summary: 'Deleted reminder.',
        command: cmd,
      );
    }

    // ── Bills ────────────────────────────────────────────────────────────
    if (cmd is CreateBill) {
      final b = cmd.toBill(now: now);
      await _repo.upsertBill(b);
      return CommandResult(
        success: true,
        summary:
            'Added bill "${b.title}" (\$${b.amount.toStringAsFixed(2)}) due ${_fmtDate(b.dueOn)}.',
        command: cmd,
      );
    }
    if (cmd is DeleteBill) {
      await _repo.deleteBill(cmd.id);
      return CommandResult(
        success: true,
        summary: 'Deleted bill.',
        command: cmd,
      );
    }

    // ── Custom lists ─────────────────────────────────────────────────────
    if (cmd is CreateCustomList) {
      final l = cmd.toList(now: now);
      await _repo.upsertCustomList(l);
      return CommandResult(
        success: true,
        summary: 'Created list "${l.title}".',
        command: cmd,
      );
    }
    if (cmd is DeleteCustomList) {
      await _repo.deleteCustomList(cmd.id);
      return CommandResult(
        success: true,
        summary: 'Deleted list.',
        command: cmd,
      );
    }
    if (cmd is AddCustomListItem) {
      final item = cmd.toItem(now: now);
      await _repo.upsertCustomListItem(item);
      return CommandResult(
        success: true,
        summary: 'Added "${item.label}" to the list.',
        command: cmd,
      );
    }
    if (cmd is RemoveCustomListItem) {
      await _repo.deleteCustomListItem(cmd.id);
      return CommandResult(
        success: true,
        summary: 'Removed item from list.',
        command: cmd,
      );
    }

    return CommandResult(
      success: false,
      summary: 'Unhandled command type.',
      command: cmd,
    );
  }

  static final _dateFmt = DateFormat('MMM d');
  static final _dateTimeFmt = DateFormat('MMM d, HH:mm');

  static String _fmtDate(DateTime d) => _dateFmt.format(d);
  static String _fmtDateTime(DateTime d) => _dateTimeFmt.format(d);
}
