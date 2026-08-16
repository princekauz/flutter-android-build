import 'dart:convert';

/// A recurring habit the user wants to maintain.
///
/// The `recurrence` field is a small JSON blob describing the schedule:
///   {"type": "daily"}
///   {"type": "weekdays", "days": [1,3,5]}         // Mon, Wed, Fri
///   {"type": "weekly", "days": [1]}
///   {"type": "monthly", "day": 1, "occurrence": "first"|"last"|"every"}
///   {"type": "yearly", "month": 1, "day": 1}
///   {"type": "interval_days", "days": 3}          // every 3 days
///
/// Phase 2: store and read. Recurrence expansion (computing "is this habit
/// due on date X?") ships in Phase 6.
class Habit {
  final String id;
  final String title;
  final Map<String, dynamic> recurrence;
  final bool isPaused;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Habit({
    required this.id,
    required this.title,
    required this.recurrence,
    this.isPaused = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Habit copyWith({
    String? id,
    String? title,
    Map<String, dynamic>? recurrence,
    bool? isPaused,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      recurrence: recurrence ?? this.recurrence,
      isPaused: isPaused ?? this.isPaused,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'title': title,
        'recurrence': jsonEncode(recurrence),
        'is_paused': isPaused ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Habit.fromRow(Map<String, Object?> row) {
    final raw = row['recurrence'] as String;
    Map<String, dynamic> recurrence;
    try {
      recurrence = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      recurrence = {'raw': raw};
    }
    return Habit(
      id: row['id'] as String,
      title: row['title'] as String,
      recurrence: recurrence,
      isPaused: (row['is_paused'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }
}
