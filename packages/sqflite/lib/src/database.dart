import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';
import 'package:sqflite_common/sqlite_api.dart';

/// An [AsyncDatabase] implementation for SQLite.
class SqfliteDatabase implements AsyncDatabase<String> {
  /// Creates a new [SqfliteDatabase] instance.
  const SqfliteDatabase(this._db);

  final Database _db;

  @override
  Future<void> beginTransaction() {
    return _db.execute('BEGIN TRANSACTION');
  }

  @override
  Future<void> commitTransaction() {
    return _db.execute('COMMIT TRANSACTION');
  }

  @override
  Future<void> initializeMigrationsTable() {
    return _db.execute('''
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
  Future<bool> isMigrationsTableInitialized() {
    return _db
        .rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='migrations' LIMIT 1")
        .then((result) => result.isNotEmpty);
  }

  @override
  Future<void> performMigration(String migration) {
    return _db.execute(migration);
  }

  @override
  Future<void> removeMigrations(List<Migration<String>> migrations) {
    return Future.wait(migrations.map((migration) {
      return _db.execute('DELETE FROM migrations WHERE defined_at = ?', [migration.definedAt.millisecondsSinceEpoch]);
    }));
  }

  @override
  Stream<Migration<String>> retrieveAllMigrations() async* {
    final cursor = await _db.rawQueryCursor("SELECT * FROM migrations ORDER BY defined_at ASC", []);

    try {
      while (true) {
        final hasRow = await cursor.moveNext();
        if (!hasRow) break;
        yield Migration<String>(
          definedAt: DateTime.fromMillisecondsSinceEpoch(cursor.current['defined_at'] as int, isUtc: true),
          name: cursor.current['name'] as String?,
          description: cursor.current['description'] as String?,
          appliedAt: cursor.current['applied_at'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(cursor.current['applied_at'] as int, isUtc: true),
          up: cursor.current['up'] as String,
          down: cursor.current['down'] as String,
        );
      }
    } catch (e) {
      await cursor.close();
      rethrow;
    }
  }

  @override
  Future<void> rollbackTransaction() {
    return _db.execute('ROLLBACK TRANSACTION');
  }

  @override
  Future<void> storeMigrations(List<Migration<String>> migrations) {
    return Future.wait(migrations.map((migration) {
      return _db.insert('migrations', {
        'defined_at': migration.definedAt.millisecondsSinceEpoch,
        'name': migration.name,
        'description': migration.description,
        if (migration.appliedAt != null) 'applied_at': migration.appliedAt!.millisecondsSinceEpoch,
        'up': migration.up,
        'down': migration.down,
      });
    }));
  }
}
