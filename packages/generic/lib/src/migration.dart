import 'dart:async';

import 'package:meta/meta.dart';

/// An error that is thrown trying to access [Migration.up] or [Migration.down]
/// when the migration is not [Migration.hasInstructions].
class UninitializedMigrationError extends StateError {
  /// Creates an error that is thrown when a migration is not yet initialized.
  UninitializedMigrationError(this.migration)
      : super("${migration.humanReadableId} is not initialized. Call initialize() before accessing up or down.");

  /// The migration that was not initialized.
  final Migration<dynamic, dynamic> migration;
}

/// An error that is thrown when trying to initialize a migration that is already initialized.
class AlreadyInitializedMigrationError extends StateError {
  /// Creates an error that is thrown when trying to initialize a migration that is already initialized.
  AlreadyInitializedMigrationError(this.migration)
      : super("${migration.humanReadableId} is already initialized."
            " Call initialize() only once, or check if the migration is already initialized using the 'initialized' property.");

  /// The migration that was already initialized.
  final Migration<dynamic, dynamic> migration;
}

/// {@template dmwmt.migration}
/// A change to the database that can be applied and rolled back.
///
/// A migration is implemented as a simple data class that uses [definedAt] as the primary key.
///
/// Migrations have to be serialized and deserialized preserving atleast [definedAt] and [down]
/// to be able to make [SyncMigrator] work.
/// 
/// [D] is the type of the database that the migration is applied to.
/// [S] is the type of the migration instructions (for example, a SQL string).
/// {@endtemplate}
sealed class Migration<D, S> implements Comparable<Migration<D, S>> {
  /// {@template dmwmt.migration.anon}
  /// Creates a new migration data class instance.
  ///
  /// Make sure that [definedAt] is unique for each migration and represents the time the code was edited.
  ///
  /// Throws an [ArgumentError] if [definedAt] is not in UTC.
  /// {@endtemplate}
  Migration({
    required DateTime definedAt,
    this.name,
    this.description,
    this.appliedAt,
    this.alwaysApply = false,
    required S up,
    required S down,
  })  : // Ensures that the DateTime is in UTC and also truncates the microseconds,
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
        ),
        _down = down,
        _up = up,
        _hasInstructions = true,
        _instructionBuilder = null;

  /// {@template dmwmt.migration.deferred}
  /// Creates a new migration data class instance that is not yet initialized.
  ///
  /// This is useful when the action that the migration performs
  /// depends on the database state at the moment the migration is applied.
  ///
  /// For example it can be shorter when altering a SQLite table,
  /// to query the current SQL layout via sqlite_master and then
  /// manipulate the SQL string, than to copy paste the entire
  /// creation including all already made alterations again.
  ///
  /// When using this constructor, you must call [builder] before accessing [up] or [down].
  ///
  /// When [builder] is called, both [up] and [down] will be set.
  /// This means effectively that a migration can be deferred
  /// in the app code, but when it is stored in the database,
  /// so that it can be rolled back, it will have been initialized.
  /// {@endtemplate}
  Migration.deferred({
    required DateTime definedAt,
    this.name,
    this.description,
    this.appliedAt,
    this.alwaysApply = false,
    required FutureOr<({S up, S down})> Function(D db) builder,
  })  : // Ensures that the DateTime is in UTC and also truncates the microseconds,
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
        ),
        _instructionBuilder = builder,
        _hasInstructions = false;

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

  bool _hasInstructions;

  /// Whether this migration has been [buildInstructions]d.
  ///
  /// When `true`, [up] and [down] are guaranteed to be set
  /// and can be accessed without throwing an [UninitializedMigrationError].
  ///
  /// This is `false` when the migration was created with [Migration.deferred].
  ///
  /// Before calling [buildInstructions] check [hasInstructions],
  /// so that you don't accidentally call it twice.
  bool get hasInstructions => _hasInstructions;

  final FutureOr<({S up, S down})> Function(D db)? _instructionBuilder;

  /// Initializes the migration by rendering the [up] and [down] migration
  /// instructions.
  ///
  /// Throws [AlreadyInitializedMigrationError] if this migration was already initialized.
  ///
  /// To prevent this error, check [hasInstructions] before calling this method.
  @mustBeOverridden
  @mustCallSuper
  FutureOr<void> buildInstructions(D db) {
    if (_hasInstructions) throw AlreadyInitializedMigrationError(this);
    if (_instructionBuilder == null) {
      throw StateError(
          'Migration renderer is not set. Use Migration.deferred constructor to create a deferred migration.');
    }
  }

  /// The migration to apply to the database.
  ///
  /// This could be a SQL string or a description of added and removed columns.
  ///
  /// It should be able to be stored inside of the database.
  ///
  /// It's kept as a generic type since different databases might support storing different types of data.
  S get up => _hasInstructions ? _up : throw UninitializedMigrationError(this);
  late final S _up;

  /// The migration to undo the changes made by [up].
  S get down => _hasInstructions ? _down : throw UninitializedMigrationError(this);
  late final S _down;

  @override
  String toString() {
    return 'Migration{definedAt: $definedAt, name: $name, description: $description, alwaysApply: $alwaysApply, appliedAt: $appliedAt, up: $up, down: $down}';
  }

  /// A human-readable identifier for the migration. Used for debugging and logging.
  String get humanReadableId => name ?? definedAt.toString();

  /// Creates a copy of this migration with the given fields replaced with new values.
  Migration<D, S> copyWith({
    DateTime? definedAt,
    String? name,
    String? description,
    DateTime? appliedAt,
    bool? alwaysApply,
    S? up,
    S? down,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Migration && runtimeType == other.runtimeType && definedAt.isAtSameMomentAs(other.definedAt);

  @override
  int get hashCode => definedAt.hashCode;

  @override
  int compareTo(Migration<D, S> other) {
    return definedAt.compareTo(other.definedAt);
  }

  /// Find out if this migration was defined before [other].
  bool operator <(Migration<D, S> other) {
    return definedAt.isBefore(other.definedAt);
  }

  /// Find out if this migration was defined after [other].
  bool operator >(Migration<D, S> other) {
    return definedAt.isAfter(other.definedAt);
  }

  /// Find out if this migration was defined before or at the same time as [other].
  bool operator <=(Migration<D, S> other) {
    return definedAt.isBefore(other.definedAt) || definedAt.isAtSameMomentAs(other.definedAt);
  }

  /// Find out if this migration was defined after or at the same time as [other].
  bool operator >=(Migration<D, S> other) {
    return definedAt.isAfter(other.definedAt) || definedAt.isAtSameMomentAs(other.definedAt);
  }
}

/// {@macro dmwt.migration}
class SyncMigration<Db, Serial> extends Migration<Db, Serial> {
  /// {@macro dmwt.migration.anon}
  SyncMigration({
    required super.definedAt,
    super.name,
    super.description,
    super.appliedAt,
    super.alwaysApply,
    required super.up,
    required super.down,
  });

  /// {@macro dmwt.migration.deferred}
  SyncMigration.deferred({
    required super.definedAt,
    super.name,
    super.description,
    super.appliedAt,
    super.alwaysApply,
    required ({Serial up, Serial down}) Function(Db db) builder,
  }) : super.deferred(builder: builder);

  @override
  SyncMigration<Db, Serial> copyWith({
    DateTime? definedAt,
    String? name,
    String? description,
    DateTime? appliedAt,
    bool? alwaysApply,
    Serial? up,
    Serial? down,
  }) {
    return SyncMigration<Db, Serial>(
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
  void buildInstructions(Db db) {
    super.buildInstructions(db);
    final result = _instructionBuilder!(db) as ({Serial up, Serial down});
    _up = result.up;
    _down = result.down;
    _hasInstructions = true;
  }
}

/// {@macro dmwt.migration}
class AsyncMigration<Db, Serial> extends Migration<Db, Serial> {
  /// {@macro dmwt.migration.anon}
  AsyncMigration({
    required super.definedAt,
    super.name,
    super.description,
    super.appliedAt,
    super.alwaysApply,
    required super.up,
    required super.down,
  });

  /// {@macro dmwt.migration.deferred}
  AsyncMigration.deferred({
    required super.definedAt,
    super.name,
    super.description,
    super.appliedAt,
    super.alwaysApply,
    required super.builder,
  }) : super.deferred();

  @override
  FutureOr<void> buildInstructions(Db db) async {
    super.buildInstructions(db);
    final result = await _instructionBuilder!(db);
    _up = result.up;
    _down = result.down;
    _hasInstructions = true;
    return Future.value();
  }

  @override
  AsyncMigration<Db, Serial> copyWith({
    DateTime? definedAt,
    String? name,
    String? description,
    DateTime? appliedAt,
    bool? alwaysApply,
    Serial? up,
    Serial? down,
  }) {
    return AsyncMigration<Db, Serial>(
      definedAt: definedAt ?? this.definedAt,
      name: name ?? this.name,
      description: description ?? this.description,
      appliedAt: appliedAt ?? this.appliedAt,
      alwaysApply: alwaysApply ?? this.alwaysApply,
      up: up ?? this.up,
      down: down ?? this.down,
    );
  }
}
