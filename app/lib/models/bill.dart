/// A bill — like recurring expense but tracked separately.
///
/// Bills have a "paid" status, an optional paid date, and a specific due
/// date. Recurring expenses are "subscriptions I track". Bills are
/// "invoices I need to pay".
class Bill {
  final String id;
  final String title;
  final double amount;
  final DateTime dueOn;
  final String? cadence; // null = one-off
  final bool isPaid;
  final DateTime? paidOn;
  final String? category;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Bill({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueOn,
    this.cadence,
    this.isPaid = false,
    this.paidOn,
    this.category,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Bill copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? dueOn,
    String? cadence,
    bool? isPaid,
    DateTime? paidOn,
    String? category,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearCadence = false,
    bool clearPaidOn = false,
  }) {
    return Bill(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      dueOn: dueOn ?? this.dueOn,
      cadence: clearCadence ? null : (cadence ?? this.cadence),
      isPaid: isPaid ?? this.isPaid,
      paidOn: clearPaidOn ? null : (paidOn ?? this.paidOn),
      category: category ?? this.category,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'title': title,
        'amount': amount,
        'due_on': dueOn.millisecondsSinceEpoch,
        'cadence': cadence,
        'is_paid': isPaid ? 1 : 0,
        'paid_on': paidOn?.millisecondsSinceEpoch,
        'category': category,
        'notes': notes,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Bill.fromRow(Map<String, Object?> row) {
    DateTime? fromMillis(Object? v) =>
        v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);
    return Bill(
      id: row['id'] as String,
      title: row['title'] as String,
      amount: (row['amount'] as num).toDouble(),
      dueOn: DateTime.fromMillisecondsSinceEpoch(row['due_on'] as int),
      cadence: row['cadence'] as String?,
      isPaid: (row['is_paid'] as int) == 1,
      paidOn: fromMillis(row['paid_on']),
      category: row['category'] as String?,
      notes: row['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }
}
