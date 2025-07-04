import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';
import 'package:meta/meta.dart';
import 'package:sqlite3/common.dart';

import 'transaction.dart';

/// A [SyncDatabase] implementation for SQLite3.
class Sqlite3Database implements SyncDatabase<CommonDatabase, String> {
  /// Creates a new [Sqlite3Database] instance.
  ///
  /// The [connect] function is used to establish a connection to the SQLite3 database,
  /// see [Sqlite3Database.reconnect].
  Sqlite3Database(
    CommonDatabase Function(CommonDatabase? oldConnection) connect, {
    this.transactor = const TransactionDelegate(),
  }) : _connect = connect;

  CommonDatabase? _db;

  @override
  CommonDatabase get db => _db ??= _connect(null);

  @internal
  set db(CommonDatabase value) {
    _db = value;
  }

  /// {@macro time_travel.sqlite3.reconnect}
  ///
  /// [oldConnection] is `null` when `connect` is called for the first time,
  /// and the previous result of [connect] on subsequent calls.
  final CommonDatabase Function(CommonDatabase? oldConnection) _connect;

  /// {@template time_travel.sqlite3.reconnect}
  /// Establishes a connection to the database.
  ///
  /// This can be called multiple times, for example,
  /// when [BackUpTransactionDelegate] is used,
  /// which can close the database connection.
  ///
  /// If you don't want to reconnect to the database,
  /// you can just pass an existing connection.
  /// {@endtemplate}
  @internal
  void reconnect() => _db = _connect(_db);

  /// Responsible for handling transactions
  final Transactor transactor;

  @override
  void initializeMigrationsTable() {
    db.execute('''
CREATE TABLE IF NOT EXISTS migrations (
  defined_at INTEGER PRIMARY KEY,
  name TEXT,
  description TEXT,
  applied_at INTEGER DEFAULT (unixepoch(current_timestamp)),
  up TEXT NOT NULL,
  down TEXT NOT NULL
)''');
  }

  @override
  bool isMigrationsTableInitialized() {
    final result = db.select(
      '''SELECT name FROM sqlite_master WHERE type='table' AND name='migrations' LIMIT 1''',
    );
    return result.isNotEmpty;
  }

  @override
  @internal
  Iterator<SyncMigration<CommonDatabase, String>> retrieveAllMigrations() {
    return db
        .select('''SELECT * FROM migrations ORDER BY defined_at ASC''')
        .rows
        .map((row) {
          final [definedAt, name, description, appliedAt, up, down] = row;

          return SyncMigration<CommonDatabase, String>(
            definedAt: DateTime.fromMillisecondsSinceEpoch(definedAt as int, isUtc: true),
            name: name as String?,
            description: description as String?,
            appliedAt: appliedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(appliedAt as int, isUtc: true),
            up: up as String,
            down: down as String,
          );
        })
        .iterator;
  }

  @override
  @internal
  void storeMigrations(List<SyncMigration<CommonDatabase, String>> migrations) {
    final withAppliedAt = db.prepare(
      "INSERT INTO migrations (defined_at, name, description, applied_at, up, down) VALUES (?, ?, ?, ?, ?, ?)",
    );
    final withoutAppliedAt = db.prepare(
      "INSERT INTO migrations (defined_at, name, description, up, down) VALUES (?, ?, ?, ?, ?)",
    );

    for (final migration in migrations) {
      if (migration.appliedAt == null) {
        withoutAppliedAt.execute([
          migration.definedAt.millisecondsSinceEpoch,
          migration.name,
          migration.description,
          migration.up,
          migration.down,
        ]);
      } else {
        withAppliedAt.execute([
          migration.definedAt.millisecondsSinceEpoch,
          migration.name,
          migration.description,
          migration.appliedAt!.millisecondsSinceEpoch,
          migration.up,
          migration.down,
        ]);
      }
    }

    withAppliedAt.dispose();
    withoutAppliedAt.dispose();
  }

  @override
  @internal
  void removeMigrations(List<SyncMigration<CommonDatabase, String>> migrations) {
    final stmt = db.prepare('''DELETE FROM migrations WHERE defined_at = ?''');

    for (final migration in migrations) {
      stmt.execute([migration.definedAt.millisecondsSinceEpoch]);
    }

    stmt.dispose();
  }

  @override
  void executeInstructions(String sql) {
    db.execute(sql);
  }

  @override
  @internal
  void beginTransaction() => transactor.begin(this);

  @override
  @internal
  void commitTransaction() => transactor.commit(this);

  @override
  @internal
  void rollbackTransaction() => transactor.rollback(this);
}
