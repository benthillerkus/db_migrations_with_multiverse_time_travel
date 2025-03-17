import 'dart:async';

import 'migration.dart';

/// {@template dmwmt.database}
/// A database that can store and apply migrations.
///
/// The type parameter [T] is the type of the [Migration].
///
/// Implementations of this class should wrap a database library.
/// {@endtemplate}
///
/// This is used for synchronous databases. For asynchronous databases, use [AsyncDatabase].
abstract interface class SyncDatabase<T> {
  /// {@template dmwmt.database.initializeMigrationsTable}
  /// Creates a table in the database that can store migrations.
  /// {@endtemplate}
  void initializeMigrationsTable();

  /// {@template dmwmt.database.isMigrationsTableInitialized}
  /// Checks if the migrations table has been initialized.
  /// {@endtemplate}
  bool isMigrationsTableInitialized();

  /// {@template dmwmt.database.retrieveAllMigrations}
  /// Reads all migrations stored in the database.
  ///
  /// The migrations are returned in the order they were defined.
  /// {@endtemplate}
  Iterator<Migration<T>> retrieveAllMigrations();

  /// {@template dmwmt.database.storeMigrations}
  /// Writes a migration to the database.
  /// {@endtemplate}
  void storeMigrations(List<Migration<T>> migrations);

  /// {@template dmwmt.database.removeMigrations}
  /// Removes a migration from the database.
  /// {@endtemplate}
  void removeMigrations(List<Migration<T>> migrations);

  /// {@template dmwmt.database.performMigration}
  /// Applies a migration to the database.
  /// {@endtemplate}
  void performMigration(T migration);

  /// {@template dmwmt.database.beginTransaction}
  /// Starts a transaction.
  /// {@endtemplate}
  void beginTransaction();

  /// {@template dmwmt.database.commitTransaction}
  /// Commits a transaction.
  /// {@endtemplate}
  void commitTransaction();

  /// {@template dmwmt.database.rollbackTransaction}
  /// Rolls back a transaction.
  /// {@endtemplate}
  void rollbackTransaction();
}

/// {@macro dmwmt.database}
///
/// This is used for asynchronous databases. For synchronous databases, use [SyncDatabase].
abstract interface class AsyncDatabase<T> {
  /// {@macro dmwmt.database.initializeMigrationsTable}
  Future<void> initializeMigrationsTable();

  /// {@macro dmwmt.database.isMigrationsTableInitialized}
  Future<bool> isMigrationsTableInitialized();

  /// {@macro dmwmt.database.retrieveAllMigrations}
  Stream<Migration<T>> retrieveAllMigrations();

  /// {@macro dmwmt.database.storeMigrations}
  Future<void> storeMigration(List<Migration<T>> migrations);

  /// {@macro dmwmt.database.removeMigrations}
  Future<void> removeMigrations(List<Migration<T>> migrations);

  /// {@macro dmwmt.database.performMigration}
  Future<void> performMigration(T migration);

  /// {@macro dmwmt.database.beginTransaction}
  Future<void> beginTransaction();

  /// {@macro dmwmt.database.commitTransaction}
  Future<void> commitTransaction();

  /// {@macro dmwmt.database.rollbackTransaction}
  Future<void> rollbackTransaction();
}
