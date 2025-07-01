import 'dart:async';

import 'migration.dart';

/// {@template dmwmt.database}
/// A database that can store and apply migrations.
/// 
/// Implementations of this class should wrap a database library.
/// 
/// [Db] is the type of the wrapped database,
/// and [Serial] is the type of the migration instructions used by the database.
/// {@endtemplate}
abstract interface class MaybeAsyncDatabase<Db, Serial> {
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
  FutureOr<void> storeMigrations(covariant List<Migration<Db, Serial>> migrations);

  /// {@template dmwmt.database.removeMigrations}
  /// Removes a migration from the database.
  /// {@endtemplate}
  FutureOr<void> removeMigrations(covariant List<Migration<Db, Serial>> migrations);

  /// The wrapped database
  Db get db;

  /// {@template dmwmt.database.performMigration}
  /// Applies a migration to the database.
  /// {@endtemplate}
  FutureOr<void> executeInstructions(Serial instructions);

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
abstract interface class SyncDatabase<D, T> implements MaybeAsyncDatabase<D, T> {
  @override
  void initializeMigrationsTable();

  @override
  bool isMigrationsTableInitialized();

  @override
  Iterator<SyncMigration<D, T>> retrieveAllMigrations();

  @override
  void storeMigrations(List<SyncMigration<D, T>> migrations);

  @override
  void removeMigrations(List<SyncMigration<D, T>> migrations);

  @override
  void executeInstructions(T instructions);

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
abstract interface class AsyncDatabase<D, T> implements MaybeAsyncDatabase<D, T> {
  @override
  Stream<AsyncMigration<D, T>> retrieveAllMigrations();
}
