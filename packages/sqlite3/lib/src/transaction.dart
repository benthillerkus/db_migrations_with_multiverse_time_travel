import 'dart:io';

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

/// A [Transactor] that creates a backup of the database that can be restored in case of a rollback.
///
/// Note that after migration it will **close** the database,
/// so you will need to reopen it if you want to continue using it.
class BackupTransactionDelegate extends Transactor {
  /// Creates a [BackupTransactionDelegate] that creates a backup of the database.
  BackupTransactionDelegate({
    this.backupFileName = 'backup.db',
  });

  /// The name of the backup file that will be created in the same directory as the database file.
  final String backupFileName;
  late final String _path;
  late final File _dbFile;
  late final File _backupFile;

  @override
  void begin(Sqlite3Database db) {
    _path = db.db.select("select file from pragma_database_list where name = 'main'").first.values.first! as String;
    if (_path.isEmpty || _path == ':memory:') {
      _backupFile = File(backupFileName);
    } else {
      _dbFile = File(_path);
      _backupFile = File('${_dbFile.parent.path}/$backupFileName');
    }
    if (_backupFile.existsSync()) {
      _backupFile.deleteSync();
    }
    db.executeInstructions("VACUUM INTO '${_backupFile.path}';");
  }

  @override
  void commit(Sqlite3Database db) {}

  @override
  void rollback(Sqlite3Database db) {
    db.db.dispose();
    if (_path.isEmpty || _path == ':memory:') return;
    _backupFile.renameSync(_dbFile.path);
    db.reconnect();
  }
}
