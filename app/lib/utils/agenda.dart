import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../models/recurring_expense.dart';
import '../models/reminder.dart';
import '../models/task.dart';
import '../models/timeline_entry.dart';

/// Builds the agenda: all schedulable entities flattened into a single
/// time-ordered list of TimelineEntry.
///
/// Includes:
///   - Tasks with dueDate set
///   - Reminders (their remindAt)
///   - Bills (dueOn)
///   - Recurring expenses (nextDue, if not paused)
///   - Habits are NOT included (those are tracked by streak — Phase 6)
///   - One-off expenses are NOT included (those are tracked under Expenses tab)
List<TimelineEntry> buildAgenda({
  required List<Task> tasks,
  required List<Reminder> reminders,
  required List<Bill> bills,
  required List<RecurringExpense> recurringExpenses,
}) {
  final entries = <TimelineEntry>[];

  for (final t in tasks) {
    if (t.dueDate == null) continue;
    final due = t.dueDate!;
    final dateTime = (t.dueTime != null)
        ? DateTime(due.year, due.month, due.day, t.dueTime!.hour, t.dueTime!.minute)
        : DateTime(due.year, due.month, due.day);
    entries.add(TimelineEntry(
      kind: TimelineKind.task,
      id: t.id,
      title: t.title,
      subtitle: t.notes ?? t.category,
      when: dateTime,
      time: t.dueTime == null
          ? null
          : TimeOfDay(hour: t.dueTime!.hour, minute: t.dueTime!.minute),
      isDone: t.isComplete,
      priority: t.priority,
      source: t,
    ));
  }

  for (final r in reminders) {
    entries.add(TimelineEntry(
      kind: TimelineKind.reminder,
      id: r.id,
      title: r.title,
      subtitle: r.category,
      when: r.remindAt,
      time: TimeOfDay(hour: r.remindAt.hour, minute: r.remindAt.minute),
      isDone: r.isDone,
      source: r,
    ));
  }

  for (final b in bills) {
    final dt = DateTime(b.dueOn.year, b.dueOn.month, b.dueOn.day);
    entries.add(TimelineEntry(
      kind: TimelineKind.bill,
      id: b.id,
      title: b.title,
      subtitle: b.category,
      when: dt,
      isDone: b.isPaid,
      source: b,
    ));
  }

  for (final r in recurringExpenses) {
    if (r.isPaused) continue;
    final dt = DateTime(r.nextDue.year, r.nextDue.month, r.nextDue.day);
    entries.add(TimelineEntry(
      kind: TimelineKind.recurring,
      id: r.id,
      title: r.label,
      subtitle: r.cadence,
      when: dt,
      source: r,
    ));
  }

  // Sort by (when, kind weight). Reminders come before tasks at the same
  // time so the most "alarmy" thing is on top.
  entries.sort((a, b) {
    final cmp = a.when.compareTo(b.when);
    if (cmp != 0) return cmp;
    return a.kind.index.compareTo(b.kind.index);
  });
  return entries;
}

/// Convenience: split an agenda into day-bucketed rows for rendering.
///
/// Each row is either a DayHeader or a TimelineEntry. Sticky headers
/// use the same day; the agenda screen wires them to SliverPersistentHeader.
enum AgendaRowKind { header, entry }

class AgendaRow {
  final AgendaRowKind kind;
  /// Day for [AgendaRowKind.header]; null for [AgendaRowKind.entry].
  /// Use [AgendaRow.entryDay] to get the entry's day.
  final DateTime? day;
  final TimelineEntry? entry; // null when kind == header
  const AgendaRow.header(DateTime this.day)
      : kind = AgendaRowKind.header,
        entry = null;
  const AgendaRow.entry(TimelineEntry this.entry)
      : kind = AgendaRowKind.entry,
        day = null;
}

List<AgendaRow> groupAgendaByDay(List<TimelineEntry> entries) {
  if (entries.isEmpty) return const [];
  final rows = <AgendaRow>[];
  DateTime? lastDay;
  for (final e in entries) {
    final d = e.day;
    if (lastDay == null || lastDay != d) {
      rows.add(AgendaRow.header(d));
      lastDay = d;
    }
    rows.add(AgendaRow.entry(e));
  }
  return rows;
}
