import 'dart:async';

import 'migration.dart';

/// {@template dmwmt.database}
/// A database that can store and apply migrations.
///
/// The type parameter [T] is the type of the [Migration].
///
/// Implementations of this class should wrap a database library.
/// {@endtemplate}
abstract interface class MaybeAsyncDatabase<T> {
  /// {@template dmwmt.database.initializeMigrationsTable}
  /// Creates a table in the database that can store migrations.
  /// {@endtemplate}
  FutureOr<void> initializeMigrationsTable();

  /// {@template dmwmt.database.isMigrationsTableInitialized}
  /// Checks if the migrations table has been initialized.
  /// {@endtemplate}
  FutureOr<bool> isMigrationsTableInitialized();

  /// {@template dmwmt.database.retrieveAllMigrations}
  /// Reads all migrations stored in the database.
  ///
  /// The migrations are returned in the order they were defined.
  /// {@endtemplate}
  dynamic retrieveAllMigrations();

  /// {@template dmwmt.database.storeMigrations}
  /// Writes a migration to the database.
  /// {@endtemplate}
  FutureOr<void> storeMigrations(List<Migration<T>> migrations);

  /// {@template dmwmt.database.removeMigrations}
  /// Removes a migration from the database.
  /// {@endtemplate}
  FutureOr<void> removeMigrations(List<Migration<T>> migrations);

  /// {@template dmwmt.database.performMigration}
  /// Applies a migration to the database.
  /// {@endtemplate}

  FutureOr<void> performMigration(T migration);

  /// {@template dmwmt.database.beginTransaction}
  /// Starts a transaction.
  /// {@endtemplate}
  FutureOr<void> beginTransaction();

  /// {@template dmwmt.database.commitTransaction}
  /// Commits a transaction.
  /// {@endtemplate}
  FutureOr<void> commitTransaction();

  /// {@template dmwmt.database.rollbackTransaction}
  /// Rolls back a transaction.
  /// {@endtemplate}
  FutureOr<void> rollbackTransaction();
}

/// {@macro dmwmt.database}
///
/// This is used for synchronous databases. For asynchronous databases, use [AsyncDatabase].
abstract interface class SyncDatabase<T> implements MaybeAsyncDatabase<T> {
  @override
  void initializeMigrationsTable();

  @override
  bool isMigrationsTableInitialized();

  @override
  Iterator<Migration<T>> retrieveAllMigrations();

  @override
  void storeMigrations(List<Migration<T>> migrations);

  @override
  void removeMigrations(List<Migration<T>> migrations);

  @override
  void performMigration(T migration);

  @override
  void beginTransaction();

  @override
  void commitTransaction();

  @override
  void rollbackTransaction();
}

/// {@macro dmwmt.database}
///
/// This is used for asynchronous databases. For synchronous databases, use [SyncDatabase].
abstract interface class AsyncDatabase<T> implements MaybeAsyncDatabase<T> {
  @override
  Stream<Migration<T>> retrieveAllMigrations();
}
