import 'dart:async';

import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';
import 'package:logging/logging.dart';

class MockDatabase<T> implements MaybeAsyncDatabase<T> {
  MockDatabase([List<Migration<T>>? applied])
      : applied = applied ?? List.empty(growable: true),
        appliedForRollback = List.empty(growable: true),
        performedMigrations = List.empty(growable: true),
        migrationsTableInitialized = false,
        log = Logger('db.mock');

  final List<Migration<T>> applied;
  final Logger log;
  bool migrationsTableInitialized;

  @override
  FutureOr<void> initializeMigrationsTable() {
    migrationsTableInitialized = true;
  }

  @override
  bool isMigrationsTableInitialized() => migrationsTableInitialized;

  @override
  FutureOr<void> performMigration(T migration) {
    log.info('performing migration', migration);
    performedMigrations.add(migration);
  }

  List<T> performedMigrations;

  @override
  dynamic retrieveAllMigrations() {
    return applied.iterator;
  }

  @override
  FutureOr<void> storeMigrations(List<Migration<T>> migration) {
    applied.addAll(migration);
  }

  @override
  FutureOr<void> removeMigrations(List<Migration<T>> migrations) {
    for (final migration in migrations) {
      log.fine('removing migration ${migration.humanReadableId} from database...');
      if (!applied.remove(migration)) {
        throw StateError('migration could not be removed: not found in database');
      }
    }
  }

  final List<Migration<T>> appliedForRollback;

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

class SyncMockDatabase<T> extends MockDatabase<T> implements SyncDatabase<T> {
  SyncMockDatabase([super.applied]);

  @override
  Iterator<Migration<T>> retrieveAllMigrations() {
    return applied.iterator;
  }
}

class AsyncMockDatabase<T> extends MockDatabase<T> implements AsyncDatabase<T> {
  AsyncMockDatabase([super.applied]);

  @override
  Stream<Migration<T>> retrieveAllMigrations() {
    return Stream.fromIterable(applied);
  }
}
