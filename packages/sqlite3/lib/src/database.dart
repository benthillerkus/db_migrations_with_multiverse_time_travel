import 'package:db_migrations_with_multiverse_timetravel/db_migrations_with_multiverse_timetravel.dart'
    hide Database, AsyncDatabase;
import 'package:db_migrations_with_multiverse_timetravel/db_migrations_with_multiverse_timetravel.dart'
    as multiverse;
import 'package:sqlite3/sqlite3.dart';

class Sqlite3Database implements multiverse.Database<String> {
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
  List<Migration<String>> readAllMigrations() {
    return _db.select('''SELECT * FROM migrations ORDER BY defined_at ASC''').rows.map((row) {
      final [definedAt, name, description, appliedAt, up, down] = row;

      return Migration<String>(
        definedAt: DateTime.fromMillisecondsSinceEpoch(definedAt as int, isUtc: true),
        name: name as String?,
        description: description as String?,
        appliedAt:
            appliedAt == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(appliedAt as int, isUtc: true),
        up: up as String,
        down: down as String,
      );
    }).toList();
  }

  @override
  void writeMigration(Migration<String> migration) {
    _db.execute(
      '''INSERT INTO migrations (defined_at, name, description, applied_at, up, down) VALUES (?, ?, ?, ?, ?, ?)''',
      [
        migration.definedAt.millisecondsSinceEpoch,
        migration.name,
        migration.description,
        migration.appliedAt?.millisecondsSinceEpoch,
        migration.up,
        migration.down,
      ],
    );
  }
}
