import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';
import 'package:meta/meta.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_migrations_with_multiverse_time_travel/src/transaction.dart';

/// An [AsyncDatabase] implementation for SQLite.
class SqfliteDatabase implements AsyncDatabase<Database, String> {
  /// Creates a new [SqfliteDatabase] instance.
  const SqfliteDatabase(
    this.db, {
    this.transactor = const TransactionDelegate(),
  });

  @override
  final Database db;

  /// Responsible for handling transactions
  final Transactor transactor;

  @override
  @internal
  Future<void> beginTransaction() => transactor.begin(db);

  @override
  @internal
  Future<void> commitTransaction() => transactor.commit(db);

  @override
  @internal
  Future<void> rollbackTransaction() => transactor.rollback(db);

  @override
  Future<void> initializeMigrationsTable() {
    return db.execute('''
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
    return db
        .rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='migrations' LIMIT 1")
        .then((result) => result.isNotEmpty);
  }

  @override
  Future<void> executeInstructions(String sql) {
    return db.execute(sql);
  }

  @override
  @internal
  Future<void> removeMigrations(List<Migration<Database, String>> migrations) {
    return Future.wait(migrations.map((migration) {
      return db.execute('DELETE FROM migrations WHERE defined_at = ?', [migration.definedAt.millisecondsSinceEpoch]);
    }));
  }

  @override
  @internal
  Stream<AsyncMigration<Database, String>> retrieveAllMigrations() async* {
    final cursor = await db.rawQueryCursor("SELECT * FROM migrations ORDER BY defined_at ASC", []);

    try {
      while (true) {
        final hasRow = await cursor.moveNext();
        if (!hasRow) break;
        yield AsyncMigration<Database, String>(
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
      rethrow;
    } finally {
      await cursor.close();
    }
  }

  @override
  @internal
  Future<void> storeMigrations(covariant List<Migration<Database, String>> migrations) {
    return Future.wait(migrations.map((migration) {
      return db.insert('migrations', {
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
