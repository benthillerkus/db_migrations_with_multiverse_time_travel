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
    final migrator = SyncMigrator<Null, Symbol>();
    final eq = IterableEquality<Mig>();

    test("Empty", () {
      migrator.call(db: SyncMockDatabase(), defined: <Mig>[].iterator);
    });

    test("Single migration", () {
      final defined = [Mig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down)];
      final db = SyncMockDatabase();

      migrator.call(db: db, defined: defined.iterator);

      expect(eq.equals(defined, db.applied), isTrue);
    });

    test("Multiple migrations", () {
      final defined = [
        Mig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        Mig(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
        Mig(definedAt: DateTime.utc(2025, 3, 8), up: #up, down: #down),
      ];
      final db = SyncMockDatabase();

      migrator.call(db: db, defined: defined.iterator);

      expect(eq.equals(defined, db.applied), isTrue);
    });

    test("Wrong order throws", () {
      final defined = [
        Mig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        Mig(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
        Mig(definedAt: DateTime.utc(2025, 3, 5), up: #up, down: #down),
      ];
      final db = SyncMockDatabase();

      expect(() => migrator.call(db: db, defined: defined.iterator), throwsA(isA<StateError>()));

      // Ensure that the database is still empty (rollback was successful).
      expect(db.applied, isEmpty);
    });

    test('Rollback no common', () {
      final db = SyncMockDatabase([
        Mig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        Mig(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
        Mig(definedAt: DateTime.utc(2025, 3, 8), up: #up, down: #down),
      ]);

      SyncMigrator<Null, Symbol>().call(db: db, defined: <Mig>[].iterator);

      expect(db.applied, isEmpty);
    });

    test('Rollback some common', () {
      final defined = [
        Mig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        Mig(definedAt: DateTime.utc(2025, 3, 9), up: #up, down: #down),
      ];

      final db = SyncMockDatabase([
        Mig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        Mig(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
        Mig(definedAt: DateTime.utc(2025, 3, 8), up: #up, down: #down),
      ]);

      SyncMigrator<Null, Symbol>().call(db: db, defined: defined.iterator);

      expect(eq.equals(db.applied, defined), isTrue);
    });
  });

  group("Async", () {
    final migrator = AsyncMigrator<Null, Symbol>();
    final eq = IterableEquality<AMig>();

    test("Empty", () async {
      await migrator.call(db: AsyncMockDatabase(), defined: <AMig>[].iterator);
    });

    test("Single migration", () async {
      final defined = [AMig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down)];
      final db = AsyncMockDatabase();

      await migrator.call(db: db, defined: defined.iterator);

      expect(eq.equals(defined, db.applied), isTrue);
    });

    test("Multiple migrations", () async {
      final defined = [
        AMig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        AMig(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
        AMig(definedAt: DateTime.utc(2025, 3, 8), up: #up, down: #down),
      ];
      final db = AsyncMockDatabase();

      await migrator.call(db: db, defined: defined.iterator);

      expect(eq.equals(defined, db.applied), isTrue);
    });

    test("Wrong order throws", () async {
      final defined = [
        AMig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        AMig(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
        AMig(definedAt: DateTime.utc(2025, 3, 5), up: #up, down: #down),
      ];
      final db = AsyncMockDatabase();

      await expectLater(() => migrator.call(db: db, defined: defined.iterator), throwsA(isA<StateError>()));

      // Ensure that the database is still empty (rollback was successful).
      expect(db.applied, isEmpty);
    });

    test('Rollback no common', () async {
      final db = AsyncMockDatabase([
        AMig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        AMig(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
        AMig(definedAt: DateTime.utc(2025, 3, 8), up: #up, down: #down),
      ]);

      await AsyncMigrator<Null, Symbol>().call(db: db, defined: <AMig>[].iterator);

      expect(db.applied, isEmpty);
    });

    test('Rollback some common', () async {
      final defined = [
        AMig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        AMig(definedAt: DateTime.utc(2025, 3, 9), up: #up, down: #down),
      ];

      final db = AsyncMockDatabase([
        AMig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        AMig(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
        AMig(definedAt: DateTime.utc(2025, 3, 8), up: #up, down: #down),
      ]);

      await AsyncMigrator<Null, Symbol>().call(db: db, defined: defined.iterator);

      expect(eq.equals(db.applied, defined), isTrue);
    });
  });
}
