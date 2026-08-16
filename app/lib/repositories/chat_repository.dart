import 'package:sqflite/sqflite.dart';

import '../models/chat_message.dart';
import '../storage/app_database.dart';

/// Persistence layer for chat messages.
///
/// Phase 1 only persists the conversation. Future phases will add read/write
/// methods for tasks, habits, expenses, etc. — each entity type gets its
/// own repository.
class ChatRepository {
  ChatRepository(this._db);

  final AppDatabase _db;

  /// Load all messages in chronological order (oldest first).
  Future<List<ChatMessage>> loadAll() async {
    final rows = await _db.raw.query(
      'chat_messages',
      orderBy: 'created_at ASC',
    );
    return rows.map(ChatMessage.fromRow).toList(growable: false);
  }

  /// Stream of all messages. Re-emits whenever the table changes.
  ///
  /// Phase 1: emits once with the current state. Phase 2 can swap in a
  /// reactive stream from sqflite's `query` updates API.
  Stream<List<ChatMessage>> watchAll() async* {
    yield await loadAll();
  }

  Future<void> insert(ChatMessage msg) async {
    await _db.raw.insert(
      'chat_messages',
      msg.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAll() async {
    await _db.raw.delete('chat_messages');
  }
}
