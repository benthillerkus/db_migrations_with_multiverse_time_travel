import 'migration.dart';
import 'database.dart';
import 'package:logging/logging.dart';

extension MigrateExt<T> on Database<T> {
  void migrate(List<Migration<T>> migrations) {
    final log = Logger('db.migrate');
    if (!isMigrationsTableInitialized()) {
      log.fine('initializing migrations table');
      initializeMigrationsTable();
    }

    final appliedMigrations = readAllMigrations();

    {
      final defined = migrations.iterator;
      final applied = appliedMigrations.iterator;
      Migration<T>? lastCommon;

      // Find the last common migration between defined and applied migrations.
      log.finer('finding last common migration...');
      while (true) {
        final hasDefined = defined.moveNext();
        final hasApplied = applied.moveNext();

        if (!hasDefined || !hasApplied) break;

        if (defined.current == applied.current) {
          lastCommon = defined.current;
          continue;
        }

        break;
      }
    }
  }
}
