import 'package:flutter/material.dart';

/// One scheduled item in the agenda view.
///
/// Tasks, reminders, bills, and recurring-expense next-due dates all
/// become TimelineEntry items. The agenda sorts them by date+time
/// and groups them under sticky day headers.
enum TimelineKind { task, reminder, bill, recurring }

class TimelineEntry {
  final TimelineKind kind;
  final String id;
  final String title;
  final String? subtitle;
  final DateTime when; // the date this entry "happens"
  final TimeOfDay? time; // optional time component
  final bool isDone; // tasks.isComplete || reminders.isDone || bills.isPaid
  final int priority; // tasks.priority (0=normal, 1=high, 2=urgent)
  /// The original entity (Task / Reminder / Bill / RecurringExpense).
  /// Typed as Object here; the agenda UI casts back to the concrete type
  /// when opening an editor.
  final Object source;

  const TimelineEntry({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.when,
    required this.source,
    this.time,
    this.isDone = false,
    this.priority = 0,
  });

  /// The day (00:00 local) this entry falls on.
  DateTime get day => DateTime(when.year, when.month, when.day);
}
