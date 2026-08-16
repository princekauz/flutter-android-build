/// A user-created list (Shopping List, Reading List, etc.) with items.
class CustomList {
  final String id;
  final String title;
  final String? emoji; // optional visual marker
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomList({
    required this.id,
    required this.title,
    this.emoji,
    required this.createdAt,
    required this.updatedAt,
  });

  CustomList copyWith({
   String? id,
   String? title,
   String? emoji,
   DateTime? createdAt,
   DateTime? updatedAt,
   bool clearEmoji = false,
 }) {
    return CustomList(
      id: id ?? this.id,
      title: title ?? this.title,
      emoji: clearEmoji ? null : (emoji ?? this.emoji),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'title': title,
        'emoji': emoji,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory CustomList.fromRow(Map<String, Object?> row) {
    return CustomList(
      id: row['id'] as String,
      title: row['title'] as String,
      emoji: row['emoji'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }
}

/// One item inside a CustomList.
class CustomListItem {
  final String id;
  final String listId;
  final String label;
  final bool isDone;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomListItem({
    required this.id,
    required this.listId,
    required this.label,
    this.isDone = false,
    this.position = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  CustomListItem copyWith({
    String? id,
    String? listId,
    String? label,
    bool? isDone,
    int? position,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomListItem(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      label: label ?? this.label,
      isDone: isDone ?? this.isDone,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'list_id': listId,
        'label': label,
        'is_done': isDone ? 1 : 0,
        'position': position,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory CustomListItem.fromRow(Map<String, Object?> row) {
    return CustomListItem(
      id: row['id'] as String,
      listId: row['list_id'] as String,
      label: row['label'] as String,
      isDone: (row['is_done'] as int) == 1,
      position: row['position'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }
}
