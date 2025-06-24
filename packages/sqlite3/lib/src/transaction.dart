import 'dart:io';

import 'package:sqlite3/common.dart';

/// A delegate for handling database transactions.
///
/// _Transactions_ being a sequence of operations that can be rolled back as a single unit.
abstract class Transactor {
  /// const constructor for implementations of [Transactor].
  const Transactor();

  /// Begins a transaction on the provided [db].
  void begin(CommonDatabase db);

  /// Commits the transaction on the provided [db].
  void commit(CommonDatabase db);

  /// Rolls back the transaction on the provided [db].
  void rollback(CommonDatabase db);
}

/// A [Transactor] that does not perform any transaction.
///
/// This is only useful for testing purposes and should not be used in production code.
class NoTransactionDelegate extends Transactor {
  /// Creates a [NoTransactionDelegate] that does not perform any transaction.
  const NoTransactionDelegate();

  @override
  void begin(CommonDatabase db) {}

  @override
  void commit(CommonDatabase db) {}

  @override
  void rollback(CommonDatabase db) {}
}

/// A [Transactor] that uses standard SQL transactions.
class TransactionDelegate extends Transactor {
  /// Creates a [TransactionDelegate] that uses standard SQL transactions.
  const TransactionDelegate();

  @override
  void begin(CommonDatabase db) => db.execute('BEGIN TRANSACTION');

  @override
  void commit(CommonDatabase db) => db.execute('COMMIT TRANSACTION');

  @override
  void rollback(CommonDatabase db) => db.execute('ROLLBACK TRANSACTION');
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
  void begin(CommonDatabase db) {
    _path = db.select("select file from pragma_database_list where name = 'main'").first.values.first! as String;
    if (_path.isEmpty || _path == ':memory:') {
      db.execute("VACUUM INTO '$backupFileName';");
    }
    _dbFile = File(_path);
    _backupFile = File('${_dbFile.parent.path}/$backupFileName');
    if (_backupFile.existsSync()) {
      _backupFile.deleteSync();
    }
    db.execute("VACUUM INTO '${_backupFile.path}';");
  }

  @override
  void commit(CommonDatabase db) => db.dispose();

  @override
  void rollback(CommonDatabase db) {
    db.dispose();
    if (_path == ':memory:') return;
    _backupFile.copySync(_dbFile.path);
    _backupFile.deleteSync();
  }
}
