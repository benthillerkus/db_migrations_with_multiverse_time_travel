import 'dart:io';

import 'package:sqflite_common/sqflite.dart';

/// A delegate for handling database transactions.
///
/// _Transactions_ being a sequence of operations that can be rolled back as a single unit.
abstract class Transactor {
  /// const constructor for implementations of [Transactor].
  const Transactor();

  /// Begins a transaction on the provided [db].
  Future<void> begin(Database db);

  /// Commits the transaction on the provided [db].
  Future<void> commit(Database db);

  /// Rolls back the transaction on the provided [db].
  Future<void> rollback(Database db);
}

/// A [Transactor] that does not perform any transaction.
///
/// This is only useful for testing purposes and should not be used in production code.
class NoTransactionDelegate extends Transactor {
  /// Creates a [NoTransactionDelegate] that does not perform any transaction.
  const NoTransactionDelegate();

  @override
  Future<void> begin(Database db) => Future.value();

  @override
  Future<void> commit(Database db) => Future.value();

  @override
  Future<void> rollback(Database db) => Future.value();
}

/// A [Transactor] that uses standard SQL transactions.
class TransactionDelegate extends Transactor {
  /// Creates a [TransactionDelegate] that uses standard SQL transactions.
  const TransactionDelegate();

  @override
  Future<void> begin(Database db) => db.execute('BEGIN TRANSACTION');

  @override
  Future<void> commit(Database db) => db.execute('COMMIT TRANSACTION');

  @override
  Future<void> rollback(Database db) => db.execute('ROLLBACK TRANSACTION');
}

/// A [Transactor] that creates a backup of the database that can be restored in case of a rollback.
///
/// Note that after migration it will **close** the database,
/// so you will need to reopen it if you want to continue using it.
class BackupTransactionDelegate extends Transactor {
  /// Creates a [BackupTransactionDelegate] that creates a backup of the database.
  ///
  /// The [backupFileName] is the name of the backup file that will be created in the same directory as the database file.
  BackupTransactionDelegate({
    this.backupFileName = 'backup.db',
  });

  /// The name of the backup file that will be created in the same directory as the database file.
  final String backupFileName;
  late final File _dbFile;
  late final File _backupFile;

  @override
  Future<void> begin(Database db) async {
    if (db.path == ":memory:") {
      return db.execute("VACUUM INTO '$backupFileName';");
    }
    _dbFile = File(db.path);
    _backupFile = File.fromUri(_dbFile.uri.replace(
        pathSegments: _dbFile.uri.pathSegments.take(_dbFile.uri.pathSegments.length - 2).followedBy([backupFileName])));
    if (await _backupFile.exists()) {
      await _backupFile.delete();
    }

    return db.execute("VACUUM INTO '${_backupFile.uri.toFilePath()}';");
  }

  @override
  Future<void> commit(Database db) {
    // Close it here too despite not being necessary,
    // to make sure that user code is able to handle
    // the rollback case correctly, where there
    // is no choice but to close the database.
    return db.close();
  }

  @override
  Future<void> rollback(Database db) async {
    await db.close();
    if (db.path == ":memory:") return;
    await _backupFile.copy(_dbFile.path);
    await _backupFile.delete();
  }
}
