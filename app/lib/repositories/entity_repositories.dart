import 'package:sqflite/sqflite.dart';

import '../models/bill.dart';
import '../models/custom_list.dart';
import '../models/expense.dart';
import '../models/habit.dart';
import '../models/recurring_expense.dart';
import '../models/reminder.dart';
import '../models/task.dart';
import '../storage/app_database.dart';

/// Aggregated repositories for all entity types.
///
/// Each repository is thin — just typed wrappers around the same `db.raw`
/// handle. They share a connection but expose entity-specific CRUD methods.
/// Phase 5 will add query methods (by date range, by category, etc.).
class EntityRepositories {
  EntityRepositories(this._db);

  final AppDatabase _db;
  Database get _raw => _db.raw;

  // ─────────────────────────────────────────────────────────────────────
  // Tasks

  Future<List<Task>> listTasks() async {
    final rows = await _raw.query('tasks', orderBy: 'due_date ASC, created_at DESC');
    return rows.map(Task.fromRow).toList();
  }

  Future<Task?> getTask(String id) async {
    final rows = await _raw.query('tasks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Task.fromRow(rows.first);
  }

  Future<void> upsertTask(Task task) async {
    await _raw.insert('tasks', task.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTask(String id) async {
    await _raw.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Habits

  Future<List<Habit>> listHabits() async {
    final rows = await _raw.query('habits', orderBy: 'created_at DESC');
    return rows.map(Habit.fromRow).toList();
  }

  Future<Habit?> getHabit(String id) async {
    final rows =
        await _raw.query('habits', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Habit.fromRow(rows.first);
  }

  Future<void> upsertHabit(Habit habit) async {
    await _raw.insert('habits', habit.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteHabit(String id) async {
    await _raw.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Expenses

  Future<List<Expense>> listExpenses() async {
    final rows = await _raw.query('expenses', orderBy: 'spent_on ASC');
    return rows.map(Expense.fromRow).toList();
  }

  Future<void> upsertExpense(Expense expense) async {
    await _raw.insert('expenses', expense.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteExpense(String id) async {
    await _raw.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Recurring expenses

  Future<List<RecurringExpense>> listRecurringExpenses() async {
    final rows =
        await _raw.query('recurring_expenses', orderBy: 'next_due ASC');
    return rows.map(RecurringExpense.fromRow).toList();
  }

  Future<void> upsertRecurringExpense(RecurringExpense r) async {
    await _raw.insert('recurring_expenses', r.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteRecurringExpense(String id) async {
    await _raw.delete('recurring_expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Reminders

  Future<List<Reminder>> listReminders() async {
    final rows = await _raw.query('reminders', orderBy: 'remind_at ASC');
    return rows.map(Reminder.fromRow).toList();
  }

  Future<void> upsertReminder(Reminder r) async {
    await _raw.insert('reminders', r.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteReminder(String id) async {
    await _raw.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Bills

  Future<List<Bill>> listBills() async {
    final rows = await _raw.query('bills', orderBy: 'due_on ASC');
    return rows.map(Bill.fromRow).toList();
  }

  Future<void> upsertBill(Bill b) async {
    await _raw.insert('bills', b.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteBill(String id) async {
    await _raw.delete('bills', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Custom lists

  Future<List<CustomList>> listCustomLists() async {
    final rows = await _raw.query('custom_lists', orderBy: 'created_at DESC');
    return rows.map(CustomList.fromRow).toList();
  }

  Future<void> upsertCustomList(CustomList l) async {
    await _raw.insert('custom_lists', l.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCustomList(String id) async {
    await _raw.delete('custom_lists', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CustomListItem>> listItemsForList(String listId) async {
    final rows = await _raw.query(
      'custom_list_items',
      where: 'list_id = ?',
      whereArgs: [listId],
      orderBy: 'position ASC, created_at ASC',
    );
    return rows.map(CustomListItem.fromRow).toList();
  }

  Future<void> upsertCustomListItem(CustomListItem item) async {
    await _raw.insert('custom_list_items', item.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCustomListItem(String id) async {
    await _raw.delete('custom_list_items', where: 'id = ?', whereArgs: [id]);
  }
}
