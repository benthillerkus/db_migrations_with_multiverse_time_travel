// LLM generated code
//
// This is just intended to "harden" the test suite
// and entrench current behavior.
//
// Since there is no intention behind these
// they can just be removed and regenerated
// if they conflict with future changes.

import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';
import 'package:test/test.dart';

import 'logging.dart';
import 'mock_database.dart';

void main() {
  setUpAll(() {
    setUpLogging();
  });

  group('Migration edge cases', () {
    test('migration with null name and description', () {
      final migration = Mig(
        definedAt: DateTime.utc(2025, 3, 6),
        up: #up,
        down: #down,
        name: null,
        description: null,
      );

      expect(migration.name, isNull);
      expect(migration.description, isNull);
      expect(migration.humanReadableId, '2025-03-06 00:00:00.000Z');
    });

    test('migration with custom name has readable id', () {
      final migration = Mig(
        definedAt: DateTime.utc(2025, 3, 6),
        up: #up,
        down: #down,
        name: 'Add Users Table',
      );

      expect(migration.humanReadableId, 'Add Users Table');
    });

    test('copyWith on uninitialized deferred migration throws', () {
      final migration = SyncMigration<dynamic, Symbol>.deferred(
        definedAt: DateTime.utc(2025, 3, 6),
        builder: (_) => (up: #up, down: #down),
      );

      expect(
        () => migration.copyWith(name: 'New Name'),
        throwsA(isA<UninitializedMigrationError>()),
      );
    });

    test('copyWith on initialized deferred migration works', () {
      final migration = SyncMigration<dynamic, Symbol>.deferred(
        definedAt: DateTime.utc(2025, 3, 6),
        builder: (_) => (up: #up, down: #down),
      );

      migration.buildInstructions(null);

      final copy = migration.copyWith(name: 'New Name');
      expect(copy.name, 'New Name');
      expect(copy.definedAt, migration.definedAt);
      expect(copy.up, migration.up);
      expect(copy.down, migration.down);
    });

    test('migration equality with different appliedAt times', () {
      final migration1 = Mig(
        definedAt: DateTime.utc(2025, 3, 6),
        up: #up,
        down: #down,
        appliedAt: DateTime.utc(2025, 3, 6, 12, 0),
      );

      final migration2 = Mig(
        definedAt: DateTime.utc(2025, 3, 6),
        up: #up,
        down: #down,
        appliedAt: DateTime.utc(2025, 3, 6, 13, 0),
      );

      // Equality is based on definedAt, not appliedAt
      expect(migration1, equals(migration2));
      expect(migration1.hashCode, equals(migration2.hashCode));
    });

    test('migration toString includes all fields', () {
      final migration = Mig(
        definedAt: DateTime.utc(2025, 3, 6),
        up: #up,
        down: #down,
        name: 'Test Migration',
        description: 'A test migration',
        appliedAt: DateTime.utc(2025, 3, 6, 12, 0),
        ephemeral: true,
      );

      final str = migration.toString();
      expect(str, contains('Test Migration'));
      expect(str, contains('A test migration'));
      expect(str, contains('2025-03-06 00:00:00.000Z'));
      expect(str, contains('2025-03-06 12:00:00.000Z'));
      expect(str, contains('true'));
    });

    test('migration comparison operators', () {
      final migration1 = Mig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down);
      final migration2 = Mig(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down);
      final migration3 = Mig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down);

      expect(migration1 < migration2, isTrue);
      expect(migration1 > migration2, isFalse);
      expect(migration1 <= migration2, isTrue);
      expect(migration1 >= migration2, isFalse);
      expect(migration1 <= migration3, isTrue);
      expect(migration1 >= migration3, isTrue);
    });
  });

  group('Always apply advanced scenarios', () {
    test('multiple ephemeral migrations in sequence', () {
      final migrator = SyncMigrator<dynamic, Symbol>();
      final defined = [
        Mig(definedAt: DateTime.utc(2025, 3, 6), up: #pragma1, down: #rollback1, ephemeral: true),
        Mig(definedAt: DateTime.utc(2025, 3, 7), up: #pragma2, down: #rollback2, ephemeral: true),
        Mig(definedAt: DateTime.utc(2025, 3, 8), up: #migration3, down: #rollback3, ephemeral: false),
        Mig(definedAt: DateTime.utc(2025, 3, 9), up: #pragma4, down: #rollback4, ephemeral: true),
      ];
      final db = SyncMockDatabase(defined.take(3).toList()); // Only first 3 applied

      migrator.call(db: db, defined: defined.iterator);

      // Should apply all ephemeral migrations and the new one
      expect(db.performedMigrations, containsAllInOrder([#pragma1, #pragma2, #pragma4]));
      expect(db.applied.length, 4);
    });

    test('ephemeral deferred migration', () {
      final migrator = SyncMigrator<dynamic, Symbol>();
      final defined = [
        SyncMigration<dynamic, Symbol>.deferred(
          definedAt: DateTime.utc(2025, 3, 6),
          builder: (_) => (up: #deferred_up, down: #deferred_down),
          ephemeral: true,
        ),
      ];
      final db = SyncMockDatabase(defined);

      migrator.call(db: db, defined: defined.iterator);

      // Should build and apply the deferred migration
      expect(db.performedMigrations, contains(#deferred_up));
    });

    test('ephemeral migration that fails still rolls back', () {
      final migrator = SyncMigrator<dynamic, Symbol>();
      final defined = [
        Mig(definedAt: DateTime.utc(2025, 3, 6), up: #working, down: #rollback, ephemeral: true),
        SyncMigration<dynamic, Symbol>.deferred(
          definedAt: DateTime.utc(2025, 3, 7),
          builder: (_) => throw Exception('Build failed'),
        ),
      ];
      final db = SyncMockDatabase(defined.take(1).toList());

      expect(() => migrator.call(db: db, defined: defined.iterator), throwsException);
      // Should have rolled back
      expect(db.applied.length, 1); // Original state restored
    });
  });

  group('Complex migration scenarios', () {
    test('partial rollback then apply new migrations', () {
      final migrator = SyncMigrator<dynamic, Symbol>();
      final defined = [
        Mig(definedAt: DateTime.utc(2025, 3, 6), up: #migration1, down: #rollback1),
        Mig(definedAt: DateTime.utc(2025, 3, 8), up: #migration3, down: #rollback3), // Skip 7
        Mig(definedAt: DateTime.utc(2025, 3, 10), up: #migration4, down: #rollback4),
      ];

      final applied = [
        Mig(definedAt: DateTime.utc(2025, 3, 6), up: #migration1, down: #rollback1),
        Mig(definedAt: DateTime.utc(2025, 3, 7), up: #migration2, down: #rollback2),
        Mig(definedAt: DateTime.utc(2025, 3, 9), up: #old_migration, down: #old_rollback),
      ];

      final db = SyncMockDatabase(applied);

      migrator.call(db: db, defined: defined.iterator);

      // Should rollback migrations 7 and 9, then apply 8 and 10
      // Rollbacks are in reverse order: latest first
      expect(db.performedMigrations, containsAllInOrder([#old_rollback, #rollback2, #migration3, #migration4]));
      expect(db.applied.length, 3);
      expect(db.applied.map((m) => m.definedAt), [
        DateTime.utc(2025, 3, 6),
        DateTime.utc(2025, 3, 8),
        DateTime.utc(2025, 3, 10),
      ]);
    });

    test('empty defined migrations with applied migrations rolls back everything', () {
      final migrator = SyncMigrator<dynamic, Symbol>();
      final applied = [
        Mig(definedAt: DateTime.utc(2025, 3, 6), up: #migration1, down: #rollback1),
        Mig(definedAt: DateTime.utc(2025, 3, 7), up: #migration2, down: #rollback2),
        Mig(definedAt: DateTime.utc(2025, 3, 8), up: #migration3, down: #rollback3),
      ];

      final db = SyncMockDatabase(applied);

      migrator.call(db: db, defined: <Mig>[].iterator);

      // Should rollback everything in reverse order
      expect(db.performedMigrations, [#rollback3, #rollback2, #rollback1]);
      expect(db.applied, isEmpty);
    });

    test('migrations with same definedAt time comparison', () {
      final time = DateTime.utc(2025, 3, 6);
      final migration1 = Mig(definedAt: time, up: #migration1, down: #rollback1);
      final migration2 = Mig(definedAt: time, up: #migration2, down: #rollback2);

      expect(migration1.compareTo(migration2), 0);
      expect(migration1 <= migration2, isTrue);
      expect(migration1 >= migration2, isTrue);
      expect(migration1 < migration2, isFalse);
      expect(migration1 > migration2, isFalse);
    });
  });

  group('AsyncMigrator working state', () {
    test('working property is false initially', () {
      final migrator = AsyncMigrator<dynamic, Symbol>();
      expect(migrator.working, isFalse);
    });

    test('working property is true during migration', () async {
      final migrator = AsyncMigrator<dynamic, Symbol>();
      final defined = [
        AMig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
      ];
      final db = AsyncMockDatabase();

      bool wasWorking = false;

      final future = migrator.call(db: db, defined: defined.iterator).then((_) {
        // After completion, should be false again
        expect(migrator.working, isFalse);
      });

      // During migration, should be true
      wasWorking = migrator.working;

      await future;
      expect(wasWorking, isTrue);
    });
  });
}
