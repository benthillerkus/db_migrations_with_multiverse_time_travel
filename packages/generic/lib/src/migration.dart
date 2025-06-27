import 'dart:async';

import 'package:meta/meta.dart';

typedef SO<Serial> = ({Serial up, Serial down});
typedef AO<Serial> = Future<SO<Serial>>;

typedef SyncMigration<Db, Serial> = Migration<Db, Serial, SyncMigrationBuilder<Db, Serial>, SO<Serial>>;
typedef StaticSyncMigration<Db, Serial> = StaticMigration<Db, Serial, SyncMigrationBuilder<Db, Serial>, SO<Serial>>;
typedef AsyncMigration<Db, Serial> = Migration<Db, Serial, AsyncMigrationBuilder<Db, Serial>, AO<Serial>>;
typedef StaticAsyncMigration<Db, Serial> = StaticMigration<Db, Serial, AsyncMigrationBuilder<Db, Serial>, AO<Serial>>;

sealed class Migration<Db, Serial, B extends MaybeAsyncMigrationBuilder<Db, Serial, B, O>, O>
    implements Comparable<Migration<Db, Serial, B, O>> {
  Migration._({
    required DateTime definedAt,
    this.name,
    this.description,
    this.appliedAt,
    this.alwaysApply = false,
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

  factory Migration({
    required DateTime definedAt,
    String? name,
    String? description,
    DateTime? appliedAt,
    bool alwaysApply,
    required Serial up,
    required Serial down,
  }) = StaticMigration<Db, Serial, B, O>;

  factory Migration.dynamic({
    required DateTime definedAt,
    String? name,
    String? description,
    DateTime? appliedAt,
    bool alwaysApply,
    required O Function(Db db) generate,
  }) = MaybeAsyncMigrationBuilder<Db, Serial, B, O>.s;

  /// Create a new [StaticMigration] that undoes [migration]
  /// by flipping its [up] and [down] fields.
  factory Migration.undo({
    required DateTime definedAt,
    String? name,
    String? description,
    DateTime? appliedAt,
    bool alwaysApply = false,
    required StaticMigration<Db, Serial, B, O> migration,
  }) =>
      StaticMigration<Db, Serial, B, O>(
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

  /// A human-readable identifier for the migration. Used for debugging and logging.
  String get humanReadableId => name ?? definedAt.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaticMigration && runtimeType == other.runtimeType && definedAt.isAtSameMomentAs(other.definedAt);

  @override
  int get hashCode => definedAt.hashCode;

  @override
  int compareTo(Migration<Db, Serial, B, O> other) {
    return definedAt.compareTo(other.definedAt);
  }

  /// Find out if this migration was defined before [other].
  bool operator <(Migration<Db, Serial, B, O> other) {
    return definedAt.isBefore(other.definedAt);
  }

  /// Find out if this migration was defined after [other].
  bool operator >(Migration<Db, Serial, B, O> other) {
    return definedAt.isAfter(other.definedAt);
  }

  /// Find out if this migration was defined before or at the same time as [other].
  bool operator <=(Migration<Db, Serial, B, O> other) {
    return definedAt.isBefore(other.definedAt) || definedAt.isAtSameMomentAs(other.definedAt);
  }

  /// Find out if this migration was defined after or at the same time as [other].
  bool operator >=(Migration<Db, Serial, B, O> other) {
    return definedAt.isAfter(other.definedAt) || definedAt.isAtSameMomentAs(other.definedAt);
  }

  Migration<Db, Serial, B, O> copyWith({
    DateTime? definedAt,
    String? name,
    String? description,
    DateTime? appliedAt,
    bool? alwaysApply,
  });

  @override
  String toString() {
    return 'MigrationBase{definedAt: $definedAt, name: $name, description: $description, alwaysApply: $alwaysApply, appliedAt: $appliedAt}';
  }

  @internal
  FutureOr<StaticMigration<Db, Serial, B, O>> build(Db db);
}

sealed class MaybeAsyncMigrationBuilder<Db, Serial, B extends MaybeAsyncMigrationBuilder<Db, Serial, B, O>, O>
    extends Migration<Db, Serial, B, O> {
  MaybeAsyncMigrationBuilder._({
    required super.definedAt,
    super.name,
    super.description,
    super.appliedAt,
    super.alwaysApply,
  }) : super._();

  factory MaybeAsyncMigrationBuilder.s({
    required DateTime definedAt,
    String? name,
    String? description,
    DateTime? appliedAt,
    bool alwaysApply = false,
    required O Function(Db db) generate,
  }) {
    return switch (B) {
      const (SyncMigrationBuilder) => SyncMigrationBuilder<Db, Serial>(
          definedAt: definedAt,
          name: name,
          description: description,
          appliedAt: appliedAt,
          alwaysApply: alwaysApply,
          generate: generate as SO<Serial> Function(Db db),
        ),
      const (AsyncMigrationBuilder) => AsyncMigrationBuilder<Db, Serial>(
          definedAt: definedAt,
          name: name,
          description: description,
          appliedAt: appliedAt,
          alwaysApply: alwaysApply,
          generate: generate as AO<Serial> Function(Db db),
        ),
      Type() => throw UnimplementedError(),
    } as MaybeAsyncMigrationBuilder<Db, Serial, B, O>;
  }
}

@internal
final class SyncMigrationBuilder<Db, Serial>
    extends MaybeAsyncMigrationBuilder<Db, Serial, SyncMigrationBuilder<Db, Serial>, SO<Serial>> {
  /// Creates a new migration builder.
  ///
  /// This is used to build migrations dynamically, for example, when the migration code is generated
  /// or when the migration is defined in a different way than the usual `up` and `down` methods.
  SyncMigrationBuilder({
    required super.definedAt,
    super.name,
    super.description,
    super.appliedAt,
    super.alwaysApply,
    required this.generate,
  }) : super._();

  SO<Serial> Function(Db db) generate;

  @override
  StaticMigration<Db, Serial, SyncMigrationBuilder<Db, Serial>, SO<Serial>> build(Db db) {
    final (:down, :up) = generate(db);
    return StaticMigration<Db, Serial, SyncMigrationBuilder<Db, Serial>, SO<Serial>>(
      definedAt: definedAt,
      name: name,
      description: description,
      appliedAt: appliedAt,
      alwaysApply: alwaysApply,
      up: up,
      down: down,
    );
  }

  @override
  String toString() {
    return 'MigrationBuilder{definedAt: $definedAt, name: $name, description: $description, alwaysApply: $alwaysApply, appliedAt: $appliedAt}';
  }

  @override
  Migration<Db, Serial, SyncMigrationBuilder<Db, Serial>, SO<Serial>> copyWith(
      {DateTime? definedAt,
      String? name,
      String? description,
      DateTime? appliedAt,
      bool? alwaysApply,
      SO<Serial> Function(Db db)? generate}) {
    return SyncMigrationBuilder<Db, Serial>(
      definedAt: definedAt ?? this.definedAt,
      name: name ?? this.name,
      description: description ?? this.description,
      appliedAt: appliedAt ?? this.appliedAt,
      alwaysApply: alwaysApply ?? this.alwaysApply,
      generate: generate ?? this.generate,
    );
  }
}

@internal
final class AsyncMigrationBuilder<Db, Serial>
    extends MaybeAsyncMigrationBuilder<Db, Serial, AsyncMigrationBuilder<Db, Serial>, AO<Serial>> {
  /// Creates a new migration builder.
  ///
  /// This is used to build migrations dynamically, for example, when the migration code is generated
  /// or when the migration is defined in a different way than the usual `up` and `down` methods.
  AsyncMigrationBuilder({
    required super.definedAt,
    super.name,
    super.description,
    super.appliedAt,
    super.alwaysApply,
    required this.generate,
  }) : super._();

  AO<Serial> Function(Db db) generate;

  @override
  Future<StaticMigration<Db, Serial, AsyncMigrationBuilder<Db, Serial>, AO<Serial>>> build(Db db) async {
    final (:down, :up) = await generate(db);
    return StaticMigration<Db, Serial, AsyncMigrationBuilder<Db, Serial>, AO<Serial>>(
      definedAt: definedAt,
      name: name,
      description: description,
      appliedAt: appliedAt,
      alwaysApply: alwaysApply,
      up: up,
      down: down,
    );
  }

  @override
  String toString() {
    return 'AsyncMigrationBuilder{definedAt: $definedAt, name: $name, description: $description, alwaysApply: $alwaysApply, appliedAt: $appliedAt}';
  }

  @override
  Migration<Db, Serial, AsyncMigrationBuilder<Db, Serial>, AO<Serial>> copyWith(
      {DateTime? definedAt,
      String? name,
      String? description,
      DateTime? appliedAt,
      bool? alwaysApply,
      AO<Serial> Function(Db db)? generate}) {
    return AsyncMigrationBuilder<Db, Serial>(
      definedAt: definedAt ?? this.definedAt,
      name: name ?? this.name,
      description: description ?? this.description,
      appliedAt: appliedAt ?? this.appliedAt,
      alwaysApply: alwaysApply ?? this.alwaysApply,
      generate: generate ?? this.generate,
    );
  }
}

//// {@template dmwmt.migration}
/// A change to the database that can be applied and rolled back.
///
/// A migration is implemented as a simple data class that uses [definedAt] as the primary key.
///
/// Migrations have to be serialized and deserialized preserving atleast [definedAt] and [down]
/// to be able to make [SyncMigrator] work.
/// {endtemplate}
class StaticMigration<Db, Serial, B extends MaybeAsyncMigrationBuilder<Db, Serial, B, F>, F>
    extends Migration<Db, Serial, B, F> {
  /// Creates a new migration data class instance.
  ///
  /// Make sure that [definedAt] is unique for each migration and represents the time the code was edited.
  ///
  /// Throws an [ArgumentError] if [definedAt] is not in UTC.
  StaticMigration({
    required super.definedAt,
    super.name,
    super.description,
    super.appliedAt,
    super.alwaysApply,
    required this.up,
    required this.down,
  }) : super._();

  /// The migration to apply to the database.
  ///
  /// This could be a SQL string or a description of added and removed columns.
  ///
  /// It should be able to be stored inside of the database.
  ///
  /// It's kept as a generic type since different databases might support storing different types of data.
  final Serial up;

  /// The migration to undo the changes made by [up].
  final Serial down;

  @override
  String toString() {
    return 'Migration{definedAt: $definedAt, name: $name, description: $description, alwaysApply: $alwaysApply, appliedAt: $appliedAt, up: $up, down: $down}';
  }

  /// Creates a copy of this migration with the given fields replaced with new values.
  @override
  StaticMigration<Db, Serial, B, F> copyWith({
    DateTime? definedAt,
    String? name,
    String? description,
    DateTime? appliedAt,
    bool? alwaysApply,
    Serial? up,
    Serial? down,
  }) {
    return StaticMigration<Db, Serial, B, F>(
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
  StaticMigration<Db, Serial, B, F> build(Db db) => this;
}
