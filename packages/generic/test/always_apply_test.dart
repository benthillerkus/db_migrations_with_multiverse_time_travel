import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';
import 'package:test/test.dart';

import 'logging.dart';
import 'mock_database.dart';

void main() {
  setUpAll(() {
    setUpLogging();
  });

  group("Sync", () {
    final migrator = SyncMigrator<dynamic, Symbol>();

    test("Some always apply", () {
      final defined = [
        Mig(definedAt: DateTime.utc(2025, 3, 6), up: #migration1, down: #rollback1, alwaysApply: true),
        Mig(definedAt: DateTime.utc(2025, 3, 7), up: #migration2, down: #rollback2, alwaysApply: false),
        Mig(definedAt: DateTime.utc(2025, 3, 8), up: #migration3, down: #rollback3, alwaysApply: true),
      ];
      final db = SyncMockDatabase(defined);

      migrator.call(db: db, defined: defined.iterator);
      expect(
          db.performedMigrations, allOf(containsAllInOrder([#migration1, #migration3]), isNot(contains(#migration2))));
    });
  });

  group("Async", () {
    final migrator = AsyncMigrator<dynamic, Symbol>();

    test("Some always apply", () async {
      final defined = [
        AMig(definedAt: DateTime.utc(2025, 3, 6), up: #migration1, down: #rollback1, alwaysApply: true),
        AMig(definedAt: DateTime.utc(2025, 3, 7), up: #migration2, down: #rollback2, alwaysApply: false),
        AMig(definedAt: DateTime.utc(2025, 3, 8), up: #migration3, down: #rollback3, alwaysApply: true),
      ];
      final db = AsyncMockDatabase(defined);

      await migrator.call(db: db, defined: defined.iterator);
      expect(
          db.performedMigrations, allOf(containsAllInOrder([#migration1, #migration3]), isNot(contains(#migration2))));
    });
  });
}
