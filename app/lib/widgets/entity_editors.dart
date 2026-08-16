import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../models/custom_list.dart';
import '../models/expense.dart';
import '../models/habit.dart';
import '../models/recurring_expense.dart';
import '../models/reminder.dart';
import '../models/task.dart';
import '../repositories/entity_repositories.dart';
import '../utils/ids.dart';
import 'form_dialog.dart';
import 'form_fields.dart';

// ─────────────────────────────────────────────────────────────────────────
// Task editor

Future<void> showTaskEditor(
  BuildContext context,
  EntityRepositories repo, {
  Task? existing,
  required VoidCallback onChanged,
}) async {
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  final categoryCtrl = TextEditingController(text: existing?.category ?? '');
  DateTime? dueDate = existing?.dueDate;
  DateTime? dueTime = existing?.dueTime;
  int priority = existing?.priority ?? 0;

  await FormDialog.show(
    context,
    title: existing == null ? 'New task' : 'Edit task',
    builder: (ctx) => [
      TextField(
        controller: titleCtrl,
        decoration: const InputDecoration(
          labelText: 'Title',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      sizedBoxH,
      TextField(
        controller: notesCtrl,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Notes (optional)',
          border: OutlineInputBorder(),
        ),
      ),
      sizedBoxH,
      Row(
        children: [
          Expanded(
            child: DateField(
              label: 'Due date',
              value: dueDate,
              onChanged: (v) => dueDate = v,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DateTimeField(
              label: 'Due time',
              value: dueTime,
              onChanged: (v) => dueTime = v,
            ),
          ),
        ],
      ),
      sizedBoxH,
      FormSection(
        title: 'Priority',
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Normal')),
              ButtonSegment(value: 1, label: Text('High')),
              ButtonSegment(value: 2, label: Text('Urgent')),
            ],
            selected: {priority},
            onSelectionChanged: (s) => priority = s.first,
          ),
        ],
      ),
      sizedBoxH,
      TextField(
        controller: categoryCtrl,
        decoration: const InputDecoration(
          labelText: 'Category (optional)',
          border: OutlineInputBorder(),
        ),
      ),
    ],
    onSave: () async {
      final title = titleCtrl.text.trim();
      if (title.isEmpty) return;
      final now = DateTime.now();
      final task = existing == null
          ? Task(
              id: newEntityId(),
              title: title,
              notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
              dueDate: dueDate,
              dueTime: dueTime,
              priority: priority,
              category: categoryCtrl.text.trim().isEmpty
                  ? null
                  : categoryCtrl.text.trim(),
              createdAt: now,
              updatedAt: now,
            )
          : existing.copyWith(
              title: title,
              notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
              dueDate: dueDate,
              dueTime: dueTime,
              priority: priority,
              category: categoryCtrl.text.trim().isEmpty
                  ? null
                  : categoryCtrl.text.trim(),
              updatedAt: now,
            );
      await repo.upsertTask(task);
      if (context.mounted) Navigator.of(context).pop(true);
      onChanged();
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Habit editor

Future<void> showHabitEditor(
  BuildContext context,
  EntityRepositories repo, {
  Habit? existing,
  required VoidCallback onChanged,
}) async {
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  RecurrenceType recType = _parseRecurrenceType(existing?.recurrence);
  final selectedDays = <int>{
    ...?existing?.recurrence['days']?.cast<int>(),
  };
  int intervalDays = (existing?.recurrence['days'] as int?) ?? 3;
  bool isPaused = existing?.isPaused ?? false;

  await FormDialog.show(
    context,
    title: existing == null ? 'New habit' : 'Edit habit',
    builder: (ctx) => [
      TextField(
        controller: titleCtrl,
        decoration: const InputDecoration(
          labelText: 'Title',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      sizedBoxH,
      FormSection(title: 'Recurrence', children: [
        DropdownButtonFormField<RecurrenceType>(
          initialValue: recType,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: RecurrenceType.daily, child: Text('Every day')),
            DropdownMenuItem(
                value: RecurrenceType.weekdays, child: Text('Weekdays only (Mon-Fri)')),
            DropdownMenuItem(
                value: RecurrenceType.weekends, child: Text('Weekends (Sat-Sun)')),
            DropdownMenuItem(
                value: RecurrenceType.customDays,
                child: Text('Specific weekdays')),
            DropdownMenuItem(
                value: RecurrenceType.interval, child: Text('Every N days')),
          ],
          onChanged: (v) => recType = v ?? RecurrenceType.daily,
        ),
        if (recType == RecurrenceType.customDays) ...[
          sizedBoxH,
          Wrap(
            spacing: 8,
            children: [
              for (final day in const [
                (1, 'Mon'),
                (2, 'Tue'),
                (3, 'Wed'),
                (4, 'Thu'),
                (5, 'Fri'),
                (6, 'Sat'),
                (7, 'Sun'),
              ])
                FilterChip(
                  label: Text(day.$2),
                  selected: selectedDays.contains(day.$1),
                  onSelected: (s) {
                    if (s) {
                      selectedDays.add(day.$1);
                    } else {
                      selectedDays.remove(day.$1);
                    }
                  },
                ),
            ],
          ),
        ],
        if (recType == RecurrenceType.interval) ...[
          sizedBoxH,
          Row(
            children: [
              const Text('Every '),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: intervalDays.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) =>
                      intervalDays = int.tryParse(v) ?? intervalDays,
                ),
              ),
              const Text(' days'),
            ],
          ),
        ],
      ]),
      sizedBoxH,
      SwitchListTile(
        title: const Text('Paused'),
        subtitle: const Text('Keep the habit but skip reminders'),
        value: isPaused,
        onChanged: (v) => isPaused = v,
        contentPadding: EdgeInsets.zero,
      ),
    ],
    onSave: () async {
      final title = titleCtrl.text.trim();
      if (title.isEmpty) return;
      final recurrence = _buildRecurrence(recType, selectedDays, intervalDays);
      final now = DateTime.now();
      final habit = existing == null
          ? Habit(
              id: newEntityId(),
              title: title,
              recurrence: recurrence,
              isPaused: isPaused,
              createdAt: now,
              updatedAt: now,
            )
          : existing.copyWith(
              title: title,
              recurrence: recurrence,
              isPaused: isPaused,
              updatedAt: now,
            );
      await repo.upsertHabit(habit);
      if (context.mounted) Navigator.of(context).pop(true);
      onChanged();
    },
  );
}

enum RecurrenceType { daily, weekdays, weekends, customDays, interval }

RecurrenceType _parseRecurrenceType(Map<String, dynamic>? r) {
  if (r == null) return RecurrenceType.daily;
  switch (r['type']) {
    case 'daily':
      return RecurrenceType.daily;
    case 'weekdays':
      return RecurrenceType.weekdays;
    case 'weekends':
      return RecurrenceType.weekends;
    case 'weekdays_custom':
    case 'custom':
      return RecurrenceType.customDays;
    case 'interval_days':
      return RecurrenceType.interval;
    default:
      return RecurrenceType.daily;
  }
}

Map<String, dynamic> _buildRecurrence(
  RecurrenceType type,
  Set<int> selectedDays,
  int intervalDays,
) {
  switch (type) {
    case RecurrenceType.daily:
      return {'type': 'daily'};
    case RecurrenceType.weekdays:
      return {'type': 'weekdays', 'days': [1, 2, 3, 4, 5]};
    case RecurrenceType.weekends:
      return {'type': 'weekends', 'days': [6, 7]};
    case RecurrenceType.customDays:
      final days = selectedDays.toList()..sort();
      return {'type': 'weekdays_custom', 'days': days};
    case RecurrenceType.interval:
      return {'type': 'interval_days', 'days': intervalDays};
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Expense editor

Future<void> showExpenseEditor(
  BuildContext context,
  EntityRepositories repo, {
  Expense? existing,
  required VoidCallback onChanged,
}) async {
  final labelCtrl = TextEditingController(text: existing?.label ?? '');
  final amountCtrl =
      TextEditingController(text: existing?.amount.toStringAsFixed(2) ?? '');
  final categoryCtrl = TextEditingController(text: existing?.category ?? '');
  DateTime spentOn = existing?.spentOn ?? DateTime.now();
  bool isPlanned = existing?.isPlanned ?? true;

  await FormDialog.show(
    context,
    title: existing == null ? 'New expense' : 'Edit expense',
    builder: (ctx) => [
      TextField(
        controller: labelCtrl,
        decoration: const InputDecoration(
          labelText: 'Label',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      sizedBoxH,
      TextField(
        controller: amountCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Amount',
          prefixText: '\$ ',
          border: OutlineInputBorder(),
        ),
      ),
      sizedBoxH,
      DateField(
        label: 'Date',
        value: spentOn,
        onChanged: (v) => spentOn = v ?? DateTime.now(),
        allowClear: false,
      ),
      sizedBoxH,
      SwitchListTile(
        title: const Text('Planned (not yet spent)'),
        value: isPlanned,
        onChanged: (v) => isPlanned = v,
        contentPadding: EdgeInsets.zero,
      ),
      sizedBoxH,
      TextField(
        controller: categoryCtrl,
        decoration: const InputDecoration(
          labelText: 'Category (optional)',
          border: OutlineInputBorder(),
        ),
      ),
    ],
    onSave: () async {
      final label = labelCtrl.text.trim();
      if (label.isEmpty) return;
      final amount = double.tryParse(amountCtrl.text.trim());
      if (amount == null) return;
      final now = DateTime.now();
      final expense = existing == null
          ? Expense(
              id: newEntityId(),
              label: label,
              amount: amount,
              spentOn: spentOn,
              category: categoryCtrl.text.trim().isEmpty
                  ? null
                  : categoryCtrl.text.trim(),
              isPlanned: isPlanned,
              createdAt: now,
              updatedAt: now,
            )
          : existing.copyWith(
              label: label,
              amount: amount,
              spentOn: spentOn,
              category: categoryCtrl.text.trim().isEmpty
                  ? null
                  : categoryCtrl.text.trim(),
              isPlanned: isPlanned,
              updatedAt: now,
            );
      await repo.upsertExpense(expense);
      if (context.mounted) Navigator.of(context).pop(true);
      onChanged();
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Recurring expense editor

Future<void> showRecurringExpenseEditor(
  BuildContext context,
  EntityRepositories repo, {
  RecurringExpense? existing,
  required VoidCallback onChanged,
}) async {
  final labelCtrl = TextEditingController(text: existing?.label ?? '');
  final amountCtrl =
      TextEditingController(text: existing?.amount.toStringAsFixed(2) ?? '');
  final categoryCtrl = TextEditingController(text: existing?.category ?? '');
  String cadence = existing?.cadence ?? 'monthly';
  DateTime nextDue = existing?.nextDue ?? DateTime.now();
  bool isPaused = existing?.isPaused ?? false;

  await FormDialog.show(
    context,
    title: existing == null ? 'New recurring expense' : 'Edit recurring expense',
    builder: (ctx) => [
      TextField(
        controller: labelCtrl,
        decoration: const InputDecoration(
          labelText: 'Label (e.g. Netflix)',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      sizedBoxH,
      TextField(
        controller: amountCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Amount',
          prefixText: '\$ ',
          border: OutlineInputBorder(),
        ),
      ),
      sizedBoxH,
      DropdownButtonFormField<String>(
        initialValue: cadence,
        decoration: const InputDecoration(
          labelText: 'Cadence',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
          DropdownMenuItem(value: 'biweekly', child: Text('Every 2 weeks')),
          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
          DropdownMenuItem(value: 'quarterly', child: Text('Every 3 months')),
          DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
        ],
        onChanged: (v) => cadence = v ?? 'monthly',
      ),
      sizedBoxH,
      DateField(
        label: 'Next due',
        value: nextDue,
        onChanged: (v) => nextDue = v ?? DateTime.now(),
        allowClear: false,
      ),
      sizedBoxH,
      SwitchListTile(
        title: const Text('Paused'),
        value: isPaused,
        onChanged: (v) => isPaused = v,
        contentPadding: EdgeInsets.zero,
      ),
      sizedBoxH,
      TextField(
        controller: categoryCtrl,
        decoration: const InputDecoration(
          labelText: 'Category (optional)',
          border: OutlineInputBorder(),
        ),
      ),
    ],
    onSave: () async {
      final label = labelCtrl.text.trim();
      if (label.isEmpty) return;
      final amount = double.tryParse(amountCtrl.text.trim());
      if (amount == null) return;
      final now = DateTime.now();
      final r = existing == null
          ? RecurringExpense(
              id: newEntityId(),
              label: label,
              amount: amount,
              cadence: cadence,
              nextDue: nextDue,
              category: categoryCtrl.text.trim().isEmpty
                  ? null
                  : categoryCtrl.text.trim(),
              isPaused: isPaused,
              createdAt: now,
              updatedAt: now,
            )
          : existing.copyWith(
              label: label,
              amount: amount,
              cadence: cadence,
              nextDue: nextDue,
              category: categoryCtrl.text.trim().isEmpty
                  ? null
                  : categoryCtrl.text.trim(),
              isPaused: isPaused,
              updatedAt: now,
            );
      await repo.upsertRecurringExpense(r);
      if (context.mounted) Navigator.of(context).pop(true);
      onChanged();
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Reminder editor

Future<void> showReminderEditor(
  BuildContext context,
  EntityRepositories repo, {
  Reminder? existing,
  required VoidCallback onChanged,
}) async {
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final categoryCtrl = TextEditingController(text: existing?.category ?? '');
  DateTime remindAt = existing?.remindAt ?? DateTime.now();
  String? cadence = existing?.cadence;
  int priority = existing?.priority ?? 0;

  await FormDialog.show(
    context,
    title: existing == null ? 'New reminder' : 'Edit reminder',
    builder: (ctx) => [
      TextField(
        controller: titleCtrl,
        decoration: const InputDecoration(
          labelText: 'Title',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      sizedBoxH,
      DateTimeField(
        label: 'When',
        value: remindAt,
        onChanged: (v) => remindAt = v ?? DateTime.now(),
        allowClear: false,
      ),
      sizedBoxH,
      DropdownButtonFormField<String?>(
        initialValue: cadence,
        decoration: const InputDecoration(
          labelText: 'Repeat',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: null, child: Text('One-time')),
          DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
          DropdownMenuItem(value: 'daily', child: Text('Daily')),
          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
        ],
        onChanged: (v) => cadence = v,
      ),
      sizedBoxH,
      FormSection(title: 'Priority', children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Normal')),
            ButtonSegment(value: 1, label: Text('High')),
            ButtonSegment(value: 2, label: Text('Urgent')),
          ],
          selected: {priority},
          onSelectionChanged: (s) => priority = s.first,
        ),
      ]),
      sizedBoxH,
      TextField(
        controller: categoryCtrl,
        decoration: const InputDecoration(
          labelText: 'Category (optional)',
          border: OutlineInputBorder(),
        ),
      ),
    ],
    onSave: () async {
      final title = titleCtrl.text.trim();
      if (title.isEmpty) return;
      final now = DateTime.now();
      final r = existing == null
          ? Reminder(
              id: newEntityId(),
              title: title,
              remindAt: remindAt,
              cadence: cadence,
              priority: priority,
              category: categoryCtrl.text.trim().isEmpty
                  ? null
                  : categoryCtrl.text.trim(),
              createdAt: now,
              updatedAt: now,
            )
          : existing.copyWith(
              title: title,
              remindAt: remindAt,
              cadence: cadence,
              priority: priority,
              category: categoryCtrl.text.trim().isEmpty
                  ? null
                  : categoryCtrl.text.trim(),
              clearCadence: cadence == null && existing.cadence != null,
              updatedAt: now,
            );
      await repo.upsertReminder(r);
      if (context.mounted) Navigator.of(context).pop(true);
      onChanged();
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Bill editor

Future<void> showBillEditor(
  BuildContext context,
  EntityRepositories repo, {
  Bill? existing,
  required VoidCallback onChanged,
}) async {
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final amountCtrl =
      TextEditingController(text: existing?.amount.toStringAsFixed(2) ?? '');
  final categoryCtrl = TextEditingController(text: existing?.category ?? '');
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  DateTime dueOn = existing?.dueOn ?? DateTime.now();
  String? cadence = existing?.cadence;
  bool isPaid = existing?.isPaid ?? false;

  await FormDialog.show(
    context,
    title: existing == null ? 'New bill' : 'Edit bill',
    builder: (ctx) => [
      TextField(
        controller: titleCtrl,
        decoration: const InputDecoration(
          labelText: 'Title (e.g. Rent)',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      sizedBoxH,
      TextField(
        controller: amountCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Amount',
          prefixText: '\$ ',
          border: OutlineInputBorder(),
        ),
      ),
      sizedBoxH,
      DateField(
        label: 'Due',
        value: dueOn,
        onChanged: (v) => dueOn = v ?? DateTime.now(),
        allowClear: false,
      ),
      sizedBoxH,
      DropdownButtonFormField<String?>(
        initialValue: cadence,
        decoration: const InputDecoration(
          labelText: 'Repeat',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: null, child: Text('One-time')),
          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
          DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
          DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
        ],
        onChanged: (v) => cadence = v,
      ),
      sizedBoxH,
      SwitchListTile(
        title: const Text('Paid'),
        value: isPaid,
        onChanged: (v) => isPaid = v,
        contentPadding: EdgeInsets.zero,
      ),
      sizedBoxH,
      TextField(
        controller: categoryCtrl,
        decoration: const InputDecoration(
          labelText: 'Category (optional)',
          border: OutlineInputBorder(),
        ),
      ),
      sizedBoxH,
      TextField(
        controller: notesCtrl,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Notes (optional)',
          border: OutlineInputBorder(),
        ),
      ),
    ],
    onSave: () async {
      final title = titleCtrl.text.trim();
      if (title.isEmpty) return;
      final amount = double.tryParse(amountCtrl.text.trim());
      if (amount == null) return;
      final now = DateTime.now();
      final bill = existing == null
          ? Bill(
              id: newEntityId(),
              title: title,
              amount: amount,
              dueOn: dueOn,
              cadence: cadence,
              category: categoryCtrl.text.trim().isEmpty
                  ? null
                  : categoryCtrl.text.trim(),
              notes: notesCtrl.text.trim().isEmpty
                  ? null
                  : notesCtrl.text.trim(),
              isPaid: isPaid,
              createdAt: now,
              updatedAt: now,
            )
          : existing.copyWith(
              title: title,
              amount: amount,
              dueOn: dueOn,
              cadence: cadence,
              category: categoryCtrl.text.trim().isEmpty
                  ? null
                  : categoryCtrl.text.trim(),
              notes: notesCtrl.text.trim().isEmpty
                  ? null
                  : notesCtrl.text.trim(),
              isPaid: isPaid,
              clearCadence: cadence == null && existing.cadence != null,
              paidOn: isPaid ? (existing.paidOn ?? now) : null,
              clearPaidOn: !isPaid && existing.paidOn != null,
              updatedAt: now,
            );
      await repo.upsertBill(bill);
      if (context.mounted) Navigator.of(context).pop(true);
      onChanged();
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Custom list item editor

Future<void> showCustomListItemEditor(
  BuildContext context,
  EntityRepositories repo, {
  required CustomList list,
  CustomListItem? existing,
  required VoidCallback onChanged,
}) async {
  final labelCtrl = TextEditingController(text: existing?.label ?? '');

  await FormDialog.show(
    context,
    title: existing == null ? 'Add to ${list.title}' : 'Edit item',
    builder: (ctx) => [
      TextField(
        controller: labelCtrl,
        decoration: const InputDecoration(
          labelText: 'Item',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
    ],
    onSave: () async {
      final label = labelCtrl.text.trim();
      if (label.isEmpty) return;
      final now = DateTime.now();
      final item = existing == null
          ? CustomListItem(
              id: newEntityId(),
              listId: list.id,
              label: label,
              createdAt: now,
              updatedAt: now,
            )
          : existing.copyWith(label: label, updatedAt: now);
      await repo.upsertCustomListItem(item);
      if (context.mounted) Navigator.of(context).pop(true);
      onChanged();
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Custom list editor (just title + emoji)

Future<void> showCustomListEditor(
  BuildContext context,
  EntityRepositories repo, {
  CustomList? existing,
  required VoidCallback onChanged,
}) async {
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final emojiCtrl = TextEditingController(text: existing?.emoji ?? '');

  await FormDialog.show(
    context,
    title: existing == null ? 'New list' : 'Edit list',
    builder: (ctx) => [
      TextField(
        controller: titleCtrl,
        decoration: const InputDecoration(
          labelText: 'List title',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      sizedBoxH,
      TextField(
        controller: emojiCtrl,
        decoration: const InputDecoration(
          labelText: 'Emoji (optional)',
          hintText: '📋',
          border: OutlineInputBorder(),
        ),
      ),
    ],
    onSave: () async {
      final title = titleCtrl.text.trim();
      if (title.isEmpty) return;
      final now = DateTime.now();
      final list = existing == null
          ? CustomList(
              id: newEntityId(),
              title: title,
              emoji: emojiCtrl.text.trim().isEmpty
                  ? null
                  : emojiCtrl.text.trim(),
              createdAt: now,
              updatedAt: now,
            )
          : existing.copyWith(
              title: title,
              emoji: emojiCtrl.text.trim().isEmpty
                  ? null
                  : emojiCtrl.text.trim(),
              updatedAt: now,
            );
      await repo.upsertCustomList(list);
      if (context.mounted) Navigator.of(context).pop(true);
      onChanged();
    },
    );
    }
