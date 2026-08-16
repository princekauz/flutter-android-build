/// A time-based reminder.
///
/// Phase 2: store and read. Notification firing (the OS actually
/// displaying it) ships in Phase 7.
class Reminder {
  final String id;
  final String title;
  final DateTime remindAt;
  final String? cadence; // null = one-shot
  final int priority; // 0 = normal, 1 = high, 2 = urgent
  final String? category;
  final bool isDone;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Reminder({
    required this.id,
    required this.title,
    required this.remindAt,
    this.cadence,
    this.priority = 0,
    this.category,
    this.isDone = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Reminder copyWith({
    String? id,
    String? title,
    DateTime? remindAt,
    String? cadence,
    int? priority,
    String? category,
    bool? isDone,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearCadence = false,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      remindAt: remindAt ?? this.remindAt,
      cadence: clearCadence ? null : (cadence ?? this.cadence),
      priority: priority ?? this.priority,
      category: category ?? this.category,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'title': title,
        'remind_at': remindAt.millisecondsSinceEpoch,
        'cadence': cadence,
        'priority': priority,
        'category': category,
        'is_done': isDone ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Reminder.fromRow(Map<String, Object?> row) {
    return Reminder(
      id: row['id'] as String,
      title: row['title'] as String,
      remindAt: DateTime.fromMillisecondsSinceEpoch(row['remind_at'] as int),
      cadence: row['cadence'] as String?,
      priority: row['priority'] as int,
      category: row['category'] as String?,
      isDone: (row['is_done'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }
}
