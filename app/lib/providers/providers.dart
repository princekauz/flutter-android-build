import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commands/command_executor.dart';
import '../repositories/chat_repository.dart';
import '../repositories/entity_repositories.dart';
import '../services/ai_service.dart';
import '../storage/app_database.dart';

/// Singleton database. Async — opened lazily on first access.
///
/// Schema versions:
///   v1: chat_messages
///   v2: + tasks, habits, expenses, recurring_expenses, reminders, bills,
///        custom_lists, custom_list_items
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

/// Aggregated entity repositories (tasks, habits, expenses, etc.).
final entityRepositoriesProvider =
    FutureProvider<EntityRepositories>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return EntityRepositories(db);
});

/// Command executor (depends on entity repositories).
final commandExecutorProvider =
    FutureProvider<CommandExecutor>((ref) async {
  final repo = await ref.watch(entityRepositoriesProvider.future);
  return CommandExecutor(repo);
});

/// Singleton AI service. WebView hosting is the chat screen's responsibility.
final aiServiceProvider = Provider<QuillBotService>((ref) {
  final svc = QuillBotService();
  ref.onDispose(svc.dispose);
  return svc;
});
