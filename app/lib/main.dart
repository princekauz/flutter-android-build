import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/app_shell.dart';
import 'utils/theme.dart';

void main() {
  runApp(const ProviderScope(child: AiAssistantApp()));
}

class AiAssistantApp extends StatelessWidget {
  const AiAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}
