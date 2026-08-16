import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/custom_list.dart';
import '../models/expense.dart';
import '../models/task.dart';
import '../providers/entity_lists_provider.dart';
import '../repositories/entity_repositories.dart';
import '../widgets/entity_editors.dart';

/// Phase 3 lists screen — categorized sub-tabs.
///
/// Eight tabs (per the brief):
///   Tasks · Habits · Expenses · Recurring · Reminders · Bills · Shopping · Custom
///
/// "Shopping" is a special view backed by a single CustomList titled
/// "Shopping" (auto-created on first access). "Custom" shows all other
/// custom lists.
///
/// Architecture: parent Scaffold owns AppBar, TabBar, FAB. Each tab's body
/// is just a widget (no inner Scaffold) to avoid layout interference.
class ListsScreen extends ConsumerStatefulWidget {
  const ListsScreen({super.key});

  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends ConsumerState<ListsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 8, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(entityListsProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lists'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Tasks'),
            Tab(text: 'Habits'),
            Tab(text: 'Expenses'),
            Tab(text: 'Recurring'),
            Tab(text: 'Reminders'),
            Tab(text: 'Bills'),
            Tab(text: 'Shopping'),
            Tab(text: 'Custom'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TasksTab(),
          _HabitsTab(),
          _ExpensesTab(),
          _RecurringTab(),
          _RemindersTab(),
          _BillsTab(),
          _ShoppingTab(),
          _CustomListsTab(),
        ],
      ),
      floatingActionButton: _AnimatedFab(
        tabController: _tabController,
        builder: (tabIndex) => _fabFor(tabIndex, context, notifier),
      ),
    );
  }

  Widget _fabFor(int tabIndex, BuildContext context, EntityLists notifier) {
    final repo = _repo(notifier);
    switch (tabIndex) {
      case 0:
        return FloatingActionButton.extended(
          heroTag: 'fab-tasks',
          onPressed: () async {
            await showTaskEditor(context, repo, onChanged: notifier.load);
          },
          icon: const Icon(Icons.add),
          label: const Text('Task'),
        );
      case 1:
        return FloatingActionButton.extended(
          heroTag: 'fab-habits',
          onPressed: () async {
            await showHabitEditor(context, repo, onChanged: notifier.load);
          },
          icon: const Icon(Icons.add),
          label: const Text('Habit'),
        );
      case 2:
        return FloatingActionButton.extended(
          heroTag: 'fab-expenses',
          onPressed: () async {
            await showExpenseEditor(context, repo, onChanged: notifier.load);
          },
          icon: const Icon(Icons.add),
          label: const Text('Expense'),
        );
      case 3:
        return FloatingActionButton.extended(
          heroTag: 'fab-recurring',
          onPressed: () async {
            await showRecurringExpenseEditor(context, repo,
                onChanged: notifier.load);
          },
          icon: const Icon(Icons.add),
          label: const Text('Recurring'),
        );
      case 4:
        return FloatingActionButton.extended(
          heroTag: 'fab-reminders',
          onPressed: () async {
            await showReminderEditor(context, repo, onChanged: notifier.load);
          },
          icon: const Icon(Icons.add),
          label: const Text('Reminder'),
        );
      case 5:
        return FloatingActionButton.extended(
          heroTag: 'fab-bills',
          onPressed: () async {
            await showBillEditor(context, repo, onChanged: notifier.load);
          },
          icon: const Icon(Icons.add),
          label: const Text('Bill'),
        );
      case 6:
        // Shopping — handled inline in the tab (different FAB label).
        return const SizedBox.shrink();
      case 7:
        return FloatingActionButton.extended(
          heroTag: 'fab-custom',
          onPressed: () async {
            await showCustomListEditor(context, repo, onChanged: notifier.load);
          },
          icon: const Icon(Icons.add),
          label: const Text('List'),
        );
    }
    return const SizedBox.shrink();
  }
}

/// Re-renders the FAB whenever the tab changes (so the label/icon swap).
class _AnimatedFab extends StatefulWidget {
  const _AnimatedFab({required this.tabController, required this.builder});
  final TabController tabController;
  final Widget Function(int tabIndex) builder;

  @override
  State<_AnimatedFab> createState() => _AnimatedFabState();
}

class _AnimatedFabState extends State<_AnimatedFab> {
  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(_onTabChange);
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChange);
    super.dispose();
  }

  void _onTabChange() {
    if (widget.tabController.indexIsChanging) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(widget.tabController.index);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Helpers

EntityRepositories _repo(EntityLists notifier) => notifier.repo;

String _newListId() {
  final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return 'list-$ts';
}

Future<bool> _confirmDelete(BuildContext context, String kind) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete $kind?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ─────────────────────────────────────────────────────────────────────────
// Tasks

class _TasksTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(entityListsProvider.notifier);
    final tasks = ref.watch(entityListsProvider).tasks;
    if (tasks.isEmpty) {
      return _EmptyState(
        msg: 'No tasks yet.\nAsk the AI or tap + to create one.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: tasks.length,
      itemBuilder: (ctx, i) {
        final t = tasks[i];
        return Dismissible(
          key: ValueKey('task-${t.id}'),
          direction: DismissDirection.endToStart,
          background: _deleteBackground(),
          confirmDismiss: (_) => _confirmDelete(context, 'task'),
          onDismissed: (_) => notifier.deleteTask(t.id),
          child: ListTile(
            leading: Checkbox(
              value: t.isComplete,
              onChanged: (_) async {
                await notifier.upsertTask(
                    t.copyWith(isComplete: !t.isComplete));
              },
            ),
            title: Text(
              t.title,
              style: TextStyle(
                decoration: t.isComplete ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: _taskSubtitle(t),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showTaskEditor(
                context,
                _repo(notifier),
                existing: t,
                onChanged: notifier.load,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget? _taskSubtitle(Task t) {
    final parts = <String>[];
    if (t.dueDate != null) parts.add(DateFormat('MMM d').format(t.dueDate!));
    if (t.dueTime != null) parts.add(DateFormat('HH:mm').format(t.dueTime!));
    if (t.category != null) parts.add(t.category!);
    if (parts.isEmpty) return null;
    return Text(parts.join(' · '));
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Habits

class _HabitsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(entityListsProvider.notifier);
    final habits = ref.watch(entityListsProvider).habits;
    if (habits.isEmpty) {
      return _EmptyState(
        msg: 'No habits yet.\nAsk the AI or tap + to create one.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: habits.length,
      itemBuilder: (ctx, i) {
        final h = habits[i];
        return Dismissible(
          key: ValueKey('habit-${h.id}'),
          direction: DismissDirection.endToStart,
          background: _deleteBackground(),
          confirmDismiss: (_) => _confirmDelete(context, 'habit'),
          onDismissed: (_) => notifier.deleteHabit(h.id),
          child: ListTile(
            leading: Icon(h.isPaused ? Icons.pause_circle : Icons.repeat),
            title: Text(h.title),
            subtitle: Text(_describeRecurrence(h.recurrence)),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showHabitEditor(
                context,
                _repo(notifier),
                existing: h,
                onChanged: notifier.load,
              ),
            ),
          ),
        );
      },
    );
  }

  String _describeRecurrence(Map<String, dynamic> r) {
    final type = r['type'];
    switch (type) {
      case 'daily':
        return 'Every day';
      case 'weekdays':
        return 'Weekdays';
      case 'weekends':
        return 'Weekends';
      case 'weekdays_custom':
        final days = (r['days'] as List?)?.cast<int>() ?? [];
        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days.map((d) => names[d - 1]).join(', ');
      case 'interval_days':
        return 'Every ${r['days']} days';
      default:
        return r.toString();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Expenses (grouped by date with daily totals)

class _ExpensesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(entityListsProvider.notifier);
    final expenses = ref.watch(entityListsProvider).expenses;
    if (expenses.isEmpty) {
      return _EmptyState(
        msg: 'No expenses yet.\nAsk the AI or tap + to add one.',
      );
    }
    final grouped = <DateTime, List<Expense>>{};
    for (final e in expenses) {
      final key = DateTime(e.spentOn.year, e.spentOn.month, e.spentOn.day);
      grouped.putIfAbsent(key, () => []).add(e);
    }
    final sortedKeys = grouped.keys.toList()..sort();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: sortedKeys.length,
      itemBuilder: (ctx, i) {
        final day = sortedKeys[i];
        final items = grouped[day]!;
        final total = items.fold<double>(0, (sum, e) => sum + e.amount);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('EEE, MMM d').format(day),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: scheme.primary),
                  ),
                ],
              ),
            ),
            ...items.map((e) => Dismissible(
                  key: ValueKey('expense-${e.id}'),
                  direction: DismissDirection.endToStart,
                  background: _deleteBackground(),
                  confirmDismiss: (_) => _confirmDelete(context, 'expense'),
                  onDismissed: (_) => notifier.deleteExpense(e.id),
                  child: ListTile(
                    leading: const Icon(Icons.attach_money),
                    title: Text(e.label),
                    subtitle: Text(e.category == null
                        ? (e.isPlanned ? 'Planned' : 'Spent')
                        : '${e.isPlanned ? "Planned" : "Spent"} · ${e.category}'),
                    trailing: Text(
                      '\$${e.amount.toStringAsFixed(2)}',
                      style: theme.textTheme.bodyLarge,
                    ),
                    onTap: () => showExpenseEditor(
                      context,
                      _repo(notifier),
                      existing: e,
                      onChanged: notifier.load,
                    ),
                  ),
                )),
            const Divider(height: 1),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Recurring expenses

class _RecurringTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(entityListsProvider.notifier);
    final items = ref.watch(entityListsProvider).recurringExpenses;
    if (items.isEmpty) {
      return _EmptyState(
        msg: 'No recurring expenses yet.\nAsk the AI or tap + to add one.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final r = items[i];
        return Dismissible(
          key: ValueKey('recurring-${r.id}'),
          direction: DismissDirection.endToStart,
          background: _deleteBackground(),
          confirmDismiss: (_) => _confirmDelete(context, 'recurring expense'),
          onDismissed: (_) => notifier.deleteRecurring(r.id),
          child: ListTile(
            leading: Icon(r.isPaused ? Icons.pause : Icons.autorenew),
            title: Text(r.label),
            subtitle: Text(
              '\$${r.amount.toStringAsFixed(2)} · ${r.cadence} · next ${DateFormat('MMM d').format(r.nextDue)}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showRecurringExpenseEditor(
                context,
                _repo(notifier),
                existing: r,
                onChanged: notifier.load,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Reminders

class _RemindersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(entityListsProvider.notifier);
    final items = ref.watch(entityListsProvider).reminders;
    if (items.isEmpty) {
      return _EmptyState(
        msg: 'No reminders yet.\nAsk the AI or tap + to add one.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final r = items[i];
        return Dismissible(
          key: ValueKey('reminder-${r.id}'),
          direction: DismissDirection.endToStart,
          background: _deleteBackground(),
          confirmDismiss: (_) => _confirmDelete(context, 'reminder'),
          onDismissed: (_) => notifier.deleteReminder(r.id),
          child: ListTile(
            leading: Icon(
              r.isDone ? Icons.check_circle : Icons.alarm,
              color: r.isDone ? Colors.green : null,
            ),
            title: Text(
              r.title,
              style: TextStyle(
                decoration: r.isDone ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text(
              DateFormat('MMM d · HH:mm').format(r.remindAt) +
                  (r.cadence == null ? '' : ' · ${r.cadence}'),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showReminderEditor(
                context,
                _repo(notifier),
                existing: r,
                onChanged: notifier.load,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Bills

class _BillsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(entityListsProvider.notifier);
    final items = ref.watch(entityListsProvider).bills;
    if (items.isEmpty) {
      return _EmptyState(
        msg: 'No bills yet.\nAsk the AI or tap + to add one.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final b = items[i];
        return Dismissible(
          key: ValueKey('bill-${b.id}'),
          direction: DismissDirection.endToStart,
          background: _deleteBackground(),
          confirmDismiss: (_) => _confirmDelete(context, 'bill'),
          onDismissed: (_) => notifier.deleteBill(b.id),
          child: ListTile(
            leading: Checkbox(
              value: b.isPaid,
              onChanged: (_) async {
                await notifier.upsertBill(b.copyWith(
                  isPaid: !b.isPaid,
                  paidOn: !b.isPaid ? DateTime.now() : null,
                  clearPaidOn: b.isPaid,
                ));
              },
            ),
            title: Text(
              b.title,
              style: TextStyle(
                decoration: b.isPaid ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text(
              '\$${b.amount.toStringAsFixed(2)} · due ${DateFormat('MMM d').format(b.dueOn)}'
              '${b.cadence != null ? " · ${b.cadence}" : ""}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showBillEditor(
                context,
                _repo(notifier),
                existing: b,
                onChanged: notifier.load,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shopping — single CustomList titled "Shopping"

class _ShoppingTab extends ConsumerWidget {
  static const _title = 'Shopping';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(entityListsProvider.notifier);
    final lists = ref.watch(entityListsProvider).customLists;
    final shopping =
        lists.where((l) => l.title.toLowerCase() == 'shopping').firstOrNull;

    if (shopping == null) {
      // Auto-create on first visit.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final now = DateTime.now();
        await notifier.upsertList(CustomList(
          id: _newListId(),
          title: _title,
          emoji: '🛒',
          createdAt: now,
          updatedAt: now,
        ));
      });
      return _EmptyState(
        msg: 'Setting up your shopping list…',
      );
    }

    return _CustomListItemsView(list: shopping, notifier: notifier);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Custom lists

class _CustomListsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(entityListsProvider.notifier);
    final lists = ref.watch(entityListsProvider).customLists;
    if (lists.isEmpty) {
      return _EmptyState(
        msg: 'No custom lists yet.\nAsk the AI or tap + to create one.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: lists.length,
      itemBuilder: (ctx, i) {
        final l = lists[i];
        return Dismissible(
          key: ValueKey('list-${l.id}'),
          direction: DismissDirection.endToStart,
          background: _deleteBackground(),
          confirmDismiss: (_) => _confirmDelete(context, 'list'),
          onDismissed: (_) => notifier.deleteList(l.id),
          child: ListTile(
            leading: Text(l.emoji ?? '📋', style: const TextStyle(fontSize: 24)),
            title: Text(l.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      _CustomListDetailScreen(list: l, notifier: notifier),
                ),
              );
            },
            onLongPress: () => showCustomListEditor(
              context,
              _repo(notifier),
              existing: l,
              onChanged: notifier.load,
            ),
          ),
        );
      },
    );
  }
}

class _CustomListDetailScreen extends StatelessWidget {
  const _CustomListDetailScreen({required this.list, required this.notifier});
  final CustomList list;
  final EntityLists notifier;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${list.emoji ?? ''} ${list.title}'.trim()),
        actions: [
          IconButton(
            tooltip: 'Edit list',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showCustomListEditor(
              context,
              _repo(notifier),
              existing: list,
              onChanged: notifier.load,
            ),
          ),
        ],
      ),
      body: _CustomListItemsView(list: list, notifier: notifier),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-list-detail',
        onPressed: () => showCustomListItemEditor(
          context,
          _repo(notifier),
          list: list,
          onChanged: notifier.load,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Item'),
      ),
    );
  }
}

class _CustomListItemsView extends ConsumerStatefulWidget {
  const _CustomListItemsView({required this.list, required this.notifier});

  final CustomList list;
  final EntityLists notifier;

  @override
  ConsumerState<_CustomListItemsView> createState() =>
      _CustomListItemsViewState();
}

class _CustomListItemsViewState extends ConsumerState<_CustomListItemsView> {
  late Future<List<CustomListItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.notifier.itemsFor(widget.list.id);
  }

  @override
  void didUpdateWidget(_CustomListItemsView old) {
    super.didUpdateWidget(old);
    if (old.list.id != widget.list.id) {
      _future = widget.notifier.itemsFor(widget.list.id);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.notifier.itemsFor(widget.list.id);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<CustomListItem>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? <CustomListItem>[];
          if (items.isEmpty) {
            return ListView(
              children: [
                SizedBox(
                  height: 300,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No items yet.\nTap + to add one.',
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
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final item = items[i];
              return Dismissible(
                key: ValueKey('item-${item.id}'),
                direction: DismissDirection.endToStart,
                background: _deleteBackground(),
                confirmDismiss: (_) => _confirmDelete(context, 'item'),
                onDismissed: (_) async {
                  await widget.notifier.deleteItem(item.id);
                  if (mounted) _refresh();
                },
                child: GestureDetector(
                  onLongPress: () => showCustomListItemEditor(
                    context,
                    widget.notifier.repo,
                    list: widget.list,
                    existing: item,
                    onChanged: _refresh,
                  ),
                  child: CheckboxListTile(
                    value: item.isDone,
                    onChanged: (_) async {
                      await widget.notifier.upsertItem(
                          item.copyWith(isDone: !item.isDone));
                      if (mounted) _refresh();
                    },
                    title: Text(
                      item.label,
                      style: TextStyle(
                        decoration:
                            item.isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shared

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.msg});
  final String msg;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _deleteBackground() => Container(
      color: Colors.red,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 16),
      child: const Icon(Icons.delete, color: Colors.white),
    );
