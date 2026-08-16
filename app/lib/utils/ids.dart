/// Generates a short, stable, RFC4122-ish ID.
///
/// Used as the primary key for every entity. Not cryptographically random —
/// just enough uniqueness for our use.
String newEntityId() {
  final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rand = (identityHashCode(Object()) ^ DateTime.now().millisecondsSinceEpoch)
      .toRadixString(36)
      .replaceAll('-', '');
  return '$ts-$rand';
}
