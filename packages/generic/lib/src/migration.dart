class Migration<T> implements Comparable<Migration<T>> {
  Migration({
    required DateTime definedAt,
    this.name,
    this.description,
    this.appliedAt,
    required this.up,
    required this.down,
  }) : // Ensures that the DateTime is in UTC and also truncates the microseconds,
       // so that it's not a problem if microsecond precision is not supported by the database.
       definedAt = DateTime.fromMillisecondsSinceEpoch(
         definedAt.toUtc().millisecondsSinceEpoch,
         isUtc: true,
       );

  /// The identity of the migration.
  ///
  /// It's a UTC timestamp of when this migration was defined in code.
  /// This should be updated whenever [up] or [down] are changed.
  ///
  /// This is the primary key of the migration when stored in a database.
  final DateTime definedAt;

  /// The name of the migration. Only used for documentation purposes.
  final String? name;

  /// A description of what the migration does. Only used for documentation purposes.
  final String? description;

  /// The timestamp of when this migration was applied to the database. Kept around to make debugging easier (for you).
  ///
  /// Leave this as `null` when defining a new migration in code.
  final DateTime? appliedAt;

  /// The migration to apply to the database.
  ///
  /// This could be a SQL string or a description of added and removed columns.
  ///
  /// It should be able to be stored inside of the database.
  ///
  /// It's kept as a generic type since different databases might support storing different types of data.
  final T up;

  /// The migration to undo the changes made by [up].
  final T down;

  @override
  String toString() {
    return 'Migration{definedAt: $definedAt, name: $name, decription: $description, appliedAt: $appliedAt, up: $up, down: $down}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Migration &&
          runtimeType == other.runtimeType &&
          definedAt.isAtSameMomentAs(other.definedAt);

  @override
  int get hashCode => definedAt.hashCode;
  
  @override
  int compareTo(Migration<T> other) {
    return definedAt.compareTo(other.definedAt);
  }

  operator <(Migration<T> other) {
    return definedAt.isBefore(other.definedAt);
  }

  operator >(Migration<T> other) {
    return definedAt.isAfter(other.definedAt);
  }
}
