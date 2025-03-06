import 'migration.dart';

abstract interface class Database<T> {
  /// Creates a table in the database that can store migrations.
  void initializeMigrationsTable();

  /// Checks if the migrations table has been initialized.
  bool isMigrationsTableInitialized();

  /// Reads all migrations stored in the database.
  List<Migration<T>> readAllMigrations();

  /// Writes a migration to the database.
  void writeMigration(Migration<T> migration);
}

abstract interface class AsyncDatabase<T> {
  /// Creates a table in the database that can store migrations.
  Future<void> initializeMigrationsTable();

  /// Checks if the migrations table has been initialized.
  Future<bool> isMigrationsTableInitialized();

  /// Reads all migrations stored in the database.
  Future<List<Migration<T>>> readAllMigrations();

  /// Writes a migration to the database.
  Future<void> writeMigration(Migration<T> migration);
}
