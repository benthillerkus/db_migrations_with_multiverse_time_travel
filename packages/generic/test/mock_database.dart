import 'dart:async';

import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';
import 'package:logging/logging.dart';

typedef Mig = Migration<Null, Symbol>;

class MockDatabase implements MaybeAsyncDatabase<Null, Symbol> {
  MockDatabase([List<Mig>? applied])
      : applied = applied ?? List.empty(growable: true),
        appliedForRollback = List.empty(growable: true),
        performedMigrations = List.empty(growable: true),
        migrationsTableInitialized = false,
        log = Logger('db.mock');

  final List<Mig> applied;
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
  FutureOr<void> storeMigrations(List<Mig> migration) {
    applied.addAll(migration);
  }

  @override
  FutureOr<void> removeMigrations(List<Mig> migrations) {
    for (final migration in migrations) {
      log.fine('removing migration ${migration.humanReadableId} from database...');
      if (!applied.remove(migration)) {
        throw StateError('migration could not be removed: not found in database');
      }
    }
  }

  final List<Mig> appliedForRollback;

  @override
  FutureOr<void> beginTransaction() {
    appliedForRollback.clear();
    appliedForRollback.addAll(applied);
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
  SyncMockDatabase([super.applied]);

  @override
  Iterator<Mig> retrieveAllMigrations() {
    return applied.iterator;
  }
}

class AsyncMockDatabase extends MockDatabase implements AsyncDatabase<Null, Symbol> {
  AsyncMockDatabase([super.applied]);

  @override
  Stream<Mig> retrieveAllMigrations() {
    return Stream.fromIterable(applied);
  }
}
