import 'dart:io';

import 'package:logging/logging.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database.dart';

/// A delegate for handling database transactions.
///
/// _Transactions_ being a sequence of operations that can be rolled back as a single unit.
abstract class Transactor {
  /// const constructor for implementations of [Transactor].
  const Transactor();

  /// Begins a transaction on the provided [db].
  void begin(Sqlite3Database db);

  /// Commits the transaction on the provided [db].
  void commit(Sqlite3Database db);

  /// Rolls back the transaction on the provided [db].
  void rollback(Sqlite3Database db);
}

/// A [Transactor] that does not perform any transaction.
///
/// This is only useful for testing purposes and should not be used in production code.
class NoTransactionDelegate extends Transactor {
  /// Creates a [NoTransactionDelegate] that does not perform any transaction.
  const NoTransactionDelegate();

  @override
  void begin(Sqlite3Database db) {}

  @override
  void commit(Sqlite3Database db) {}

  @override
  void rollback(Sqlite3Database db) {}
}

/// A [Transactor] that uses standard SQL transactions.
class TransactionDelegate extends Transactor {
  /// Creates a [TransactionDelegate] that uses standard SQL transactions.
  const TransactionDelegate();

  @override
  void begin(Sqlite3Database db) => db.executeInstructions('BEGIN TRANSACTION');

  @override
  void commit(Sqlite3Database db) => db.executeInstructions('COMMIT TRANSACTION');

  @override
  void rollback(Sqlite3Database db) => db.executeInstructions('ROLLBACK TRANSACTION');
}

final Logger _log = Logger('db.transactor');

/// A [Transactor] that uses a backup of the database to perform rollbacks.
///
/// When [begin] is called, it creates a backup of the database using the `VACUUM INTO` command.
/// Aslong as that backup file exists, it can be used to restore the database in case of a rollback
/// and the transaction is considered in flight.
///
/// When [commit] is called, the backup file is deleted.
/// When [rollback] is called, the backup file is renamed to the original database file.
///
/// When [begin] is called, if the backup file already exists, it throws a [UncleanTransactionException],
/// because it indicates that a previous migration failed before committing.
///
/// To solve this, you can either remove the backup file (accepting the current potentially broken state)
/// by calling [commit]
/// or rename it to the original database file name (accepting the previous state before the migration)
/// by calling [rollback].
class BackupTransactionDelegate extends Transactor {
  /// Creates a [BackupTransactionDelegate] that creates a backup of the database.
  BackupTransactionDelegate({
    required this.dbFile,
    required this.backupFile,
  });

  /// The file of the database that is being backed up.
  final File dbFile;

  /// The file where the backup will be stored.
  final File backupFile;

  @override
  void begin(Sqlite3Database db) {
    if (backupFile.existsSync()) {
      _log.info("Found existing backup file at '${backupFile.path}'. Checking integrity...");
      CommonDatabase? backupDbConnection;
      try {
        backupDbConnection = sqlite3.open(backupFile.path);
        _log.fine("Backup file at '${backupFile.path}' can be opened. Checking integrity...");
        final res = backupDbConnection.select("pragma integrity_check;");
        if (res.first['integrity_check'] == 'ok') {
          // If the backup file is valid, we throw an exception to indicate that
          // a previous transaction was not cleanly completed.
          throw UncleanTransactionException(
            "Backup file exists at '${backupFile.path}'."
            " Maybe the previous migration failed before committing?"
            " The issue could be a power failure or a native crash."
            " Please either remove the backup file or rename the backup file as ${dbFile.path}.",
            this,
            db,
          );
        } else {
          _log.warning("Backup file at '${backupFile.path}' is corrupted. Proceeding with migration.");
        }
      } on UncleanTransactionException {
        rethrow;
      } on SqliteException {
        _log.info("Dropping unusable backup file at '${backupFile.path}'.");
        // If the backup file is corrupted, we cannot use it for rollback
        // and can just proceed with the migration.
        backupDbConnection?.dispose();
        backupFile.deleteSync();
      }
    }
    _log.fine("Creating backup of database at '${dbFile.path}' into '${backupFile.path}'");
    db.executeInstructions("VACUUM INTO '${backupFile.path}';");
  }

  @override
  void commit(Sqlite3Database db) {
    _log.fine("Committing transaction. Deleting backup file at '${backupFile.path}'");
    backupFile.deleteSync();
  }

  /// Rolls back the transaction by restoring the database from [backupFile].
  ///
  /// This is done by closing the current database connection,
  /// renaming the backup file to the original database file name,
  /// and then reconnecting to the database.
  ///
  /// If the database is in memory (i.e., `dbFile.path` is empty or `:memory:`),
  /// it will copy the backup file into memory and then delete the backup file.
  /// To do this a new in-memory database connection is created with default settings.
  @override
  void rollback(Sqlite3Database db) {
    db.db.dispose();
    if (dbFile.path.isEmpty || dbFile.path == ':memory:') {
      final backupDb = sqlite3.open(backupFile.uri.toString(), uri: true);
      db.db = sqlite3.copyIntoMemory(backupDb);
      backupDb.dispose();
      backupFile.deleteSync();
    } else {
      backupFile.renameSync(dbFile.path);
      db.reconnect();
    }
  }
}

/// An exception indicating that a previous transaction was not cleanly completed.
///
/// Handling code should either call [Transactor.commit] or
/// [Transactor.rollback] on [transactor] to resolve the issue
/// and then try the operation again.
class UncleanTransactionException implements Exception {
  /// Creates a [UncleanTransactionException] with the given [message].
  UncleanTransactionException(this.message, this.transactor, this.db);

  /// The message describing the exception.
  final String message;

  /// The [Transactor] that was used when the exception occurred.
  final Transactor transactor;

  /// The [Sqlite3Database] that was being used by the [transactor] when the exception occurred.
  final Sqlite3Database db;

  @override
  String toString() => 'Unclean transaction detected: $message';
}
