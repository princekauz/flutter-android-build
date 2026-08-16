/// A single task the user wants to track.
///
/// Stored in the `tasks` table. Soft-deletable (we keep the row but mark
/// deleted in the future); for now hard delete via SQL is fine.
class Task {
  final String id;
  final String title;
  final String? notes;
  final DateTime? dueDate; // date only — midnight local
  final DateTime?
      dueTime; // full timestamp with time-of-day (if user specified)
  final bool isComplete;
  final int priority; // 0 = normal, 1 = high, 2 = urgent
  final String? category;
  final String? recurrence; // null = one-off, else RRULE-ish string
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.title,
    this.notes,
    this.dueDate,
    this.dueTime,
    this.isComplete = false,
    this.priority = 0,
    this.category,
    this.recurrence,
    required this.createdAt,
    required this.updatedAt,
  });

  Task copyWith({
    String? id,
    String? title,
    String? notes,
    DateTime? dueDate,
    DateTime? dueTime,
    bool? isComplete,
    int? priority,
    String? category,
    String? recurrence,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearDueDate = false,
    bool clearDueTime = false,
    bool clearRecurrence = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      dueTime: clearDueTime ? null : (dueTime ?? this.dueTime),
      isComplete: isComplete ?? this.isComplete,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'title': title,
        'notes': notes,
        'due_date': dueDate?.millisecondsSinceEpoch,
        'due_time': dueTime?.millisecondsSinceEpoch,
        'is_complete': isComplete ? 1 : 0,
        'priority': priority,
        'category': category,
        'recurrence': recurrence,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Task.fromRow(Map<String, Object?> row) {
    DateTime? fromMillis(Object? v) =>
        v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);
    return Task(
      id: row['id'] as String,
      title: row['title'] as String,
      notes: row['notes'] as String?,
      dueDate: fromMillis(row['due_date']),
      dueTime: fromMillis(row['due_time']),
      isComplete: (row['is_complete'] as int) == 1,
      priority: row['priority'] as int,
      category: row['category'] as String?,
      recurrence: row['recurrence'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }
}
