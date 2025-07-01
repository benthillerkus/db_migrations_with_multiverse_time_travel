import 'dart:async';

import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';
import 'package:logging/logging.dart';

typedef Mig = SyncMigration<Null, Symbol>;
typedef AMig = AsyncMigration<Null, Symbol>;

class SyncMockDatabase implements SyncDatabase<Null, Symbol> {
  SyncMockDatabase([List<Mig>? applied])
      : applied = applied ?? List.empty(growable: true),
        appliedForRollback = List.empty(growable: true),
        performedMigrations = List.empty(growable: true),
        migrationsTableInitialized = false,
        log = Logger('db.mock');

  @override
  final Null db = null;

  final List<Mig> applied;
  final List<Mig> appliedForRollback;
  final Logger log;
  bool migrationsTableInitialized;
  List<Symbol> performedMigrations;

  @override
  void initializeMigrationsTable() {
    migrationsTableInitialized = true;
  }

  @override
  bool isMigrationsTableInitialized() => migrationsTableInitialized;

  @override
  void performMigration(Symbol migration) {
    log.info('performing migration', migration);
    performedMigrations.add(migration);
  }

  @override
  Iterator<Mig> retrieveAllMigrations() {
    return applied.iterator;
  }

  @override
  void storeMigrations(List<Mig> migration) {
    applied.addAll(migration);
  }

  @override
  void removeMigrations(List<Mig> migrations) {
    for (final migration in migrations) {
      log.fine('removing migration ${migration.humanReadableId} from database...');
      if (!applied.remove(migration)) {
        throw StateError('migration could not be removed: not found in database');
      }
    }
  }

  @override
  void beginTransaction() {
    appliedForRollback.clear();
    appliedForRollback.addAll(applied);
  }

  @override
  void commitTransaction() {
    appliedForRollback.clear();
  }

  @override
  void rollbackTransaction() {
    applied.clear();
    applied.addAll(appliedForRollback);
    appliedForRollback.clear();
  }
}

class AsyncMockDatabase implements AsyncDatabase<Null, Symbol> {
  AsyncMockDatabase([List<AMig>? applied])
      : applied = applied ?? List.empty(growable: true),
        appliedForRollback = List.empty(growable: true),
        performedMigrations = List.empty(growable: true),
        migrationsTableInitialized = false,
        log = Logger('db.mock');

  @override
  final Null db = null;

  final List<AMig> applied;
  final List<AMig> appliedForRollback;
  final Logger log;
  bool migrationsTableInitialized;
  List<Symbol> performedMigrations;

  @override
  Future<void> initializeMigrationsTable() async {
    migrationsTableInitialized = true;
  }

  @override
  bool isMigrationsTableInitialized() => migrationsTableInitialized;

  @override
  Future<void> performMigration(Symbol migration) async {
    log.info('performing migration', migration);
    performedMigrations.add(migration);
  }

  @override
  Stream<AMig> retrieveAllMigrations() {
    return Stream.fromIterable(applied);
  }

  @override
  Future<void> storeMigrations(List<AMig> migration) async {
    applied.addAll(migration);
  }

  @override
  Future<void> removeMigrations(List<AMig> migrations) async {
    for (final migration in migrations) {
      log.fine('removing migration ${migration.humanReadableId} from database...');
      if (!applied.remove(migration)) {
        throw StateError('migration could not be removed: not found in database');
      }
    }
  }

  @override
  Future<void> beginTransaction() async {
    appliedForRollback.clear();
    appliedForRollback.addAll(applied);
  }

  @override
  Future<void> commitTransaction() async {
    appliedForRollback.clear();
  }

  @override
  Future<void> rollbackTransaction() async {
    applied.clear();
    applied.addAll(appliedForRollback);
    appliedForRollback.clear();
  }
}
