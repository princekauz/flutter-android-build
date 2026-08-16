import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/chat_repository.dart';
import '../services/ai_service.dart';
import '../storage/app_database.dart';

/// Singleton database. Async — opened lazily on first access.
///
/// Phase 1: only chat_messages table exists. Phase 2+ will add other tables.
final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final db = await SqliteAppDatabase.instance();
  ref.onDispose(() async {
    await db.close();
  });
  return db;
});

/// Chat repository. Depends on the database provider.
final chatRepositoryProvider = FutureProvider<ChatRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return ChatRepository(db);
});

/// Singleton AI service. WebView hosting is the chat screen's responsibility.
final aiServiceProvider = Provider<QuillBotService>((ref) {
  final svc = QuillBotService();
  ref.onDispose(svc.dispose);
  return svc;
});
