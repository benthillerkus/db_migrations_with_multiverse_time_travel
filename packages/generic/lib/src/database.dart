import 'migration.dart';

abstract interface class Database<T> {
  /// Creates a table in the database that can store migrations.
  void initializeMigrationsTable();

  /// Checks if the migrations table has been initialized.
  bool isMigrationsTableInitialized();

  /// Reads all migrations stored in the database.
  ///
  /// The migrations are returned in the order they were defined.
  Iterator<Migration<T>> retrieveAllMigrations();

  /// Writes a migration to the database.
  void storeMigrations(List<Migration<T>> migrations);

  /// Removes a migration from the database.
  void removeMigrations(List<Migration<T>> migrations);

  /// Applies a migration to the database.
  void performMigration(T migration);

  // TODO Transactions!
}

abstract interface class AsyncDatabase<T> {
  /// Creates a table in the database that can store migrations.
  Future<void> initializeMigrationsTable();

  /// Checks if the migrations table has been initialized.
  Future<bool> isMigrationsTableInitialized();

  /// Reads all migrations stored in the database.
  ///
  /// The migrations are returned in the order they were defined.
  Stream<Migration<T>> retrieveAllMigrations();

  /// Writes a migration to the database.
  Future<void> storeMigration(List<Migration<T>> migrations);

  /// Removes a migration from the database.
  Future<void> removeMigrations(List<Migration<T>> migrations);

  /// Applies a migration to the database.
  Future<void> performMigration(T migration);
}
