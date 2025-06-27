import 'dart:async';

import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';
import 'package:logging/logging.dart';

typedef Db = void;
typedef EmptyMigration = SyncMigration<Db, Symbol>;
typedef StaticEmptyMigration = StaticSyncMigration<Db, Symbol>;
typedef EmptyAsyncMigration = AsyncMigration<Db, Symbol>;
typedef StaticEmptyAsyncMigration = StaticAsyncMigration<Db, Symbol>;

class MockDatabase<B extends MaybeAsyncMigrationBuilder<Db, Symbol, B, O>, O>
    implements MaybeAsyncDatabase<Db, Symbol, B, O> {
  MockDatabase([List<StaticMigration<Db, Symbol, B, O>>? applied])
      : applied = applied ?? List.empty(growable: true),
        appliedForRollback = List.empty(growable: true),
        performedMigrations = List.empty(growable: true),
        migrationsTableInitialized = false,
        log = Logger('db.mock');

  final List<StaticMigration<void, Symbol, B, O>> applied;
  final Logger log;
  bool migrationsTableInitialized;

  @override
  FutureOr<void> initializeMigrationsTable() {
    migrationsTableInitialized = true;
  }

  @override
  bool isMigrationsTableInitialized() => migrationsTableInitialized;

  @override
  FutureOr<void> execute(Symbol migration) {
    log.info('performing migration', migration);
    performedMigrations.add(migration);
  }

  List<Symbol> performedMigrations;

  @override
  dynamic retrieveAllMigrations() {
    return applied.iterator;
  }

  final List<StaticMigration<Db, Symbol, B, O>> appliedForRollback;

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

  @override
  FutureOr<T> executeRaw<T>(FutureOr<T> Function(Db) action) {
    return action(null);
  }

  @override
  FutureOr<void> storeMigrations(List<StaticMigration<Db, Symbol, B, O>> migrations) {
    applied.addAll(migrations);
  }

  @override
  FutureOr<void> removeMigrations(List<Migration<Db, Symbol, B, O>> migrations) {
    for (final migration in migrations) {
      log.fine('removing migration ${migration.humanReadableId} from database...');
      if (!applied.remove(migration)) {
        throw StateError('migration could not be removed: not found in database');
      }
    }
  }
}

class SyncMockDatabase extends MockDatabase<SyncMigrationBuilder<Db, Symbol>, SO<Symbol>>
    implements SyncDatabase<Db, Symbol> {
  SyncMockDatabase([super.applied]);

  @override
  Iterator<StaticEmptyMigration> retrieveAllMigrations() {
    return applied.iterator;
  }

  @override
  T executeRaw<T>(T Function(Db) action) {
    return action(null);
  }
}

class AsyncMockDatabase extends MockDatabase<AsyncMigrationBuilder<Db, Symbol>, AO<Symbol>>
    implements AsyncDatabase<void, Symbol> {
  AsyncMockDatabase([super.applied]);

  @override
  Stream<StaticEmptyAsyncMigration> retrieveAllMigrations() {
    return Stream.fromIterable(applied);
  }
}
