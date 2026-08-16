import '../models/bill.dart';
import '../models/custom_list.dart';
import '../models/expense.dart';
import '../models/habit.dart';
import '../models/recurring_expense.dart';
import '../models/reminder.dart';
import '../models/task.dart';

/// A structured command the AI returned, ready to be executed.
///
/// Each command maps 1:1 to a database operation. The AI emits commands
/// in JSON inside a fenced ```json block at the end of its reply; the
/// parser converts that JSON into these typed objects.
///
/// To add a new command:
///   1. Add a new subtype here.
///   2. Add a JSON factory in CommandParser (or use the catch-all factory).
///   3. Add a case in CommandExecutor.execute().
///   4. Document it in the system prompt.
sealed class Command {
  const Command();

  /// Short name used in JSON ("CREATE_TASK", "DELETE_HABIT", ...).
  String get actionName;
}

// ─────────────────────────────────────────────────────────────────────────
// Tasks

class CreateTask extends Command {
  @override
  String get actionName => 'CREATE_TASK';
  final String id;
  final String title;
  final String? notes;
  final DateTime? dueDate;
  final DateTime? dueTime;
  final int priority;
  final String? category;
  final String? recurrence;

  const CreateTask({
    required this.id,
    required this.title,
    this.notes,
    this.dueDate,
    this.dueTime,
    this.priority = 0,
    this.category,
    this.recurrence,
  });

  Task toTask({required DateTime now}) => Task(
        id: id,
        title: title,
        notes: notes,
        dueDate: dueDate,
        dueTime: dueTime,
        priority: priority,
        category: category,
        recurrence: recurrence,
        createdAt: now,
        updatedAt: now,
      );
}

class UpdateTask extends Command {
  @override
  String get actionName => 'UPDATE_TASK';
  final String id;
  final String? title;
  final String? notes;
  final DateTime? dueDate;
  final DateTime? dueTime;
  final bool? isComplete;
  final int? priority;
  final String? category;
  final String? recurrence;

  /// When true, clear dueDate (vs leave unchanged).
  final bool clearDueDate;
  final bool clearDueTime;
  final bool clearRecurrence;

  const UpdateTask({
    required this.id,
    this.title,
    this.notes,
    this.dueDate,
    this.dueTime,
    this.isComplete,
    this.priority,
    this.category,
    this.recurrence,
    this.clearDueDate = false,
    this.clearDueTime = false,
    this.clearRecurrence = false,
  });
}

class DeleteTask extends Command {
  @override
  String get actionName => 'DELETE_TASK';
  final String id;
  const DeleteTask(this.id);
}

class MarkTaskComplete extends Command {
  @override
  String get actionName => 'MARK_TASK_COMPLETE';
  final String id;
  const MarkTaskComplete(this.id);
}

// ─────────────────────────────────────────────────────────────────────────
// Habits

class CreateHabit extends Command {
  @override
  String get actionName => 'CREATE_HABIT';
  final String id;
  final String title;
  final Map<String, dynamic> recurrence;

  const CreateHabit({
    required this.id,
    required this.title,
    required this.recurrence,
  });

  Habit toHabit({required DateTime now}) => Habit(
        id: id,
        title: title,
        recurrence: recurrence,
        createdAt: now,
        updatedAt: now,
      );
}

class UpdateHabit extends Command {
  @override
  String get actionName => 'UPDATE_HABIT';
  final String id;
  final String? title;
  final Map<String, dynamic>? recurrence;
  final bool? isPaused;

  const UpdateHabit({
    required this.id,
    this.title,
    this.recurrence,
    this.isPaused,
  });
}

class DeleteHabit extends Command {
  @override
  String get actionName => 'DELETE_HABIT';
  final String id;
  const DeleteHabit(this.id);
}

// ─────────────────────────────────────────────────────────────────────────
// Expenses

class CreateExpense extends Command {
  @override
  String get actionName => 'CREATE_EXPENSE';
  final String id;
  final String label;
  final double amount;
  final DateTime spentOn;
  final String? category;
  final String? notes;
  final bool isPlanned;

  const CreateExpense({
    required this.id,
    required this.label,
    required this.amount,
    required this.spentOn,
    this.category,
    this.notes,
    this.isPlanned = true,
  });

  Expense toExpense({required DateTime now}) => Expense(
        id: id,
        label: label,
        amount: amount,
        spentOn: spentOn,
        category: category,
        notes: notes,
        isPlanned: isPlanned,
        createdAt: now,
        updatedAt: now,
      );
}

class UpdateExpense extends Command {
  @override
  String get actionName => 'UPDATE_EXPENSE';
  final String id;
  final String? label;
  final double? amount;
  final DateTime? spentOn;
  final String? category;
  final String? notes;
  final bool? isPlanned;

  const UpdateExpense({
    required this.id,
    this.label,
    this.amount,
    this.spentOn,
    this.category,
    this.notes,
    this.isPlanned,
  });
}

class DeleteExpense extends Command {
  @override
  String get actionName => 'DELETE_EXPENSE';
  final String id;
  const DeleteExpense(this.id);
}

// ─────────────────────────────────────────────────────────────────────────
// Recurring expenses

class CreateRecurringExpense extends Command {
  @override
  String get actionName => 'CREATE_RECURRING_EXPENSE';
  final String id;
  final String label;
  final double amount;
  final String cadence;
  final DateTime nextDue;
  final String? category;

  const CreateRecurringExpense({
    required this.id,
    required this.label,
    required this.amount,
    required this.cadence,
    required this.nextDue,
    this.category,
  });

  RecurringExpense toRecurringExpense({required DateTime now}) =>
      RecurringExpense(
        id: id,
        label: label,
        amount: amount,
        cadence: cadence,
        nextDue: nextDue,
        category: category,
        createdAt: now,
        updatedAt: now,
      );
}

class DeleteRecurringExpense extends Command {
  @override
  String get actionName => 'DELETE_RECURRING_EXPENSE';
  final String id;
  const DeleteRecurringExpense(this.id);
}

// ─────────────────────────────────────────────────────────────────────────
// Reminders

class CreateReminder extends Command {
  @override
  String get actionName => 'CREATE_REMINDER';
  final String id;
  final String title;
  final DateTime remindAt;
  final String? cadence;
  final int priority;
  final String? category;

  const CreateReminder({
    required this.id,
    required this.title,
    required this.remindAt,
    this.cadence,
    this.priority = 0,
    this.category,
  });

  Reminder toReminder({required DateTime now}) => Reminder(
        id: id,
        title: title,
        remindAt: remindAt,
        cadence: cadence,
        priority: priority,
        category: category,
        createdAt: now,
        updatedAt: now,
      );
}

class UpdateReminder extends Command {
  @override
  String get actionName => 'UPDATE_REMINDER';
  final String id;
  final String? title;
  final DateTime? remindAt;
  final String? cadence;
  final int? priority;
  final String? category;
  final bool? isDone;
  final bool clearCadence;

  const UpdateReminder({
    required this.id,
    this.title,
    this.remindAt,
    this.cadence,
    this.priority,
    this.category,
    this.isDone,
    this.clearCadence = false,
  });
}

class DeleteReminder extends Command {
  @override
  String get actionName => 'DELETE_REMINDER';
  final String id;
  const DeleteReminder(this.id);
}

// ─────────────────────────────────────────────────────────────────────────
// Bills

class CreateBill extends Command {
  @override
  String get actionName => 'CREATE_BILL';
  final String id;
  final String title;
  final double amount;
  final DateTime dueOn;
  final String? cadence;
  final String? category;

  const CreateBill({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueOn,
    this.cadence,
    this.category,
  });

  Bill toBill({required DateTime now}) => Bill(
        id: id,
        title: title,
        amount: amount,
        dueOn: dueOn,
        cadence: cadence,
        category: category,
        createdAt: now,
        updatedAt: now,
      );
}

class DeleteBill extends Command {
  @override
  String get actionName => 'DELETE_BILL';
  final String id;
  const DeleteBill(this.id);
}

// ─────────────────────────────────────────────────────────────────────────
// Custom lists

class CreateCustomList extends Command {
  @override
  String get actionName => 'CREATE_CUSTOM_LIST';
  final String id;
  final String title;
  final String? emoji;

  const CreateCustomList({
    required this.id,
    required this.title,
    this.emoji,
  });

  CustomList toList({required DateTime now}) => CustomList(
        id: id,
        title: title,
        emoji: emoji,
        createdAt: now,
        updatedAt: now,
      );
}

class DeleteCustomList extends Command {
  @override
  String get actionName => 'DELETE_CUSTOM_LIST';
  final String id;
  const DeleteCustomList(this.id);
}

class AddCustomListItem extends Command {
  @override
  String get actionName => 'ADD_CUSTOM_LIST_ITEM';
  final String id;
  final String listId;
  final String label;
  final int position;

  const AddCustomListItem({
    required this.id,
    required this.listId,
    required this.label,
    this.position = 0,
  });

  CustomListItem toItem({required DateTime now}) => CustomListItem(
        id: id,
        listId: listId,
        label: label,
        position: position,
        createdAt: now,
        updatedAt: now,
      );
}

class RemoveCustomListItem extends Command {
  @override
  String get actionName => 'REMOVE_CUSTOM_LIST_ITEM';
  final String id;
  const RemoveCustomListItem(this.id);
}
