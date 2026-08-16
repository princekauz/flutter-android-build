import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/bill.dart';
import '../models/recurring_expense.dart';
import '../models/reminder.dart';
import '../models/task.dart';
import '../models/timeline_entry.dart';
import '../providers/entity_lists_provider.dart';
import '../repositories/entity_repositories.dart';
import '../utils/agenda.dart';
import '../widgets/entity_editors.dart';

/// Calendar screen — agenda view.
///
/// All schedulable entities (tasks with due dates, reminders, bills,
/// recurring expenses) flattened into a single time-ordered list,
/// grouped under sticky day headers.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showJumpToTodayFab = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scrollController.hasClients &&
        _scrollController.offset > 400;
    if (show != _showJumpToTodayFab) {
      setState(() => _showJumpToTodayFab = show);
    }
  }

  void _jumpToToday() {
    if (!_scrollController.hasClients) return;
    // Scroll back to top — that's where "today" sits.
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(entityListsProvider);
    final notifier = ref.watch(entityListsProvider.notifier);
    final entries = buildAgenda(
      tasks: lists.tasks,
      reminders: lists.reminders,
      bills: lists.bills,
      recurringExpenses: lists.recurringExpenses,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      body: entries.isEmpty
          ? const _EmptyAgenda()
          : _AgendaList(
              entries: entries,
              repo: _repo(notifier),
              scrollController: _scrollController,
            ),
      floatingActionButton: _showJumpToTodayFab
          ? FloatingActionButton.small(
              heroTag: 'fab-jump-today',
              onPressed: _jumpToToday,
              tooltip: 'Jump to today',
              child: const Icon(Icons.today),
            )
          : null,
    );
  }
}

EntityRepositories _repo(EntityLists notifier) => notifier.repo;

// ─────────────────────────────────────────────────────────────────────────
// Agenda list

class _AgendaList extends StatelessWidget {
  const _AgendaList({
    required this.entries,
    required this.repo,
    required this.scrollController,
  });

  final List<TimelineEntry> entries;
  final EntityRepositories repo;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final rows = groupAgendaByDay(entries);
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: rows.length,
      itemBuilder: (ctx, i) {
        final row = rows[i];
        if (row.kind == AgendaRowKind.header) {
          return _DayHeader(day: row.day!);
        }
        return _AgendaRowTile(entry: row.entry!, repo: repo);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Day header

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = _sameDay(day, today);
    final isPast = day.isBefore(DateTime(today.year, today.month, today.day));
    final theme = Theme.of(context);
    final color = isToday
        ? theme.colorScheme.primary
        : (isPast ? theme.colorScheme.outline : theme.colorScheme.onSurface);

    final label = isToday
        ? 'Today'
        : (isPast
            ? DateFormat('EEE, MMM d').format(day)
            : DateFormat('EEE, MMM d').format(day));

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (isPast) ...[
            const SizedBox(width: 8),
            Text(
              'past',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Entry tile

class _AgendaRowTile extends StatelessWidget {
  const _AgendaRowTile({required this.entry, required this.repo});
  final TimelineEntry entry;
  final EntityRepositories repo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, color) = _styleFor(entry, scheme);
    final timeStr = entry.time == null
        ? ''
        : DateFormat('HH:mm').format(DateTime(0, 1, 1, entry.time!.hour, entry.time!.minute));
    final subtitleParts = <String>[
      if (timeStr.isNotEmpty) timeStr,
      if (entry.subtitle != null && entry.subtitle!.isNotEmpty) entry.subtitle!,
    ];
    final subtitle = subtitleParts.isEmpty ? null : subtitleParts.join(' · ');

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        entry.title,
        style: TextStyle(
          decoration: entry.isDone ? TextDecoration.lineThrough : null,
          fontWeight: entry.priority >= 2 ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: entry.isDone
          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
          : null,
      onTap: () => _openEditor(context),
    );
  }

  (IconData, Color) _styleFor(TimelineEntry e, ColorScheme scheme) {
    if (e.isDone) return (Icons.check, Colors.green);
    switch (e.kind) {
      case TimelineKind.task:
        if (e.priority == 2) return (Icons.priority_high, scheme.error);
        if (e.priority == 1) return (Icons.task_alt, scheme.primary);
        return (Icons.task_outlined, scheme.primary);
      case TimelineKind.reminder:
        return (Icons.alarm, scheme.tertiary);
      case TimelineKind.bill:
        return (Icons.receipt_long, scheme.error);
      case TimelineKind.recurring:
        return (Icons.autorenew, scheme.secondary);
    }
  }

  void _openEditor(BuildContext context) {
    switch (entry.kind) {
      case TimelineKind.task:
        showTaskEditor(context, repo, existing: entry.source as Task, onChanged: () {});
        break;
      case TimelineKind.reminder:
        showReminderEditor(context, repo, existing: entry.source as Reminder, onChanged: () {});
        break;
      case TimelineKind.bill:
        showBillEditor(context, repo, existing: entry.source as Bill, onChanged: () {});
        break;
      case TimelineKind.recurring:
        showRecurringExpenseEditor(context, repo,
            existing: entry.source as RecurringExpense, onChanged: () {});
        break;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Empty state

class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Nothing scheduled.\nAdd a task, reminder, or bill with a date.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
