import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import 'database.dart';
import 'migration.dart';

/// An extension on [Database] that adds a [migrate] method.
extension SyncMigrateExt<T> on SyncDatabase<T> {
  /// Migrates the database using the given [migrations].
  void migrate(List<Migration<T>> migrations) {
    SyncMigrator<T>()(db: this, defined: migrations.iterator);
  }
}

/// A migrator that applies and rolls back migrations.
///
/// Use [call] to perform a schema update.
// Unfortunatly this ended up being an object instead of a function
// but this made it easier to test
class SyncMigrator<T> {
  /// Creates a new [SyncMigrator] with an optional [logger].
  ///
  /// The [logger] is used to log messages during the migration process.
  /// If no [Logger] is provided, a new logger named 'db.migrate' is created.
  SyncMigrator({Logger? logger})
      : log = logger ?? Logger('db.migrate'),
        _hasDefined = false,
        _hasApplied = false;

  /// The logger used during migrations.
  ///
  /// Conforms to the [Logger] class from the `logging` package.
  ///
  /// Defaults to a logger named 'db.migrate'.
  final Logger log;

  SyncDatabase<T>? _db;

  /// The migrations that are defined in code.
  Iterator<Migration<T>>? _defined;

  /// The migrations that have been applied to the database.
  Iterator<Migration<T>>? _applied;

  /// Whether there are any [_defined] migrations left to apply.
  ///
  /// This is the result of [_defined.moveNext].
  bool _hasDefined;

  /// Whether there are any [_applied] migrations left to rollback.
  ///
  /// This is the result of [_applied.moveNext].
  bool _hasApplied;

  /// The previous migration obtained from [_defined] before calling [_defined.moveNext].
  ///
  /// Used to ensure that migrations are being iterated in the correct order.
  Migration<T>? _previousDefined;

  /// The previous migration obtained from [_applied] before calling [_applied.moveNext].
  ///
  /// Used to ensure that migrations are being iterated in the correct order.
  Migration<T>? _previousApplied;

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

  /// Makes the migrator work with the given database and migrations.
  ///
  /// Throws a [StateError] if the [Migration]s in [defined] are not in ascending order.
  /// Throws a [StateError] the [Migration]s obtained from the db are not in ascending order.
  /// Throws a [ConcurrentModificationError] if the migrator is already [working].
  /// To prevent this, check [working] before calling this method.
  void call({required SyncDatabase<T> db, required Iterator<Migration<T>> defined}) {
    initialize(db, defined);
    // [_defined] and [_applied] are moved to the first migration

    _db!.beginTransaction();
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

      _db!.commitTransaction();
    } catch (e) {
      _db!.rollbackTransaction();
      rethrow;
    }

    log.fine('migration complete');

    reset();
  }

  /// Sets up the migrator to work with the given database and migrations.
  ///
  /// Throws a [ConcurrentModificationError] if the migrator is already [working].
  @visibleForTesting
  void initialize(SyncDatabase<T> db, Iterator<Migration<T>> defined) {
    log.finer('initializing migrator...');

    _db = db;
    _defined = defined;

    if (!_db!.isMigrationsTableInitialized()) {
      log.fine('initializing migrations table');
      _db!.initializeMigrationsTable();
    }

    _applied = db.retrieveAllMigrations();
    _hasDefined = _defined!.moveNext();
    _hasApplied = _applied!.moveNext();
  }

  /// Find the last common migration between defined and applied migrations.
  ///
  /// The last common migration is the last (going forwards in time) migration that is both defined and applied.
  @visibleForTesting
  Migration<T>? findLastCommonMigration() {
    log.finer('finding last common migration...');
    Migration<T>? lastCommon;
    while (_hasDefined && _hasApplied && _defined!.current == _applied!.current) {
      lastCommon = _defined!.current;
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

  /// Rollback all incoming [_applied] migrations.
  ///
  /// This is done in reverse order: the last applied [Migration] is rolled back first.
  ///
  /// The migrations are then removed from the migrations table in the [Database].
  @visibleForTesting
  void rollbackRemainingAppliedMigrations() {
    log.fine('rolling back applied migrations...');

    if (!_hasApplied) {
      log.finer('no migrations to rollback');
      return;
    }

    final toRollback = [for (; _hasApplied; _moveNextApplied()) _applied!.current].reversed.toList();

    for (final migration in toRollback) {
      log.finer('|_ - migration ${migration.humanReadableId}');
      _db!.performMigration(migration.down);
    }
    log.finest('updating applied migrations database table...');
    _db!.removeMigrations(toRollback);
  }

  /// Apply all remaining defined migrations.
  ///
  /// The migrations are applied in order: the first defined [Migration] is applied first.
  ///
  /// The migrations are then added to the migrations table in the [Database].
  @visibleForTesting
  void applyRemainingDefinedMigrations() {
    log.fine('applying all remaining defined migrations');

    final toApply = List<Migration<T>>.empty(growable: true);
    final now = DateTime.now().toUtc();
    while (_hasDefined) {
      final migration = _defined!.current.copyWith(appliedAt: now);
      log.finer('|_ + migration ${migration.humanReadableId}');
      _db!.performMigration(migration.up);
      toApply.add(migration);
      _moveNextDefined();
    }
    log.finest('updating applied migrations database table...');
    _db!.storeMigrations(toApply);
  }

  /// Resets the migrator to its initial state, allowing it to be used again.
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
