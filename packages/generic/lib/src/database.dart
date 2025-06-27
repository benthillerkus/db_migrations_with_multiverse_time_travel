import 'dart:async';

import 'migration.dart';

/// {@template dmwmt.database}
/// A database that can store and apply migrations.
///
/// The type parameter [T] is the type of the [Migration].
///
/// Implementations of this class should wrap a database library.
/// {@endtemplate}
abstract interface class MaybeAsyncDatabase<Db, Serial, B extends MaybeAsyncMigrationBuilder<Db, Serial, B, O>, O> {
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
  FutureOr<void> storeMigrations(List<StaticMigration<Db, Serial, B, O>> migrations);

  /// {@template dmwmt.database.removeMigrations}
  /// Removes a migration from the database.
  /// {@endtemplate}
  FutureOr<void> removeMigrations(List<Migration<Db, Serial, B, O>> migrations);

  /// {@template dmwmt.database.performMigration}
  /// Applies a migration to the database.
  /// {@endtemplate}
  FutureOr<void> execute(Serial migration);

  /// {@template dmwmt.database.db}
  /// Uses the database to execute a raw action.
  /// {@endtemplate}
  FutureOr<T> executeRaw<T>(FutureOr<T> Function(Db db) action);

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
abstract interface class SyncDatabase<Db, Serial>
    implements MaybeAsyncDatabase<Db, Serial, SyncMigrationBuilder<Db, Serial>, SO<Serial>> {
  @override
  void initializeMigrationsTable();

  @override
  bool isMigrationsTableInitialized();

  @override
  Iterator<StaticSyncMigration<Db, Serial>> retrieveAllMigrations();

  @override
  void storeMigrations(List<StaticSyncMigration<Db, Serial>> migrations);

  @override
  void removeMigrations(List<SyncMigration<Db, Serial>> migrations);

  @override
  void execute(Serial serializedMigration);

  @override
  T executeRaw<T>(covariant T Function(Db db) action);

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
abstract interface class AsyncDatabase<Db, Serial>
    implements MaybeAsyncDatabase<Db, Serial, AsyncMigrationBuilder<Db, Serial>, AO<Serial>> {
  @override
  Stream<StaticMigration<Db, Serial, AsyncMigrationBuilder<Db, Serial>, AO<Serial>>> retrieveAllMigrations();
}
