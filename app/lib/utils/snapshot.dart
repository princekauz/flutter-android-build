import 'package:intl/intl.dart';

import '../models/bill.dart';
import '../models/expense.dart';
import '../models/habit.dart';
import '../models/recurring_expense.dart';
import '../models/reminder.dart';
import '../models/task.dart';
import '../models/timeline_entry.dart';
import 'agenda.dart';

/// A computed snapshot of the user's data, used as part of the AI's
/// system context.
///
/// The AI gets this as plain markdown so it can quickly answer questions
/// like "what's due tomorrow?" or "how much did I spend this week?"
/// without having to do the math itself.
class DataSnapshot {
  final DateTime generatedAt;
  final List<Task> tasks;
  final List<Reminder> reminders;
  final List<Bill> bills;
  final List<RecurringExpense> recurringExpenses;
  final List<Expense> expenses;
  final List<Habit> habits;

  // Pre-computed aggregates
  late final double _expensesToday =
      _sumExpenses(expenses, _today);
  late final double _expensesThisWeek =
      _sumExpenses(expenses, _weekStart);
  late final double _expensesThisMonth =
      _sumExpenses(expenses, _monthStart);
  late final List<TimelineEntry> _upcomingWeek =
      buildAgenda(
        tasks: tasks,
        reminders: reminders,
        bills: bills,
        recurringExpenses: recurringExpenses,
      ).where(_isWithinNextWeek).toList();
  late final List<TimelineEntry> _overdue =
      buildAgenda(
        tasks: tasks,
        reminders: reminders,
        bills: bills,
        recurringExpenses: recurringExpenses,
      ).where(_isOverdue).toList();

  DataSnapshot({
    required this.generatedAt,
    required this.tasks,
    required this.reminders,
    required this.bills,
    required this.recurringExpenses,
    required this.expenses,
    required this.habits,
  });

  DateTime get _today {
    final n = generatedAt;
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get _weekStart => _today.subtract(Duration(days: _today.weekday - 1));
  DateTime get _monthStart => DateTime(_today.year, _today.month, 1);

  bool _isWithinNextWeek(TimelineEntry e) {
    final end = _today.add(const Duration(days: 7));
    return e.day.isAfter(_today.subtract(const Duration(days: 1))) &&
        e.day.isBefore(end);
  }

  bool _isOverdue(TimelineEntry e) {
    if (e.isDone) return false;
    return e.day.isBefore(_today);
  }

  double _sumExpenses(List<Expense> list, DateTime since) {
    return list
        .where((e) =>
            e.spentOn.isAfter(since.subtract(const Duration(seconds: 1))))
        .fold<double>(0, (sum, e) => sum + e.amount);
  }

  /// Markdown render of the snapshot. Kept short so it doesn't blow up the
  /// AI's context window.
  String toMarkdown() {
    final fmtDate = DateFormat('EEE, MMM d');
    final fmtTime = DateFormat('HH:mm');
    final sb = StringBuffer();

    sb.writeln('# Data snapshot (${fmtDate.format(_today)})');
    sb.writeln();

    // Expenses
    sb.writeln('## Expenses');
    sb.writeln('- Today: \$${_expensesToday.toStringAsFixed(2)}');
    sb.writeln(
        '- This week (since ${fmtDate.format(_weekStart)}): \$${_expensesThisWeek.toStringAsFixed(2)}');
    sb.writeln(
        '- This month: \$${_expensesThisMonth.toStringAsFixed(2)}');
    if (expenses.isNotEmpty) {
      final byCategory = <String, double>{};
      for (final e in expenses) {
        final cat = e.category ?? '(uncategorized)';
        byCategory[cat] = (byCategory[cat] ?? 0) + e.amount;
      }
      final cats = byCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = cats.take(5).map((e) => '${e.key}: \$${e.value.toStringAsFixed(2)}');
      sb.writeln('- Top categories (all-time): ${top.join(", ")}');
    }
    sb.writeln();

    // Upcoming week
    sb.writeln('## Upcoming (next 7 days)');
    if (_upcomingWeek.isEmpty) {
      sb.writeln('- Nothing scheduled.');
    } else {
      for (final e in _upcomingWeek) {
        final time = e.time != null
            ? ' ${fmtTime.format(DateTime(0, 1, 1, e.time!.hour, e.time!.minute))}'
            : '';
        final kind = _kindLabel(e.kind);
        sb.writeln('- ${fmtDate.format(e.day)}$time — [$kind] ${e.title}');
      }
    }
    sb.writeln();

    // Overdue
    if (_overdue.isNotEmpty) {
      sb.writeln('## Overdue');
      for (final e in _overdue) {
        final kind = _kindLabel(e.kind);
        sb.writeln('- ${fmtDate.format(e.day)} — [$kind] ${e.title}');
      }
      sb.writeln();
    }

    return sb.toString();
  }

  String _kindLabel(TimelineKind k) {
    switch (k) {
      case TimelineKind.task:
        return 'task';
      case TimelineKind.reminder:
        return 'reminder';
      case TimelineKind.bill:
        return 'bill';
      case TimelineKind.recurring:
        return 'recurring';
    }
  }
}
