import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Abstract database handle.
///
/// Phase 1: only chat_messages table exists. Phase 2+ will add other tables.
/// We define this as an interface so the chat controller can use a no-op
/// implementation while the real database is still opening (the provider
/// is async).
abstract class AppDatabase {
  Database get raw;

  Future<void> close();
}

/// Real SQLite-backed implementation.
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
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE chat_messages (
            id              TEXT PRIMARY KEY,
            role            TEXT NOT NULL,
            content         TEXT NOT NULL,
            context_snapshot TEXT,
            created_at      INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_chat_created_at ON chat_messages(created_at)',
        );
      },
    );
    _instance = SqliteAppDatabase._(db);
    return _instance!;
  }

  @override
  Future<void> close() async {
    await _db.close();
    _instance = null;
  }
}
