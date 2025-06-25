//// {@template dmwmt.migration}
/// A change to the database that can be applied and rolled back.
///
/// A migration is implemented as a simple data class that uses [definedAt] as the primary key.
///
/// Migrations have to be serialized and deserialized preserving atleast [definedAt] and [down]
/// to be able to make [SyncMigrator] work.
/// {endtemplate}
class Migration<T> implements Comparable<Migration<T>> {
  /// Creates a new migration data class instance.
  ///
  /// Make sure that [definedAt] is unique for each migration and represents the time the code was edited.
  ///
  /// Throws an [ArgumentError] if [definedAt] is not in UTC.
  Migration({
    required DateTime definedAt,
    this.name,
    this.description,
    this.appliedAt,
    this.alwaysApply = false,
    required this.up,
    required this.down,
  }) : // Ensures that the DateTime is in UTC and also truncates the microseconds,
        // so that it's not a problem if microsecond precision is not supported by the database.
        definedAt = DateTime.fromMillisecondsSinceEpoch(
          (() {
            if (!definedAt.isUtc) {
              throw ArgumentError.value(definedAt, 'definedAt', 'must be in UTC');
            }
            return definedAt;
          })()
              .millisecondsSinceEpoch,
          isUtc: true,
        );

  /// Create a new [Migration] that undoes [migration]
  /// by flipping its [up] and [down] fields.
  Migration.undo({
    required DateTime definedAt,
    String? name,
    String? description,
    DateTime? appliedAt,
    bool alwaysApply = false,
    required Migration<T> migration,
  }) : this(
          definedAt: definedAt,
          name: name ?? (migration.name != null ? "Undo ${migration.name}" : null),
          description: description,
          appliedAt: appliedAt,
          alwaysApply: alwaysApply,
          up: migration.down,
          down: migration.up,
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
  ///
  /// Implementations of the algorithm or database wrappers are free to update this field
  /// on insertion to represent the time the migration was applied.
  final DateTime? appliedAt;

  /// Whether this migration should always be applied, even if it was already applied before.
  ///
  /// This might be useful for enabling per session PRAGMAs like `PRAGMA foreign_keys = ON;`
  /// in SQLite that need to be applied every time the database is opened,
  /// but also may be incompatible with some states of the database during the migration.
  final bool alwaysApply;

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
    return 'Migration{definedAt: $definedAt, name: $name, description: $description, alwaysApply: $alwaysApply, appliedAt: $appliedAt, up: $up, down: $down}';
  }

  /// A human-readable identifier for the migration. Used for debugging and logging.
  String get humanReadableId => name ?? definedAt.toString();

  /// Creates a copy of this migration with the given fields replaced with new values.
  Migration<T> copyWith({
    DateTime? definedAt,
    String? name,
    String? description,
    DateTime? appliedAt,
    bool? alwaysApply,
    T? up,
    T? down,
  }) {
    return Migration<T>(
      definedAt: definedAt ?? this.definedAt,
      name: name ?? this.name,
      description: description ?? this.description,
      appliedAt: appliedAt ?? this.appliedAt,
      alwaysApply: alwaysApply ?? this.alwaysApply,
      up: up ?? this.up,
      down: down ?? this.down,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Migration && runtimeType == other.runtimeType && definedAt.isAtSameMomentAs(other.definedAt);

  @override
  int get hashCode => definedAt.hashCode;

  @override
  int compareTo(Migration<T> other) {
    return definedAt.compareTo(other.definedAt);
  }

  /// Find out if this migration was defined before [other].
  bool operator <(Migration<T> other) {
    return definedAt.isBefore(other.definedAt);
  }

  /// Find out if this migration was defined after [other].
  bool operator >(Migration<T> other) {
    return definedAt.isAfter(other.definedAt);
  }

  /// Find out if this migration was defined before or at the same time as [other].
  bool operator <=(Migration<T> other) {
    return definedAt.isBefore(other.definedAt) || definedAt.isAtSameMomentAs(other.definedAt);
  }

  /// Find out if this migration was defined after or at the same time as [other].
  bool operator >=(Migration<T> other) {
    return definedAt.isAfter(other.definedAt) || definedAt.isAtSameMomentAs(other.definedAt);
  }
}
