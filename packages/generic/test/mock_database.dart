import 'package:db_migrations_with_multiverse_timetravel/db_migrations_with_multiverse_timetravel.dart';
import 'package:logging/logging.dart';

class MockDatabase<T> implements Database<T> {
  MockDatabase([List<Migration<T>>? applied])
    : applied = applied ?? List.empty(growable: true),
      log = Logger('db.mock');

  final List<Migration<T>> applied;
  final Logger log;

  @override
  void initializeMigrationsTable() {}

  @override
  bool isMigrationsTableInitialized() => true;

  @override
  void performMigration(T migration) {
    log.info('performing migration', migration);
  }

  @override
  Iterator<Migration<T>> retrieveAllMigrations() {
    return applied.iterator;
  }

  @override
  void storeMigrations(List<Migration<T>> migration) {
    applied.addAll(migration);
  }

  @override
  void removeMigrations(List<Migration<T>> migrations) {
    for (final migration in migrations) {
      log.fine('removing migration ${migration.humanReadableId} from database...');
      if (!applied.remove(migration)) {
        throw StateError('migration could not be removed: not found in database');
      }
    }
  }
}
