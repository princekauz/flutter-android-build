import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../models/bill.dart';
import '../models/custom_list.dart';
import '../models/expense.dart';
import '../models/habit.dart';
import '../models/recurring_expense.dart';
import '../models/reminder.dart';
import '../models/task.dart';
import '../repositories/entity_repositories.dart';
import '../storage/app_database.dart';
import 'providers.dart';

/// Callback the chat controller calls after running a batch of commands,
/// so the in-memory entity cache stays in sync with the database.
///
/// The ListsScreen watches `entityListsProvider`, which feeds from this
/// notifier. Calling `refresher()` forces a re-fetch and rebuilds.
typedef EntityListsRefresher = Future<void> Function();

/// In-memory snapshots of all entity lists.
///
/// The repository still owns the SQL. This notifier just caches the latest
/// read so UI rebuilds don't hit SQLite every time. After any mutation
/// (chat command OR UI edit), call `bumpVersion()` to force a re-fetch.
class EntityLists extends StateNotifier<EntityListsState> {
  EntityLists(this._repo) : super(const EntityListsState.empty());

  final EntityRepositories _repo;

  Future<void> load() async {
    final next = EntityListsState(
      tasks: await _repo.listTasks(),
      habits: await _repo.listHabits(),
      expenses: await _repo.listExpenses(),
      recurringExpenses: await _repo.listRecurringExpenses(),
      reminders: await _repo.listReminders(),
      bills: await _repo.listBills(),
      customLists: await _repo.listCustomLists(),
    );
    state = next;
  }

  /// Increment version + reload. Call after any external mutation.
  Future<void> bumpVersion() async => load();

  // ─────────────────────────────────────────────────────────────────────
  // Targeted refreshes (after chat commands execute)

  Future<void> refreshTasks() async {
    state = EntityListsState(
      tasks: await _repo.listTasks(),
      habits: state.habits,
      expenses: state.expenses,
      recurringExpenses: state.recurringExpenses,
      reminders: state.reminders,
      bills: state.bills,
      customLists: state.customLists,
    );
  }

  Future<void> refreshHabits() async {
    state = EntityListsState(
      tasks: state.tasks,
      habits: await _repo.listHabits(),
      expenses: state.expenses,
      recurringExpenses: state.recurringExpenses,
      reminders: state.reminders,
      bills: state.bills,
      customLists: state.customLists,
    );
  }

  Future<void> refreshExpenses() async {
    state = EntityListsState(
      tasks: state.tasks,
      habits: state.habits,
      expenses: await _repo.listExpenses(),
      recurringExpenses: state.recurringExpenses,
      reminders: state.reminders,
      bills: state.bills,
      customLists: state.customLists,
    );
  }

  Future<void> refreshRecurring() async {
    state = EntityListsState(
      tasks: state.tasks,
      habits: state.habits,
      expenses: state.expenses,
      recurringExpenses: await _repo.listRecurringExpenses(),
      reminders: state.reminders,
      bills: state.bills,
      customLists: state.customLists,
    );
  }

  Future<void> refreshReminders() async {
    state = EntityListsState(
      tasks: state.tasks,
      habits: state.habits,
      expenses: state.expenses,
      recurringExpenses: state.recurringExpenses,
      reminders: await _repo.listReminders(),
      bills: state.bills,
      customLists: state.customLists,
    );
  }

  Future<void> refreshBills() async {
    state = EntityListsState(
      tasks: state.tasks,
      habits: state.habits,
      expenses: state.expenses,
      recurringExpenses: state.recurringExpenses,
      reminders: state.reminders,
      bills: await _repo.listBills(),
      customLists: state.customLists,
    );
  }

  Future<void> refreshCustomLists() async {
    state = EntityListsState(
      tasks: state.tasks,
      habits: state.habits,
      expenses: state.expenses,
      recurringExpenses: state.recurringExpenses,
      reminders: state.reminders,
      bills: state.bills,
      customLists: await _repo.listCustomLists(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Mutations (proxy through the notifier so the cache stays fresh)

  Future<void> upsertTask(Task t) async {
    await _repo.upsertTask(t);
    await refreshTasks();
  }

  Future<void> deleteTask(String id) async {
    await _repo.deleteTask(id);
    await refreshTasks();
  }

  Future<void> upsertHabit(Habit h) async {
    await _repo.upsertHabit(h);
    await refreshHabits();
  }

  Future<void> deleteHabit(String id) async {
    await _repo.deleteHabit(id);
    await refreshHabits();
  }

  Future<void> upsertExpense(Expense e) async {
    await _repo.upsertExpense(e);
    await refreshExpenses();
  }

  Future<void> deleteExpense(String id) async {
    await _repo.deleteExpense(id);
    await refreshExpenses();
  }

  Future<void> upsertRecurring(RecurringExpense r) async {
    await _repo.upsertRecurringExpense(r);
    await refreshRecurring();
  }

  Future<void> deleteRecurring(String id) async {
    await _repo.deleteRecurringExpense(id);
    await refreshRecurring();
  }

  Future<void> upsertReminder(Reminder r) async {
    await _repo.upsertReminder(r);
    await refreshReminders();
  }

  Future<void> deleteReminder(String id) async {
    await _repo.deleteReminder(id);
    await refreshReminders();
  }

  Future<void> upsertBill(Bill b) async {
    await _repo.upsertBill(b);
    await refreshBills();
  }

  Future<void> deleteBill(String id) async {
    await _repo.deleteBill(id);
    await refreshBills();
  }

  Future<void> upsertList(CustomList l) async {
    await _repo.upsertCustomList(l);
    await refreshCustomLists();
  }

  Future<void> deleteList(String id) async {
    await _repo.deleteCustomList(id);
    await refreshCustomLists();
  }

  Future<void> upsertItem(CustomListItem item) async {
    await _repo.upsertCustomListItem(item);
  }

  Future<void> deleteItem(String id) async {
    await _repo.deleteCustomListItem(id);
  }

  Future<List<CustomListItem>> itemsFor(String listId) =>
      _repo.listItemsForList(listId);

  /// The underlying repository. Screens should use this to pass to
  /// entity editors (which call upsert/delete on the repo directly).
  EntityRepositories get repo => _repo;
}

class EntityListsState {
  final List<Task> tasks;
  final List<Habit> habits;
  final List<Expense> expenses;
  final List<RecurringExpense> recurringExpenses;
  final List<Reminder> reminders;
  final List<Bill> bills;
  final List<CustomList> customLists;

  const EntityListsState({
    this.tasks = const [],
    this.habits = const [],
    this.expenses = const [],
    this.recurringExpenses = const [],
    this.reminders = const [],
    this.bills = const [],
    this.customLists = const [],
  });

  const EntityListsState.empty() : this();

  int get total =>
      tasks.length +
      habits.length +
      expenses.length +
      recurringExpenses.length +
      reminders.length +
      bills.length +
      customLists.length;
}

/// Provider for the in-memory entity cache.
///
/// Waits for the repository to open, then loads on first access. While the
/// DB is still opening, returns an empty notifier that will load the real
/// data once the repository resolves.
final entityListsProvider =
    StateNotifierProvider<EntityLists, EntityListsState>((ref) {
  // Sync access — but the provider only resolves when DB is ready.
  // We use `ref.watch` then `.valueOrNull` to avoid blocking if not ready.
  final repoAsync = ref.watch(entityRepositoriesProvider);
  final repo = repoAsync.valueOrNull;
  if (repo == null) {
    // Return an empty notifier with a no-op repo. The screens gate reads
    // behind the database banner; once the DB opens, the provider will
    // re-evaluate and return a real notifier.
    return EntityLists(_NoopEntityRepo());
  }
  final notifier = EntityLists(repo);
  notifier.load();
  return notifier;
});

/// No-op repository — every method does nothing. Used as a placeholder
/// while the real DB is still opening. We can't construct EntityLists with
/// null, so this gives a safe stub that produces empty results.
class _NoopEntityRepo extends EntityRepositories {
  _NoopEntityRepo() : super(_NoopDb());
  @override
  Future<List<Task>> listTasks() async => const [];
  @override
  Future<List<Habit>> listHabits() async => const [];
  @override
  Future<List<Expense>> listExpenses() async => const [];
  @override
  Future<List<RecurringExpense>> listRecurringExpenses() async => const [];
  @override
  Future<List<Reminder>> listReminders() async => const [];
  @override
  Future<List<Bill>> listBills() async => const [];
  @override
  Future<List<CustomList>> listCustomLists() async => const [];
}

class _NoopDb implements AppDatabase {
  @override
  Database get raw => throw StateError('Noop DB should never be called');

  @override
  Future<void> close() async => throw StateError('Noop DB should never be called');
}
