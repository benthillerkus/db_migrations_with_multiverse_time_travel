import 'dart:async';

import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';
import 'package:logging/logging.dart';

typedef Mig = SyncMigration<Null, Symbol>;
typedef AMig = AsyncMigration<Null, Symbol>;

abstract class MockDatabase implements MaybeAsyncDatabase<Null, Symbol> {
  MockDatabase()
      : appliedForRollback = List.empty(growable: true),
        performedMigrations = List.empty(growable: true),
        migrationsTableInitialized = false,
        log = Logger('db.mock');

  @override
  Null db;

  List<dynamic> get applied;
  final Logger log;
  bool migrationsTableInitialized;

  @override
  FutureOr<void> initializeMigrationsTable() {
    migrationsTableInitialized = true;
  }

  @override
  bool isMigrationsTableInitialized() => migrationsTableInitialized;

  @override
  FutureOr<void> performMigration(Symbol migration) {
    log.info('performing migration', migration);
    performedMigrations.add(migration);
  }

  List<Symbol> performedMigrations;

  @override
  dynamic retrieveAllMigrations() {
    return applied.iterator;
  }

  @override
  FutureOr<void> storeMigrations(List<Migration<Null, Symbol>> migration) {
    applied.addAll(migration);
  }

  @override
  FutureOr<void> removeMigrations(List<Migration<Null, Symbol>> migrations) {
    for (final migration in migrations) {
      log.fine('removing migration ${migration.humanReadableId} from database...');
      if (!applied.remove(migration)) {
        throw StateError('migration could not be removed: not found in database');
      }
    }
  }

  final List<Migration<Null, Symbol>> appliedForRollback;

  @override
  FutureOr<void> beginTransaction() {
    appliedForRollback.clear();
    appliedForRollback.addAll(applied.cast());
  }

  @override
  FutureOr<void> commitTransaction() {
    appliedForRollback.clear();
  }

  @override
  FutureOr<void> rollbackTransaction() {
    applied.clear();
    applied.addAll(appliedForRollback);
    appliedForRollback.clear();
  }
}

class SyncMockDatabase extends MockDatabase implements SyncDatabase<Null, Symbol> {
  SyncMockDatabase([this.applied = const []]) : super();

  @override
  final List<Mig> applied;

  @override
  Iterator<Mig> retrieveAllMigrations() {
    return applied.iterator;
  }
}

class AsyncMockDatabase extends MockDatabase implements AsyncDatabase<Null, Symbol> {
  AsyncMockDatabase([this.applied = const []]) : super();

  @override
  final List<AMig> applied;

  @override
  Stream<AsyncMigration<Null, Symbol>> retrieveAllMigrations() {
    return Stream.fromIterable(applied.cast());
  }
}
