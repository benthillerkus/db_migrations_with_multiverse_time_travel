import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';
import 'package:sqlite3/sqlite3.dart';

/// A [SyncDatabase] implementation for SQLite3.
class Sqlite3Database implements SyncDatabase<String> {
  /// Creates a new [Sqlite3Database] instance.
  const Sqlite3Database(this._db);

  final Database _db;

  @override
  void initializeMigrationsTable() {
    _db.execute('''CREATE TABLE IF NOT EXISTS migrations (
  defined_at INTEGER PRIMARY KEY,
  name TEXT,
  description TEXT,
  applied_at INTEGER,
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
  Iterator<Migration<String>> retrieveAllMigrations() {
    return _db
        .select('''SELECT * FROM migrations ORDER BY defined_at ASC''')
        .rows
        .map((row) {
          final [definedAt, name, description, appliedAt, up, down] = row;

          return Migration<String>(
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
  void storeMigrations(List<Migration<String>> migrations) {
    final stmt = _db.prepare(
      '''INSERT INTO migrations (defined_at, name, description, applied_at, up, down) VALUES (?, ?, ?, ?, ?, ?)''',
    );

    for (final migration in migrations) {
      stmt.execute([
        migration.definedAt.millisecondsSinceEpoch,
        migration.name,
        migration.description,
        migration.appliedAt?.millisecondsSinceEpoch,
        migration.up,
        migration.down,
      ]);
    }

    stmt.dispose();
  }

  @override
  void removeMigrations(List<Migration<String>> migrations) {
    final stmt = _db.prepare('''DELETE FROM migrations WHERE defined_at = ?''');

    for (final migration in migrations) {
      stmt.execute([migration.definedAt.millisecondsSinceEpoch]);
    }

    stmt.dispose();
  }

  @override
  void performMigration(String migration) {
    _db.execute(migration);
  }

  @override
  void beginTransaction() {
    _db.execute('BEGIN TRANSACTION');
  }

  @override
  void commitTransaction() {
    _db.execute('COMMIT TRANSACTION');
  }

  @override
  void rollbackTransaction() {
    _db.execute('ROLLBACK TRANSACTION');
  }
}
