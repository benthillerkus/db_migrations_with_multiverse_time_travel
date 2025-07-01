import 'dart:async';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import 'database.dart';
import 'migration.dart';

/// An extension on [SyncDatabase] that adds a [migrate] method.
extension SyncMigrateExt<D, T> on SyncDatabase<D, T> {
  /// Migrates the database using the given [migrations].
  void migrate(List<SyncMigration<D, T>> migrations) {
    SyncMigrator<D, T>()(db: this, defined: migrations.iterator);
  }
}

/// An extension on [AsyncDatabase] that adds a [migrate] method.
extension AsyncMigrateExt<D, T> on AsyncDatabase<D, T> {
  /// Migrates the database using the given [migrations].
  Future<void> migrate(List<AsyncMigration<D, T>> migrations) {
    return AsyncMigrator<D, T>()(db: this, defined: migrations.iterator);
  }
}

/// {@template dmwmt.migrator}
/// A migrator that applies and rolls back migrations.
///
/// Use [call] to perform a schema update.
// Unfortunatly this ended up being an object instead of a function
// but this made it easier to test
/// {@endtemplate}
class SyncMigrator<D, T> {
  /// Creates a new [SyncMigrator] with an optional [logger].
  ///
  /// {@template dmwmt.migrator.new}
  /// The [logger] is used to log messages during the migration process.
  /// If no [Logger] is provided, a new logger named 'db.migrate' is created.
  /// {@endtemplate}
  SyncMigrator({Logger? logger})
      : log = logger ?? Logger('db.migrate'),
        _hasDefined = false,
        _hasApplied = false,
        _inTransaction = false;

  /// {@template dmwmt.migrator.log}
  /// The logger used during migrations.
  ///
  /// Conforms to the [Logger] class from the `logging` package.
  ///
  /// Defaults to a logger named 'db.migrate'.
  /// {@endtemplate}
  final Logger log;

  SyncDatabase<D, T>? _db;

  /// {@template dmwmt.migrator._defined}
  /// The migrations that are defined in code.
  /// {@endtemplate}
  Iterator<SyncMigration<D, T>>? _defined;

  /// {@template dmwmt.migrator._applied}
  /// The migrations that have been applied to the database.
  /// {@endtemplate}
  Iterator<SyncMigration<D, T>>? _applied;

  /// {@template dmwmt.migrator._hasDefined}
  /// Whether there are any [_defined] migrations left to apply.
  ///
  /// This is the result of [_defined.moveNext].
  /// {@endtemplate}
  bool _hasDefined;

  /// {@template dmwmt.migrator._hasApplied}
  /// Whether there are any [_applied] migrations left to rollback.
  ///
  /// This is the result of [_applied.moveNext].
  /// {@endtemplate}
  bool _hasApplied;

  /// {@template dmwmt.migrator._previousDefined}
  /// The previous migration obtained from [_defined] before calling [_defined.moveNext].
  ///
  /// Used to ensure that migrations are being iterated in the correct order.
  /// {@endtemplate}
  SyncMigration<D, T>? _previousDefined;

  /// {@template dmwmt.migrator._previousApplied}
  /// The previous migration obtained from [_applied] before calling [_applied.moveNext].
  ///
  /// Used to ensure that migrations are being iterated in the correct order.
  /// {@endtemplate}
  SyncMigration<D, T>? _previousApplied;

  /// {@template dmwmt.migrator._inTransaction}
  /// Whether the migrator has started a transaction on the [_db].
  ///
  /// This is used so that the migrator can be lazy about transactions,
  /// only starting one when it needs to actually change something on the database.
  ///
  /// (Arguably, everything should then still be in a READ transaction, but we're not going that far)
  /// {@endtemplate}
  bool _inTransaction;

  void _moveNextDefined() {
    _previousDefined = _defined!.current;
    _hasDefined = _defined!.moveNext();
    if (_hasDefined && (_previousDefined! >= _defined!.current)) {
      throw StateError(
        'Defined migrations are not in ascending order: $_previousDefined should not come before ${_defined!.current}.',
      );
    }
  }

  void _moveNextApplied() {
    _previousApplied = _applied!.current;
    _hasApplied = _applied!.moveNext();
    if (_hasApplied && _previousApplied! >= _applied!.current) {
      throw StateError(
        'Applied migrations are not in ascending order: $_previousApplied should not come before ${_applied!.current}.',
      );
    }
  }

  /// {@template dmwmt.migrator.call}
  /// Makes the migrator work with the given database and migrations.
  ///
  /// Throws a [StateError] if the [Migration]s in [defined] are not in ascending order.
  /// Throws a [StateError] the [Migration]s obtained from the db are not in ascending order.
  /// {@endtemplate}
  void call({required SyncDatabase<D, T> db, required Iterator<SyncMigration<D, T>> defined}) {
    initialize(db, defined);
    // [_defined] and [_applied] are moved to the first migration

    try {
      findLastCommonMigration();
      // [_defined] and [_applied] are moved to the migration after the last common migration

      /// The loop is only there to be able to first rollback with [rollbackRemainingAppliedMigrations]
      /// and then [applyRemainingDefinedMigrations] to apply the rest.
      loop:
      while (true) {
        switch ((_hasDefined, _hasApplied)) {
          case (false, false):
            // No remaining migrations to apply or rollback.
            // we're done
            break loop;
          case (true, false):
            // [_applied] is moved to the end
            applyRemainingDefinedMigrations();
          // [_defined] is moved to the end
          case (_, true):
            rollbackRemainingAppliedMigrations();
          // [_applied] is moved to the end
        }
      }

      if (_inTransaction) {
        _db!.commitTransaction();
      }
    } catch (e) {
      if (_inTransaction) {
        _db!.rollbackTransaction();
      }
      rethrow;
    }

    log.fine('migration complete');

    reset();
  }

  /// {@template dmwmt.migrator.initialize}
  /// Sets up the migrator to work with the given database and migrations.
  ///
  /// Throws a [ConcurrentModificationError] if the migrator is already [working].
  /// {@endtemplate}
  @visibleForTesting
  void initialize(SyncDatabase<D, T> db, Iterator<SyncMigration<D, T>> defined) {
    log.finer('initializing migrator...');

    _db = db;
    _defined = defined;
    _inTransaction = false;

    if (!_db!.isMigrationsTableInitialized()) {
      log.fine('initializing migrations table');
      _db!.initializeMigrationsTable();
    }

    _applied = db.retrieveAllMigrations();
    _hasDefined = _defined!.moveNext();
    _hasApplied = _applied!.moveNext();
  }

  /// {@template dmwmt.migrator.findLastCommonMigration}
  /// Find the last common migration between defined and applied migrations.
  ///
  /// The last common migration is the last (going forwards in time) migration that is both defined and applied.
  ///
  /// Any common migration that has [Migration.alwaysApply] set to `true` will be applied to the database.
  /// {@endtemplate}
  @visibleForTesting
  Migration<D, T>? findLastCommonMigration() {
    log.finer('finding last common migration...');
    Migration<D, T>? lastCommon;
    while (_hasDefined && _hasApplied && _defined!.current == _applied!.current) {
      lastCommon = _defined!.current;
      if (lastCommon.alwaysApply) {
        if (!_inTransaction) {
          log.finer('beginning transaction...');
          _db!.beginTransaction();
          _inTransaction = true;
        }
        lastCommon.initialize(_db!.db);
        _db!.performMigration(lastCommon.up);
      }
      _moveNextDefined();
      _moveNextApplied();
    }

    if (lastCommon != null) {
      log.finer('last common migration: ${lastCommon.humanReadableId}');
    } else {
      log.finer('no common migrations found');
    }

    return lastCommon;
  }

  /// {@template dmwmt.migrator.rollbackRemainingAppliedMigrations}
  /// Rollback all incoming [_applied] migrations.
  ///
  /// This is done in reverse order: the last applied [Migration] is rolled back first.
  ///
  /// The migrations are then removed from the migrations table in the [MaybeAsyncDatabase].
  /// {@endtemplate}
  @visibleForTesting
  void rollbackRemainingAppliedMigrations() {
    log.fine('rolling back applied migrations...');

    if (!_hasApplied) {
      log.finer('no migrations to rollback');
      return;
    }

    final toRollback = [for (; _hasApplied; _moveNextApplied()) _applied!.current].reversed.toList();

    if (!_inTransaction && toRollback.isNotEmpty) {
      log.finer('beginning transaction...');
      _db!.beginTransaction();
      _inTransaction = true;
    }

    for (final migration in toRollback) {
      log.finer('|_ - migration ${migration.humanReadableId}');
      _db!.performMigration(migration.down);
    }
    log.finest('updating applied migrations database table...');
    _db!.removeMigrations(toRollback);
  }

  /// {@template dmwmt.migrator.applyRemainingDefinedMigrations}
  /// Apply all remaining defined migrations.
  ///
  /// The migrations are applied in order: the first defined [Migration] is applied first.
  ///
  /// The migrations are then added to the migrations table in the [MaybeAsyncDatabase].
  /// {@endtemplate}
  @visibleForTesting
  void applyRemainingDefinedMigrations() {
    log.fine('applying all remaining defined migrations');

    final toApply = List<SyncMigration<D, T>>.empty(growable: true);
    final now = DateTime.now().toUtc();

    while (_hasDefined) {
      if (!_inTransaction) {
        log.finer('beginning transaction...');
        _db!.beginTransaction();
        _inTransaction = true;
      }
      final migration = _defined!.current.copyWith(appliedAt: now);
      log.finer('|_ + migration ${migration.humanReadableId}');
      migration.initialize(_db!.db);
      _db!.performMigration(migration.up);
      toApply.add(migration);
      _moveNextDefined();
    }
    log.finest('updating applied migrations database table...');
    _db!.storeMigrations(toApply);
  }

  /// {@template dmwmt.migrator}
  /// Resets the migrator to its initial state, allowing it to be used again.
  /// {@endtemplate}
  @visibleForTesting
  void reset() {
    _defined = null;
    _applied = null;
    _hasDefined = false;
    _hasApplied = false;
    _previousDefined = null;
    _previousApplied = null;
    _db = null;
    log.finer('migrator resetted');
  }
}

/// {@macro dmwmt.migrator}
class AsyncMigrator<D, T> {
  /// Creates a new [AsyncMigrator] with an optional [logger].
  ///
  /// {@macro dmwmt.migrator.new}
  AsyncMigrator({Logger? logger})
      : log = logger ?? Logger('db.migrate'),
        _hasDefined = false,
        _hasApplied = false,
        _inTransaction = false;

  /// {@macro dmwmt.migrator.log}
  final Logger log;

  AsyncDatabase<D, T>? _db;

  /// Flag to check if the migrator is already working.
  ///
  /// When this is `true`, calling [call] will throw a [ConcurrentModificationError].
  bool get working => _db != null;

  /// {@macro dmwmt.migrator._defined}
  Iterator<AsyncMigration<D, T>>? _defined;

  /// {@macro dmwmt.migrator._applied}
  StreamIterator<AsyncMigration<D, T>>? _applied;

  /// {@macro dmwmt.migrator._hasDefined}
  bool _hasDefined;

  /// {@macro dmwmt.migrator._hasApplied}
  bool _hasApplied;

  /// {@macro dmwmt.migrator._previousDefined}
  AsyncMigration<D, T>? _previousDefined;

  /// {@macro dmwmt.migrator._previousApplied}
  AsyncMigration<D, T>? _previousApplied;

  /// {@macro dmwmt.migrator._inTransaction}
  bool _inTransaction;

  void _moveNextDefined() {
    _previousDefined = _defined!.current;
    _hasDefined = _defined!.moveNext();
    if (_hasDefined && (_previousDefined! >= _defined!.current)) {
      throw StateError(
        'Defined migrations are not in ascending order: $_previousDefined should not come before ${_defined!.current}.',
      );
    }
  }

  Future<void> _moveNextApplied() async {
    _previousApplied = _applied!.current;
    _hasApplied = await _applied!.moveNext();
    if (_hasApplied && _previousApplied! >= _applied!.current) {
      throw StateError(
        'Applied migrations are not in ascending order: $_previousApplied should not come before ${_applied!.current}.',
      );
    }
  }

  /// {@macro dmwmt.migrator.call}
  /// Throws a [ConcurrentModificationError] if the migrator is already [working].
  /// To prevent this, check [working] before calling this method.
  Future<void> call({required AsyncDatabase<D, T> db, required Iterator<AsyncMigration<D, T>> defined}) async {
    if (working) throw ConcurrentModificationError(this);

    await initialize(db, defined);

    try {
      await findLastCommonMigration();

      loop:
      while (true) {
        switch ((_hasDefined, _hasApplied)) {
          case (false, false):
            break loop;
          case (true, false):
            await applyRemainingDefinedMigrations();
          case (_, true):
            await rollbackRemainingAppliedMigrations();
        }
      }

      if (_inTransaction) {
        await _db!.commitTransaction();
      }
    } catch (e) {
      if (_inTransaction) {
        await _db!.rollbackTransaction();
      }
      rethrow;
    }

    log.fine('migration complete');

    reset();
  }

  /// {@macro dmwmt.migrator.initialize}
  @visibleForTesting
  Future<void> initialize(AsyncDatabase<D, T> db, Iterator<AsyncMigration<D, T>> defined) async {
    log.finer('initializing migrator...');

    _db = db;
    _defined = defined;
    _inTransaction = false;

    if (!await _db!.isMigrationsTableInitialized()) {
      log.fine('initializing migrations table');
      await _db!.initializeMigrationsTable();
    }

    _applied = StreamIterator(_db!.retrieveAllMigrations());
    _hasDefined = _defined!.moveNext();
    _hasApplied = await _applied!.moveNext();
  }

  /// {@macro dmwmt.migrator.findLastCommonMigration}
  @visibleForTesting
  Future<AsyncMigration<D, T>?> findLastCommonMigration() async {
    log.finer('finding last common migration...');
    AsyncMigration<D, T>? lastCommon;
    while (_hasDefined && _hasApplied && _defined!.current == _applied!.current) {
      lastCommon = _defined!.current;
      if (lastCommon.alwaysApply) {
        if (!_inTransaction) {
          log.finer('beginning transaction...');
          await _db!.beginTransaction();
          _inTransaction = true;
        }
        lastCommon.initialize(_db!.db);
        await _db!.performMigration(lastCommon.up);
      }
      _moveNextDefined();
      await _moveNextApplied();
    }

    if (lastCommon != null) {
      log.finer('last common migration: ${lastCommon.humanReadableId}');
    } else {
      log.finer('no common migrations found');
    }

    return lastCommon;
  }

  /// {@macro dmwmt.migrator.rollbackRemainingAppliedMigrations}
  @visibleForTesting
  Future<void> rollbackRemainingAppliedMigrations() async {
    log.fine('rolling back applied migrations...');

    if (!_hasApplied) {
      log.finer('no migrations to rollback');
      return;
    }

    final toRollback = [for (; _hasApplied; await _moveNextApplied()) _applied!.current].reversed.toList();

    if (!_inTransaction && toRollback.isNotEmpty) {
      log.finer('beginning transaction...');
      await _db!.beginTransaction();
      _inTransaction = true;
    }

    for (final migration in toRollback) {
      log.finer('|_ - migration ${migration.humanReadableId}');
      await _db!.performMigration(migration.down);
    }
    log.finest('updating applied migrations database table...');
    await _db!.removeMigrations(toRollback);
  }

  /// {@macro dmwmt.migrator.applyRemainingDefinedMigrations}
  @visibleForTesting
  Future<void> applyRemainingDefinedMigrations() async {
    log.fine('applying all remaining defined migrations');

    final toApply = List<AsyncMigration<D, T>>.empty(growable: true);
    final now = DateTime.now().toUtc();
    while (_hasDefined) {
      if (!_inTransaction) {
        log.finer('beginning transaction...');
        await _db!.beginTransaction();
        _inTransaction = true;
      }
      final migration = _defined!.current.copyWith(appliedAt: now);
      log.finer('|_ + migration ${migration.humanReadableId}');
      migration.initialize(_db!.db);
      await _db!.performMigration(migration.up);
      toApply.add(migration);
      _moveNextDefined();
    }
    log.finest('updating applied migrations database table...');
    await _db!.storeMigrations(toApply);
  }

  /// {@macro dmwmt.migrator}
  @visibleForTesting
  void reset() {
    _defined = null;
    _applied = null;
    _hasDefined = false;
    _hasApplied = false;
    _previousDefined = null;
    _previousApplied = null;
    _db = null;
    log.finer('migrator resetted');
  }
}
