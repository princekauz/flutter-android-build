import 'package:flutter/material.dart';

/// Phase 0 lists screen — empty placeholder.
///
/// The categorized lists (Tasks, Habits, Expenses, Recurring Expenses,
/// Bills, Shopping, Custom) ship in Phase 3.
class ListsScreen extends StatelessWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Lists')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.checklist_outlined,
                  size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Lists — Phase 3',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Tasks, Habits, Expenses, Recurring, Bills,\n'
                'Shopping, and your Custom Lists will live here.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
