import 'package:flutter/material.dart';

/// Phase 0 calendar screen — empty placeholder.
///
/// The agenda view (sticky-day-header scrollable list of tasks/habits/
/// expenses/reminders) ships in Phase 4.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month_outlined,
                  size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Agenda view — Phase 4',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Will show tasks, habits, expenses, bills and reminders\n'
                'grouped by day.',
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
