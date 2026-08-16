import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/bill.dart';
import '../models/custom_list.dart';
import '../models/expense.dart';
import '../models/habit.dart';
import '../models/recurring_expense.dart';
import '../models/reminder.dart';
import '../models/task.dart';
import '../providers/providers.dart';
import '../repositories/entity_repositories.dart';

/// Phase 2 debug list view.
///
/// Shows all stored entities so you can verify the AI command protocol
/// actually mutated the database. Each section has a count + a list.
/// Tapping an item shows full detail; long-press deletes (Phase 2 debug
/// helper — real UI comes in Phase 3).
class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitiesAsync = ref.watch(entityRepositoriesProvider);

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lists (debug)'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Tasks'),
              Tab(text: 'Habits'),
              Tab(text: 'Expenses'),
              Tab(text: 'Recurring'),
              Tab(text: 'Reminders'),
              Tab(text: 'Bills'),
              Tab(text: 'Custom'),
            ],
          ),
        ),
        body: entitiesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (repo) => TabBarView(
            children: [
              _taskList(context, ref, repo),
              _habitList(context, ref, repo),
              _expenseList(context, ref, repo),
              _recurringList(context, ref, repo),
              _reminderList(context, ref, repo),
              _billList(context, ref, repo),
              _customList(context, ref, repo),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Section builders

  Widget _taskList(BuildContext context, WidgetRef ref, EntityRepositories repo) {
    return _AsyncList<Task>(
      fetcher: repo.listTasks,
      emptyMsg: 'No tasks yet.\nAsk the AI: "Add task: call mom Sunday"',
      itemBuilder: (t) => ListTile(
        leading: Icon(
          t.isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
          color: t.isComplete ? Colors.green : null,
        ),
        title: Text(t.title),
        subtitle: Text(_summarizeTask(t)),
        onLongPress: () => _confirmDelete(context, ref, 'task', t.id, () async {
          await repo.deleteTask(t.id);
        }),
      ),
    );
  }

  Widget _habitList(BuildContext context, WidgetRef ref, EntityRepositories repo) {
    return _AsyncList<Habit>(
      fetcher: repo.listHabits,
      emptyMsg:
          'No habits yet.\nAsk the AI: "I want to go to the gym every day"',
      itemBuilder: (h) => ListTile(
        leading: Icon(h.isPaused ? Icons.pause_circle : Icons.repeat),
        title: Text(h.title),
        subtitle: Text('Recurrence: ${h.recurrence}'),
        onLongPress: () => _confirmDelete(context, ref, 'habit', h.id, () async {
          await repo.deleteHabit(h.id);
        }),
      ),
    );
  }

  Widget _expenseList(BuildContext context, WidgetRef ref, EntityRepositories repo) {
    return _AsyncList<Expense>(
      fetcher: repo.listExpenses,
      emptyMsg:
          'No expenses yet.\nAsk the AI: "I\'ll spend \$40 on fuel tomorrow"',
      itemBuilder: (e) => ListTile(
        leading: const Icon(Icons.attach_money),
        title: Text(e.label),
        subtitle: Text(
          '\$${e.amount.toStringAsFixed(2)} on ${DateFormat('MMM d').format(e.spentOn)}'
          '${e.isPlanned ? " (planned)" : ""}',
        ),
        onLongPress: () => _confirmDelete(
            context, ref, 'expense', e.id, () async {
          await repo.deleteExpense(e.id);
        }),
      ),
    );
  }

  Widget _recurringList(BuildContext context, WidgetRef ref, EntityRepositories repo) {
    return _AsyncList<RecurringExpense>(
      fetcher: repo.listRecurringExpenses,
      emptyMsg:
          'No recurring expenses yet.\nAsk the AI: "I pay Netflix \$15 monthly"',
      itemBuilder: (r) => ListTile(
        leading: const Icon(Icons.autorenew),
        title: Text(r.label),
        subtitle: Text(
          '\$${r.amount.toStringAsFixed(2)} ${r.cadence}, next ${DateFormat('MMM d').format(r.nextDue)}',
        ),
        onLongPress: () => _confirmDelete(
            context, ref, 'recurring expense', r.id, () async {
          await repo.deleteRecurringExpense(r.id);
        }),
      ),
    );
  }

  Widget _reminderList(BuildContext context, WidgetRef ref, EntityRepositories repo) {
    return _AsyncList<Reminder>(
      fetcher: repo.listReminders,
      emptyMsg:
          'No reminders yet.\nAsk the AI: "Remind me to drink water every hour"',
      itemBuilder: (r) => ListTile(
        leading: const Icon(Icons.alarm),
        title: Text(r.title),
        subtitle: Text('At ${DateFormat('MMM d, HH:mm').format(r.remindAt)}'),
        onLongPress: () => _confirmDelete(
            context, ref, 'reminder', r.id, () async {
          await repo.deleteReminder(r.id);
        }),
      ),
    );
  }

  Widget _billList(BuildContext context, WidgetRef ref, EntityRepositories repo) {
    return _AsyncList<Bill>(
      fetcher: repo.listBills,
      emptyMsg: 'No bills yet.\nAsk the AI: "I need to pay rent next Friday"',
      itemBuilder: (b) => ListTile(
        leading: Icon(
          b.isPaid ? Icons.check_circle : Icons.receipt_long,
          color: b.isPaid ? Colors.green : null,
        ),
        title: Text(b.title),
        subtitle: Text(
          '\$${b.amount.toStringAsFixed(2)} due ${DateFormat('MMM d').format(b.dueOn)}',
        ),
        onLongPress: () => _confirmDelete(context, ref, 'bill', b.id, () async {
          await repo.deleteBill(b.id);
        }),
      ),
    );
  }

  Widget _customList(BuildContext context, WidgetRef ref, EntityRepositories repo) {
    return _AsyncList<CustomList>(
      fetcher: repo.listCustomLists,
      emptyMsg:
          'No custom lists yet.\nAsk the AI: "Create a shopping list called groceries"',
      itemBuilder: (l) => ListTile(
        leading: Text(l.emoji ?? '📋', style: const TextStyle(fontSize: 24)),
        title: Text(l.title),
        onLongPress: () => _confirmDelete(
            context, ref, 'list', l.id, () async {
          await repo.deleteCustomList(l.id);
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Helpers

  String _summarizeTask(Task t) {
    final parts = <String>[];
    if (t.dueDate != null) {
      parts.add('Due ${DateFormat('MMM d').format(t.dueDate!)}');
    }
    if (t.dueTime != null) {
      parts.add(DateFormat('HH:mm').format(t.dueTime!));
    }
    if (t.priority > 0) {
      parts.add('priority ${t.priority}');
    }
    return parts.join(' · ');
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String kind,
      String id, Future<void> Function() deleteFn) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $kind?'),
        content: const Text('This is a debug helper. Real UI in Phase 3.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () async {
              await deleteFn();
              if (ctx.mounted) Navigator.pop(ctx);
              // Trigger a rebuild
              ref.invalidate(entityRepositoriesProvider);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Generic Future-loading list with empty state + pull-to-refresh.
class _AsyncList<T> extends StatefulWidget {
  const _AsyncList({
    required this.fetcher,
    required this.emptyMsg,
    required this.itemBuilder,
  });

  final Future<List<T>> Function() fetcher;
  final String emptyMsg;
  final Widget Function(T) itemBuilder;

  @override
  State<_AsyncList<T>> createState() => _AsyncListState<T>();
}

class _AsyncListState<T> extends State<_AsyncList<T>> {
  late Future<List<T>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.fetcher();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.fetcher();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<T>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final items = snap.data ?? <T>[];
          if (items.isEmpty) {
            return ListView(
              children: [
                SizedBox(
                  height: 300,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        widget.emptyMsg,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (ctx, i) => widget.itemBuilder(items[i]),
          );
        },
      ),
    );
  }
}
