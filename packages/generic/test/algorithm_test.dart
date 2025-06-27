import 'package:collection/collection.dart';
import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';
import 'package:test/test.dart';

import 'logging.dart';
import 'mock_database.dart';

void main() {
  setUpAll(() {
    setUpLogging();
  });

  group("Sync", () {
    final eq = IterableEquality<EmptyMigration>();
    final migrator = SyncMigrator<void, void>();

    test("Empty", () {
      migrator.call(db: SyncMockDatabase(), defined: <EmptyMigration>[].iterator);
    });

    test("Single migration", () {
      final defined = [EmptyMigration(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down)];
      final db = SyncMockDatabase();

      migrator.call(db: db, defined: defined.iterator);

      expect(eq.equals(defined, db.applied), isTrue);
    });

    test("Multiple migrations", () {
      final defined = [
        EmptyMigration(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        EmptyMigration(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
        EmptyMigration(definedAt: DateTime.utc(2025, 3, 8), up: #up, down: #down),
      ];
      final db = SyncMockDatabase();

      migrator.call(db: db, defined: defined.iterator);

      expect(eq.equals(defined, db.applied), isTrue);
    });

    test("Wrong order throws", () {
      final defined = [
        EmptyMigration(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        EmptyMigration(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
        EmptyMigration(definedAt: DateTime.utc(2025, 3, 5), up: #up, down: #down),
      ];
      final db = SyncMockDatabase();

      expect(() => migrator.call(db: db, defined: defined.iterator), throwsA(isA<StateError>()));

      // Ensure that the database is still empty (rollback was successful).
      expect(db.applied, isEmpty);
    });

    test('Rollback no common', () {
      final db = SyncMockDatabase([
        StaticEmptyMigration(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        StaticEmptyMigration(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
        StaticEmptyMigration(definedAt: DateTime.utc(2025, 3, 8), up: #up, down: #down),
      ]);

      SyncMigrator<void, Symbol>().call(db: db, defined: <EmptyMigration>[].iterator);

      expect(db.applied, isEmpty);
    });

    test('Rollback some common', () {
      final defined = [
        EmptyMigration(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        EmptyMigration(definedAt: DateTime.utc(2025, 3, 9), up: #up, down: #down),
      ];

      final db = SyncMockDatabase([
        StaticEmptyMigration(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        StaticEmptyMigration(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
        StaticEmptyMigration(definedAt: DateTime.utc(2025, 3, 8), up: #up, down: #down),
      ]);

      SyncMigrator<void, Symbol>().call(db: db, defined: defined.iterator);

      expect(eq.equals(db.applied, defined), isTrue);
    });
  });

  group("Async", () {
    final eq = IterableEquality<EmptyAsyncMigration>();

    final migrator = AsyncMigrator<void, void>();

    test("Empty", () async {
      await migrator.call(db: AsyncMockDatabase(), defined: <EmptyAsyncMigration>[].iterator);
    });

    test("Single migration", () async {
      final defined = [EmptyAsyncMigration(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down)];
      final db = AsyncMockDatabase();

      await migrator.call(db: db, defined: defined.iterator);

      expect(eq.equals(defined, db.applied), isTrue);
    });

    test("Multiple migrations", () async {
      final defined = [
        EmptyAsyncMigration(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        EmptyAsyncMigration(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
        EmptyAsyncMigration(definedAt: DateTime.utc(2025, 3, 8), up: #up, down: #down),
      ];
      final db = AsyncMockDatabase();

      await migrator.call(db: db, defined: defined.iterator);

      expect(eq.equals(defined, db.applied), isTrue);
    });

    test("Wrong order throws", () async {
      final defined = [
        EmptyAsyncMigration(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        EmptyAsyncMigration(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
        EmptyAsyncMigration(definedAt: DateTime.utc(2025, 3, 5), up: #up, down: #down),
      ];
      final db = AsyncMockDatabase();

      await expectLater(() => migrator.call(db: db, defined: defined.iterator), throwsA(isA<StateError>()));

      // Ensure that the database is still empty (rollback was successful).
      expect(db.applied, isEmpty);
    });

    test('Rollback no common', () async {
      final db = AsyncMockDatabase([
        StaticEmptyAsyncMigration(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        StaticEmptyAsyncMigration(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
        StaticEmptyAsyncMigration(definedAt: DateTime.utc(2025, 3, 8), up: #up, down: #down),
      ]);

      await AsyncMigrator<void, Symbol>().call(db: db, defined: <EmptyAsyncMigration>[].iterator);

      expect(db.applied, isEmpty);
    });

    test('Rollback some common', () async {
      final defined = [
        EmptyAsyncMigration(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        EmptyAsyncMigration(definedAt: DateTime.utc(2025, 3, 9), up: #down, down: #down),
      ];

      final db = AsyncMockDatabase([
        StaticEmptyAsyncMigration(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        StaticEmptyAsyncMigration(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
        StaticEmptyAsyncMigration(definedAt: DateTime.utc(2025, 3, 8), up: #up, down: #down),
      ]);

      await AsyncMigrator<void, Symbol>().call(db: db, defined: defined.iterator);

      expect(eq.equals(db.applied, defined), isTrue);
    });
  });
}
