import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';
import 'package:meta/meta.dart';
import 'package:sqlite3/common.dart';

import 'transaction.dart';

/// A [SyncDatabase] implementation for SQLite3.
class Sqlite3Database implements SyncDatabase<CommonDatabase, String> {
  /// Creates a new [Sqlite3Database] instance.
  const Sqlite3Database(
    this._db, {
    this.transactor = const TransactionDelegate(),
  });

  final CommonDatabase _db;

  /// Responsible for handling transactions
  final Transactor transactor;

  @override
  void initializeMigrationsTable() {
    _db.execute('''
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
    final result = _db.select(
      '''SELECT name FROM sqlite_master WHERE type='table' AND name='migrations' LIMIT 1''',
    );
    return result.isNotEmpty;
  }

  @override
  @internal
  Iterator<Migration<CommonDatabase, String>> retrieveAllMigrations() {
    return _db
        .select('''SELECT * FROM migrations ORDER BY defined_at ASC''')
        .rows
        .map((row) {
          final [definedAt, name, description, appliedAt, up, down] = row;

          return Migration<CommonDatabase, String>(
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
  void storeMigrations(List<Migration<CommonDatabase, String>> migrations) {
    final withAppliedAt = _db.prepare(
      "INSERT INTO migrations (defined_at, name, description, applied_at, up, down) VALUES (?, ?, ?, ?, ?, ?)",
    );
    final withoutAppliedAt = _db.prepare(
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
  void removeMigrations(List<Migration<CommonDatabase, String>> migrations) {
    final stmt = _db.prepare('''DELETE FROM migrations WHERE defined_at = ?''');

    for (final migration in migrations) {
      stmt.execute([migration.definedAt.millisecondsSinceEpoch]);
    }

    stmt.dispose();
  }

  @override
  @internal
  void performMigration(String migration) {
    _db.execute(migration);
  }

  @override
  @internal
  void beginTransaction() => transactor.begin(_db);

  @override
  @internal
  void commitTransaction() => transactor.commit(_db);

  @override
  @internal
  void rollbackTransaction() => transactor.rollback(_db);
}
