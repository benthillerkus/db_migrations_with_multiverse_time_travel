import 'package:sqflite_migrations_with_multiverse_time_travel/sqflite_migrations_with_multiverse_time_travel.dart';

/// A delegate for handling database transactions.
///
/// _Transactions_ being a sequence of operations that can be rolled back as a single unit.
abstract class Transactor {
  /// const constructor for implementations of [Transactor].
  const Transactor();

  /// Begins a transaction on the provided [db].
  Future<void> begin(SqfliteDatabase db);

  /// Commits the transaction on the provided [db].
  Future<void> commit(SqfliteDatabase db);

  /// Rolls back the transaction on the provided [db].
  Future<void> rollback(SqfliteDatabase db);
}

/// A [Transactor] that does not perform any transaction.
///
/// This is only useful for testing purposes and should not be used in production code.
class NoTransactionDelegate extends Transactor {
  /// Creates a [NoTransactionDelegate] that does not perform any transaction.
  const NoTransactionDelegate();

  @override
  Future<void> begin(SqfliteDatabase db) => Future.value();

  @override
  Future<void> commit(SqfliteDatabase db) => Future.value();

  @override
  Future<void> rollback(SqfliteDatabase db) => Future.value();
}

/// A [Transactor] that uses standard SQL transactions.
class TransactionDelegate extends Transactor {
  /// Creates a [TransactionDelegate] that uses standard SQL transactions.
  const TransactionDelegate();

  @override
  Future<void> begin(SqfliteDatabase db) => db.executeInstructions('BEGIN TRANSACTION');

  @override
  Future<void> commit(SqfliteDatabase db) => db.executeInstructions('COMMIT TRANSACTION');

  @override
  Future<void> rollback(SqfliteDatabase db) => db.executeInstructions('ROLLBACK TRANSACTION');
}
