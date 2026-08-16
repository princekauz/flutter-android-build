/// A planned or past expense.
///
/// "Tomorrow's fuel" and "Tuesday's lunch" are each a single Expense row.
/// Updates to the same conceptual expense mutate the row's amount/label.
/// Deletes remove the row entirely.
class Expense {
  final String id;
  final String label;
  final double amount;
  final DateTime spentOn; // date the expense belongs to
  final String? category;
  final String? notes;
  final bool isPlanned; // false = already spent; true = upcoming
  final DateTime createdAt;
  final DateTime updatedAt;

  const Expense({
    required this.id,
    required this.label,
    required this.amount,
    required this.spentOn,
    this.category,
    this.notes,
    this.isPlanned = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Expense copyWith({
    String? id,
    String? label,
    double? amount,
    DateTime? spentOn,
    String? category,
    String? notes,
    bool? isPlanned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      label: label ?? this.label,
      amount: amount ?? this.amount,
      spentOn: spentOn ?? this.spentOn,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      isPlanned: isPlanned ?? this.isPlanned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'label': label,
        'amount': amount,
        'spent_on': spentOn.millisecondsSinceEpoch,
        'category': category,
        'notes': notes,
        'is_planned': isPlanned ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Expense.fromRow(Map<String, Object?> row) {
    return Expense(
      id: row['id'] as String,
      label: row['label'] as String,
      amount: (row['amount'] as num).toDouble(),
      spentOn: DateTime.fromMillisecondsSinceEpoch(row['spent_on'] as int),
      category: row['category'] as String?,
      notes: row['notes'] as String?,
      isPlanned: (row['is_planned'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }
}
