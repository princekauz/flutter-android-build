import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ai_service.dart';

/// Singleton AI service. WebView hosting is the chat screen's responsibility —
/// this provider just manages the service lifecycle.
///
/// Phase 0 only — the database provider comes in Phase 2 when we need
/// persistence for tasks/habits/expenses.
final aiServiceProvider = Provider<QuillBotService>((ref) {
  final svc = QuillBotService();
  ref.onDispose(svc.dispose);
  return svc;
});
