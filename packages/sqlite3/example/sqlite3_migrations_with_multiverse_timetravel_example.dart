import 'package:sqlite3_migrations_with_multiverse_timetravel/sqlite3_migrations_with_multiverse_timetravel.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final db = sqlite3.openInMemory();
  final migrationManager = Sqlite3Database(db);

  if (!migrationManager.isMigrationsTableInitialized()) {
    migrationManager.initializeMigrationsTable();
  }

  final migrations = migrationManager.readAllMigrations();

  print('awesome: ${migrations.length}');
}
