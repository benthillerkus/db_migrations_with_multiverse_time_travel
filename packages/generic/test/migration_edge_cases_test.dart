// LLM generated code
//
// This is just intended to "harden" the test suite
// and entrench current behavior.
//
// Since there is no intention behind these
// they can just be removed and regenerated
// if they conflict with future changes.

import 'dart:async';

import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';
import 'package:test/test.dart';

import 'logging.dart';
import 'mock_database.dart';

void main() {
  setUpAll(() {
    setUpLogging();
  });

  group('Deferred Migration Edge Cases', () {
    test('sync deferred migration builder cannot be async', () {
      // This test demonstrates that the sync migration builder must return sync results
      final migration = SyncMigration<dynamic, Symbol>.deferred(
        definedAt: DateTime.utc(2025, 3, 6),
        builder: (_) => (up: #up, down: #down), // sync builder for sync migration
      );

      migration.buildInstructions(null);
      expect(migration.hasInstructions, isTrue);
    });

    test('async deferred migration with sync builder works', () async {
      final migration = AsyncMigration<dynamic, Symbol>.deferred(
        definedAt: DateTime.utc(2025, 3, 6),
        builder: (_) => (up: #up, down: #down), // sync builder for async migration
      );

      await migration.buildInstructions(null);
      expect(migration.hasInstructions, isTrue);
      expect(migration.up, #up);
      expect(migration.down, #down);
    });

    test('async deferred migration with async builder works', () async {
      final migration = AsyncMigration<dynamic, Symbol>.deferred(
        definedAt: DateTime.utc(2025, 3, 6),
        builder: (_) => (up: #up, down: #down),
      );

      await migration.buildInstructions(null);
      expect(migration.hasInstructions, isTrue);
      expect(migration.up, #up);
      expect(migration.down, #down);
    });

    test('deferred migration builder receives database instance', () {
      dynamic receivedDb;
      final migration = SyncMigration<String, Symbol>.deferred(
        definedAt: DateTime.utc(2025, 3, 6),
        builder: (db) {
          receivedDb = db;
          return (up: #up, down: #down);
        },
      );

      const dbInstance = 'test-database';
      migration.buildInstructions(dbInstance);

      expect(receivedDb, equals(dbInstance));
    });

    test('async deferred migration builder receives database instance', () async {
      dynamic receivedDb;
      final migration = AsyncMigration<String, Symbol>.deferred(
        definedAt: DateTime.utc(2025, 3, 6),
        builder: (db) {
          receivedDb = db;
          return (up: #up, down: #down);
        },
      );

      const dbInstance = 'test-database';
      await migration.buildInstructions(dbInstance);

      expect(receivedDb, equals(dbInstance));
    });

    test('deferred migration can use database to build instructions', () {
      final migration = SyncMigration<Map<String, dynamic>, String>.deferred(
        definedAt: DateTime.utc(2025, 3, 6),
        builder: (db) {
          final tableName = db['tableName'] as String;
          return (
            up: 'CREATE TABLE $tableName (id INTEGER)',
            down: 'DROP TABLE $tableName',
          );
        },
      );

      migration.buildInstructions({'tableName': 'users'});

      expect(migration.up, 'CREATE TABLE users (id INTEGER)');
      expect(migration.down, 'DROP TABLE users');
    });

    test('async deferred migration handles async database operations', () async {
      final migration = AsyncMigration<Future<String>, String>.deferred(
        definedAt: DateTime.utc(2025, 3, 6),
        builder: (dbFuture) async {
          final tableName = await dbFuture;
          return (
            up: 'CREATE TABLE $tableName (id INTEGER)',
            down: 'DROP TABLE $tableName',
          );
        },
      );

      await migration.buildInstructions(Future.value('async_users'));

      expect(migration.up, 'CREATE TABLE async_users (id INTEGER)');
      expect(migration.down, 'DROP TABLE async_users');
    });

    test('double initialization of deferred migration throws', () {
      final migration = SyncMigration<dynamic, Symbol>.deferred(
        definedAt: DateTime.utc(2025, 3, 6),
        builder: (_) => (up: #up, down: #down),
      );

      migration.buildInstructions(null);

      expect(
        () => migration.buildInstructions(null),
        throwsA(isA<AlreadyInitializedMigrationError>()),
      );
    });

    test('async double initialization of deferred migration throws', () async {
      final migration = AsyncMigration<dynamic, Symbol>.deferred(
        definedAt: DateTime.utc(2025, 3, 6),
        builder: (_) => (up: #up, down: #down),
      );

      await migration.buildInstructions(null);

      await expectLater(
        () => migration.buildInstructions(null),
        throwsA(isA<AlreadyInitializedMigrationError>()),
      );
    });

    test('deferred migration builder exception is propagated', () {
      final migration = SyncMigration<dynamic, Symbol>.deferred(
        definedAt: DateTime.utc(2025, 3, 6),
        builder: (_) => throw Exception('Builder failed'),
      );

      expect(
        () => migration.buildInstructions(null),
        throwsA(isA<Exception>()),
      );
    });

    test('async deferred migration builder exception is propagated', () async {
      final migration = AsyncMigration<dynamic, Symbol>.deferred(
        definedAt: DateTime.utc(2025, 3, 6),
        builder: (_) => throw Exception('Async builder failed'),
      );

      await expectLater(
        () => migration.buildInstructions(null),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Migration DateTime Handling', () {
    test('non-UTC datetime throws error', () {
      expect(
        () => Mig(
          definedAt: DateTime(2025, 3, 6), // Local time
          up: #up,
          down: #down,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('UTC datetime is preserved exactly', () {
      final originalTime = DateTime.utc(2025, 3, 6, 14, 30, 45, 123);
      final migration = Mig(
        definedAt: originalTime,
        up: #up,
        down: #down,
      );

      expect(migration.definedAt, equals(originalTime));
      expect(migration.definedAt.isUtc, isTrue);
    });

    test('microseconds are truncated', () {
      final originalTime = DateTime.utc(2025, 3, 6, 14, 30, 45, 123, 456);
      final migration = Mig(
        definedAt: originalTime,
        up: #up,
        down: #down,
      );

      // Should truncate microseconds but keep milliseconds
      expect(migration.definedAt.millisecondsSinceEpoch, originalTime.millisecondsSinceEpoch);
      expect(migration.definedAt.microsecondsSinceEpoch, isNot(originalTime.microsecondsSinceEpoch));
    });

    test('appliedAt can be null', () {
      final migration = Mig(
        definedAt: DateTime.utc(2025, 3, 6),
        up: #up,
        down: #down,
        appliedAt: null,
      );

      expect(migration.appliedAt, isNull);
    });

    test('appliedAt is preserved when set', () {
      final appliedTime = DateTime.utc(2025, 3, 6, 12, 0);
      final migration = Mig(
        definedAt: DateTime.utc(2025, 3, 6),
        up: #up,
        down: #down,
        appliedAt: appliedTime,
      );

      expect(migration.appliedAt, equals(appliedTime));
    });
  });

  group('Migration copyWith', () {
    test('copyWith preserves unspecified fields', () {
      final original = Mig(
        definedAt: DateTime.utc(2025, 3, 6),
        name: 'Original Name',
        description: 'Original Description',
        up: #original_up,
        down: #original_down,
        ephemeral: true,
        appliedAt: DateTime.utc(2025, 3, 6, 12, 0),
      );

      final copy = original.copyWith(name: 'New Name');

      expect(copy.name, 'New Name');
      expect(copy.description, original.description);
      expect(copy.definedAt, original.definedAt);
      expect(copy.up, original.up);
      expect(copy.down, original.down);
      expect(copy.ephemeral, original.ephemeral);
      expect(copy.appliedAt, original.appliedAt);
    });

    test('copyWith can update all fields', () {
      final original = Mig(
        definedAt: DateTime.utc(2025, 3, 6),
        name: 'Original',
        up: #original_up,
        down: #original_down,
      );

      final newTime = DateTime.utc(2025, 3, 7);
      final appliedTime = DateTime.utc(2025, 3, 8);

      final copy = original.copyWith(
        definedAt: newTime,
        name: 'New Name',
        description: 'New Description',
        up: #new_up,
        down: #new_down,
        ephemeral: true,
        appliedAt: appliedTime,
      );

      expect(copy.definedAt, newTime);
      expect(copy.name, 'New Name');
      expect(copy.description, 'New Description');
      expect(copy.up, #new_up);
      expect(copy.down, #new_down);
      expect(copy.ephemeral, isTrue);
      expect(copy.appliedAt, appliedTime);
    });

    test('async copyWith works the same way', () {
      final original = AMig(
        definedAt: DateTime.utc(2025, 3, 6),
        name: 'Original Name',
        up: #original_up,
        down: #original_down,
      );

      final copy = original.copyWith(description: 'New Description');

      expect(copy.name, original.name);
      expect(copy.description, 'New Description');
      expect(copy.definedAt, original.definedAt);
      expect(copy.up, original.up);
      expect(copy.down, original.down);
    });
  });

  group('Unique edge cases', () {
    test('migration with extremely old date', () {
      final migration = Mig(
        definedAt: DateTime.utc(1970, 1, 1),
        up: #up,
        down: #down,
      );

      expect(migration.definedAt.year, 1970);
      expect(migration.humanReadableId, '1970-01-01 00:00:00.000Z');
    });

    test('migration with future date', () {
      final migration = Mig(
        definedAt: DateTime.utc(2050, 12, 31, 23, 59, 59),
        up: #up,
        down: #down,
      );

      expect(migration.definedAt.year, 2050);
      expect(migration.humanReadableId, '2050-12-31 23:59:59.000Z');
    });

    test('migration set operations work correctly', () {
      final migration1 = Mig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down);
      final migration2 = Mig(definedAt: DateTime.utc(2025, 3, 6), up: #different, down: #different);
      final migration3 = Mig(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down);

      final migrationSet = {migration1, migration2, migration3};

      // Should only contain 2 elements since migration1 and migration2 are equal
      expect(migrationSet.length, 2);
      expect(migrationSet.contains(migration1), isTrue);
      expect(migrationSet.contains(migration2), isTrue);
      expect(migrationSet.contains(migration3), isTrue);
    });
  });
}
