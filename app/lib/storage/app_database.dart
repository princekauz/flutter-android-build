import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Abstract database handle.
///
/// The repository layer talks to this interface so we can swap in a no-op
/// during startup or tests without touching real SQLite.
abstract class AppDatabase {
  Database get raw;

  Future<void> close();
}

/// Real SQLite-backed implementation.
///
/// Schema versions:
///   v1: chat_messages
///   v2: + tasks, habits, expenses, recurring_expenses, reminders, bills,
///        custom_lists, custom_list_items
class SqliteAppDatabase implements AppDatabase {
  SqliteAppDatabase._(this._db);

  final Database _db;

  @override
  Database get raw => _db;

  static AppDatabase? _instance;

  /// Get (or open) the singleton database.
  static Future<AppDatabase> instance() async {
    if (_instance != null) return _instance!;
    final docs = await getApplicationDocumentsDirectory();
    final path = p.join(docs.path, 'ai_assistant.sqlite');
    final db = await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    _instance = SqliteAppDatabase._(db);
    return _instance!;
  }

  @override
  Future<void> close() async {
    await _db.close();
    _instance = null;
  }

  // ─────────────────────────────────────────────────────────────────────
  // Schema setup

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    _createV1(batch);
    _createV2(batch);
    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    final batch = db.batch();
    if (oldVersion < 2) {
      _createV2(batch);
    }
    await batch.commit(noResult: true);
  }

  static void _createV1(Batch b) {
    b.execute('''
      CREATE TABLE chat_messages (
        id              TEXT PRIMARY KEY,
        role            TEXT NOT NULL,
        content         TEXT NOT NULL,
        context_snapshot TEXT,
        created_at      INTEGER NOT NULL
      )
    ''');
    b.execute('CREATE INDEX idx_chat_created_at ON chat_messages(created_at)');
  }

  static void _createV2(Batch b) {
    // tasks
    b.execute('''
      CREATE TABLE tasks (
        id          TEXT PRIMARY KEY,
        title       TEXT NOT NULL,
        notes       TEXT,
        due_date    INTEGER,
        due_time    INTEGER,
        is_complete INTEGER NOT NULL DEFAULT 0,
        priority    INTEGER NOT NULL DEFAULT 0,
        category    TEXT,
        recurrence  TEXT,
        created_at  INTEGER NOT NULL,
        updated_at  INTEGER NOT NULL
      )
    ''');
    b.execute('CREATE INDEX idx_tasks_due ON tasks(due_date)');

    // habits
    b.execute('''
      CREATE TABLE habits (
        id          TEXT PRIMARY KEY,
        title       TEXT NOT NULL,
        recurrence  TEXT NOT NULL,
        is_paused   INTEGER NOT NULL DEFAULT 0,
        created_at  INTEGER NOT NULL,
        updated_at  INTEGER NOT NULL
      )
    ''');

    // habit completions — one row per (habit, date)
    b.execute('''
      CREATE TABLE habit_completions (
        habit_id    TEXT NOT NULL,
        completed_on INTEGER NOT NULL,
        PRIMARY KEY (habit_id, completed_on),
        FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE
      )
    ''');
    b.execute(
        'CREATE INDEX idx_habit_completions_habit ON habit_completions(habit_id)');

    // expenses — one row per (date, label) bucket. "Tomorrow's fuel" lives
    // as a single row; updates mutate the same row.
    b.execute('''
      CREATE TABLE expenses (
        id          TEXT PRIMARY KEY,
        label       TEXT NOT NULL,
        amount      REAL NOT NULL,
        spent_on    INTEGER NOT NULL,
        category    TEXT,
        notes       TEXT,
        is_planned  INTEGER NOT NULL DEFAULT 1,
        created_at  INTEGER NOT NULL,
        updated_at  INTEGER NOT NULL
      )
    ''');
    b.execute('CREATE INDEX idx_expenses_spent_on ON expenses(spent_on)');

    // recurring expenses (subscriptions, bills that recur)
    b.execute('''
      CREATE TABLE recurring_expenses (
        id          TEXT PRIMARY KEY,
        label       TEXT NOT NULL,
        amount      REAL NOT NULL,
        cadence     TEXT NOT NULL,
        next_due    INTEGER NOT NULL,
        category    TEXT,
        notes       TEXT,
        is_paused   INTEGER NOT NULL DEFAULT 0,
        created_at  INTEGER NOT NULL,
        updated_at  INTEGER NOT NULL
      )
    ''');
    b.execute('CREATE INDEX idx_recurring_next_due ON recurring_expenses(next_due)');

    // reminders — time-based notifications
    b.execute('''
      CREATE TABLE reminders (
        id          TEXT PRIMARY KEY,
        title       TEXT NOT NULL,
        remind_at   INTEGER NOT NULL,
        cadence     TEXT,
        priority    INTEGER NOT NULL DEFAULT 0,
        category    TEXT,
        is_done     INTEGER NOT NULL DEFAULT 0,
        created_at  INTEGER NOT NULL,
        updated_at  INTEGER NOT NULL
      )
    ''');
    b.execute('CREATE INDEX idx_reminders_at ON reminders(remind_at)');

    // bills — like recurring expenses but tracked separately (status, paid date)
    b.execute('''
      CREATE TABLE bills (
        id          TEXT PRIMARY KEY,
        title       TEXT NOT NULL,
        amount      REAL NOT NULL,
        due_on      INTEGER NOT NULL,
        cadence     TEXT,
        is_paid     INTEGER NOT NULL DEFAULT 0,
        paid_on     INTEGER,
        category    TEXT,
        notes       TEXT,
        created_at  INTEGER NOT NULL,
        updated_at  INTEGER NOT NULL
      )
    ''');
    b.execute('CREATE INDEX idx_bills_due ON bills(due_on)');

    // custom lists (Shopping Lists, etc.) + items
    b.execute('''
      CREATE TABLE custom_lists (
        id          TEXT PRIMARY KEY,
        title       TEXT NOT NULL,
        emoji       TEXT,
        created_at  INTEGER NOT NULL,
        updated_at  INTEGER NOT NULL
      )
    ''');
    b.execute('''
      CREATE TABLE custom_list_items (
        id          TEXT PRIMARY KEY,
        list_id     TEXT NOT NULL,
        label       TEXT NOT NULL,
        is_done     INTEGER NOT NULL DEFAULT 0,
        position    INTEGER NOT NULL DEFAULT 0,
        created_at  INTEGER NOT NULL,
        updated_at  INTEGER NOT NULL,
        FOREIGN KEY (list_id) REFERENCES custom_lists(id) ON DELETE CASCADE
      )
    ''');
    b.execute(
        'CREATE INDEX idx_custom_list_items_list ON custom_list_items(list_id)');
  }
}
