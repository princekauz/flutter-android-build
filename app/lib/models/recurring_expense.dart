/// A recurring expense — Netflix subscription, monthly rent, etc.
///
/// Stored separately from one-off expenses so we can track cadence and
/// "next due" date for queries like "what subscriptions do I have?"
class RecurringExpense {
  final String id;
  final String label;
  final double amount;
  final String cadence; // human-readable: 'monthly', 'weekly', 'yearly', etc.
  final DateTime nextDue;
  final String? category;
  final String? notes;
  final bool isPaused;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringExpense({
    required this.id,
    required this.label,
    required this.amount,
    required this.cadence,
    required this.nextDue,
    this.category,
    this.notes,
    this.isPaused = false,
    required this.createdAt,
    required this.updatedAt,
  });

  RecurringExpense copyWith({
    String? id,
    String? label,
    double? amount,
    String? cadence,
    DateTime? nextDue,
    String? category,
    String? notes,
    bool? isPaused,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringExpense(
      id: id ?? this.id,
      label: label ?? this.label,
      amount: amount ?? this.amount,
      cadence: cadence ?? this.cadence,
      nextDue: nextDue ?? this.nextDue,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      isPaused: isPaused ?? this.isPaused,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'label': label,
        'amount': amount,
        'cadence': cadence,
        'next_due': nextDue.millisecondsSinceEpoch,
        'category': category,
        'notes': notes,
        'is_paused': isPaused ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory RecurringExpense.fromRow(Map<String, Object?> row) {
    return RecurringExpense(
      id: row['id'] as String,
      label: row['label'] as String,
      amount: (row['amount'] as num).toDouble(),
      cadence: row['cadence'] as String,
      nextDue: DateTime.fromMillisecondsSinceEpoch(row['next_due'] as int),
      category: row['category'] as String?,
      notes: row['notes'] as String?,
      isPaused: (row['is_paused'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }
}
