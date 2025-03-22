import 'package:collection/collection.dart';
import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';
import 'package:test/test.dart';

import 'logging.dart';
import 'mock_database.dart';

void main() {
  setUpAll(() {
    setUpLogging();
  });

  final eq = IterableEquality<Migration<void>>();

  group("Sync", () {
    final migrator = SyncMigrator<void>();

    test("Empty", () {
      migrator.call(db: SyncMockDatabase(), defined: <Migration<void>>[].iterator);
    });

    test("Single migration", () {
      final defined = [Migration(definedAt: DateTime.utc(2025, 3, 6), up: null, down: null)];
      final db = SyncMockDatabase<void>();

      migrator.call(db: db, defined: defined.iterator);

      expect(eq.equals(defined, db.applied), isTrue);
    });

    test("Multiple migrations", () {
      final defined = [
        Migration(definedAt: DateTime.utc(2025, 3, 6), up: null, down: null),
        Migration(definedAt: DateTime.utc(2025, 3, 7), up: null, down: null),
        Migration(definedAt: DateTime.utc(2025, 3, 8), up: null, down: null),
      ];
      final db = SyncMockDatabase<void>();

      migrator.call(db: db, defined: defined.iterator);

      expect(eq.equals(defined, db.applied), isTrue);
    });

    test("Wrong order throws", () {
      final defined = [
        Migration(definedAt: DateTime.utc(2025, 3, 6), up: null, down: null),
        Migration(definedAt: DateTime.utc(2025, 3, 7), up: null, down: null),
        Migration(definedAt: DateTime.utc(2025, 3, 5), up: null, down: null),
      ];
      final db = SyncMockDatabase<void>();

      expect(() => migrator.call(db: db, defined: defined.iterator), throwsA(isA<StateError>()));

      // Ensure that the database is still empty (rollback was successful).
      expect(db.applied, isEmpty);
    });

    test('Rollback no common', () {
      final db = SyncMockDatabase([
        Migration(definedAt: DateTime.utc(2025, 3, 6), up: null, down: null),
        Migration(definedAt: DateTime.utc(2025, 3, 7), up: null, down: null),
        Migration(definedAt: DateTime.utc(2025, 3, 8), up: null, down: null),
      ]);

      SyncMigrator<Null>().call(db: db, defined: <Migration<Null>>[].iterator);

      expect(db.applied, isEmpty);
    });

    test('Rollback some common', () {
      final defined = [
        Migration(definedAt: DateTime.utc(2025, 3, 6), up: null, down: null),
        Migration(definedAt: DateTime.utc(2025, 3, 9), up: null, down: null),
      ];

      final db = SyncMockDatabase([
        Migration(definedAt: DateTime.utc(2025, 3, 6), up: null, down: null),
        Migration(definedAt: DateTime.utc(2025, 3, 7), up: null, down: null),
        Migration(definedAt: DateTime.utc(2025, 3, 8), up: null, down: null),
      ]);

      SyncMigrator<Null>().call(db: db, defined: defined.iterator);

      expect(eq.equals(db.applied, defined), isTrue);
    });
  });

  group("Async", () {
    final migrator = AsyncMigrator<void>();

    test("Empty", () async {
      await migrator.call(db: AsyncMockDatabase(), defined: <Migration<void>>[].iterator);
    });

    test("Single migration", () async {
      final defined = [Migration(definedAt: DateTime.utc(2025, 3, 6), up: null, down: null)];
      final db = AsyncMockDatabase<void>();

      await migrator.call(db: db, defined: defined.iterator);

      expect(eq.equals(defined, db.applied), isTrue);
    });

    test("Multiple migrations", () async {
      final defined = [
        Migration(definedAt: DateTime.utc(2025, 3, 6), up: null, down: null),
        Migration(definedAt: DateTime.utc(2025, 3, 7), up: null, down: null),
        Migration(definedAt: DateTime.utc(2025, 3, 8), up: null, down: null),
      ];
      final db = AsyncMockDatabase<void>();

      await migrator.call(db: db, defined: defined.iterator);

      expect(eq.equals(defined, db.applied), isTrue);
    });

    test("Wrong order throws", () async {
      final defined = [
        Migration(definedAt: DateTime.utc(2025, 3, 6), up: null, down: null),
        Migration(definedAt: DateTime.utc(2025, 3, 7), up: null, down: null),
        Migration(definedAt: DateTime.utc(2025, 3, 5), up: null, down: null),
      ];
      final db = AsyncMockDatabase<void>();

      await expectLater(() => migrator.call(db: db, defined: defined.iterator), throwsA(isA<StateError>()));

      // Ensure that the database is still empty (rollback was successful).
      expect(db.applied, isEmpty);
    });

    test('Rollback no common', () async {
      final db = AsyncMockDatabase([
        Migration(definedAt: DateTime.utc(2025, 3, 6), up: null, down: null),
        Migration(definedAt: DateTime.utc(2025, 3, 7), up: null, down: null),
        Migration(definedAt: DateTime.utc(2025, 3, 8), up: null, down: null),
      ]);

      await AsyncMigrator<Null>().call(db: db, defined: <Migration<Null>>[].iterator);

      expect(db.applied, isEmpty);
    });

    test('Rollback some common', () async {
      final defined = [
        Migration(definedAt: DateTime.utc(2025, 3, 6), up: null, down: null),
        Migration(definedAt: DateTime.utc(2025, 3, 9), up: null, down: null),
      ];

      final db = AsyncMockDatabase([
        Migration(definedAt: DateTime.utc(2025, 3, 6), up: null, down: null),
        Migration(definedAt: DateTime.utc(2025, 3, 7), up: null, down: null),
        Migration(definedAt: DateTime.utc(2025, 3, 8), up: null, down: null),
      ]);

      await AsyncMigrator<Null>().call(db: db, defined: defined.iterator);

      expect(eq.equals(db.applied, defined), isTrue);
    });
  });
}
