import 'migration.dart';
import 'database.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

extension MigrateExt<T> on Database<T> {
  void migrate(List<Migration<T>> migrations) {
    Migrator()(db: this, defined: migrations.iterator);
  }
}

class Migrator<T> {
  Migrator({Logger? logger})
    : log = logger ?? Logger('db.migrate'),
      _hasDefined = false,
      _hasApplied = false,
      _working = false;

  /// The logger used during migrations.
  ///
  /// Conforms to the [Logger] class from the `logging` package.
  ///
  /// Defaults to a logger named 'db.migrate'.
  final Logger log;

  /// A guard to prevent the [Migrator] from being used concurrently.
  bool _working;

  /// Whether the migrator is currently working.
  ///
  /// This is used to prevent the migrator from being used concurrently.
  /// Check this property before calling [call].
  bool get working => _working;

  late Database<T> _db;

  /// The migrations that are defined in code.
  late Iterator<Migration<T>> _defined;

  /// The migrations that have been applied to the database.
  late Iterator<Migration<T>> _applied;

  /// Whether there are any [_defined] migrations left to apply.
  ///
  /// This is the result of [_defined.moveNext].
  bool _hasDefined;

  /// Whether there are any [_applied] migrations left to rollback.
  ///
  /// This is the result of [_applied.moveNext].
  bool _hasApplied;

  /// Makes the migrator work with the given database and migrations.
  ///
  /// Throws a [StateError] if the migrator is already [working].
  /// To prevent this, check [working] before calling this method.
  void call({required Database<T> db, required Iterator<Migration<T>> defined}) {
    initialize(db, defined);
    // [_defined] and [_applied] are moved to the first migration

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

    log.fine('migration complete');

    reset();
  }

  /// Sets up the migrator to work with the given database and migrations.
  ///
  /// Throws a [StateError] if the migrator is already [working].
  @visibleForTesting
  void initialize(Database<T> db, Iterator<Migration<T>> defined) {
    log.finer('initializing migrator...');
    if (_working) {
      throw StateError('Migrator is already working.');
    }
    _working = true;

    _db = db;
    _defined = defined;

    if (!_db.isMigrationsTableInitialized()) {
      log.fine('initializing migrations table');
      _db.initializeMigrationsTable();
    }

    _applied = db.retrieveAllMigrations();
    _hasDefined = _defined.moveNext();
    _hasApplied = _applied.moveNext();
  }

  /// Find the last common migration between defined and applied migrations.
  ///
  /// The last common migration is the last (going forwards in time) migration that is both defined and applied.
  @visibleForTesting
  Migration<T>? findLastCommonMigration() {
    log.finer('finding last common migration...');
    Migration<T>? lastCommon;
    while (_hasDefined && _hasApplied && _defined.current == _applied.current) {
      lastCommon = _defined.current;
      _hasDefined = _defined.moveNext();
      _hasApplied = _applied.moveNext();
    }

    if (lastCommon != null) {
      log.finer('last common migration: ${lastCommon.humanReadableId}');
    } else {
      log.finer('no common migrations found');
    }

    return lastCommon;
  }

  /// Rollback all incoming applied migrations.
  @visibleForTesting
  void rollbackRemainingAppliedMigrations() {
    log.fine('rolling back applied migrations...');

    if (!_hasApplied) {
      log.finer('no migrations to rollback');
      return;
    }

    final toRollback =
        [for (; _hasApplied; _hasApplied = _applied.moveNext()) _applied.current].reversed.toList();

    for (final migration in toRollback) {
      log.finer('|_ - migration ${migration.humanReadableId}');
      _db.performMigration(migration.down);
    }
    log.finest('updating applied migrations database table...');
    _db.removeMigrations(toRollback);
  }

  @visibleForTesting
  void applyRemainingDefinedMigrations() {
    log.fine('applying all remaining defined migrations');

    final toApply = List<Migration<T>>.empty(growable: true);
    while (_hasDefined) {
      final migration = _defined.current;
      log.finer('|_ + migration ${migration.humanReadableId}');
      _db.performMigration(migration.up);
      toApply.add(migration);
      _hasDefined = _defined.moveNext();
    }
    log.finest('updating applied migrations database table...');
    _db.storeMigrations(toApply);
  }

  @visibleForTesting
  void reset() {
    _hasDefined = false;
    _hasApplied = false;
    _working = false;
    log.finer('migrator resetted');
  }
}
