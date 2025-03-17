import 'package:collection/collection.dart';
import 'package:db_migrations_with_multiverse_timetravel/db_migrations_with_multiverse_timetravel.dart';
import 'package:test/test.dart';

import 'logging.dart';
import 'mock_database.dart';

void main() {
  setUpAll(() {
    setUpLogging();
  });

  final migrator = SyncMigrator();

  test("Empty", () {
    migrator.call(db: MockDatabase(), defined: <Migration>[].iterator);
  });

  test("Single migration", () {
    final defined = [Migration(definedAt: DateTime(2025, 3, 6), up: null, down: null)];
    final db = MockDatabase();

    migrator.call(db: db, defined: defined.iterator);

    expect(IterableEquality().equals(defined, db.applied), isTrue);
  });

  test("Multiple migrations", () {
    final defined = [
      Migration(definedAt: DateTime(2025, 3, 6), up: null, down: null),
      Migration(definedAt: DateTime(2025, 3, 7), up: null, down: null),
      Migration(definedAt: DateTime(2025, 3, 8), up: null, down: null),
    ];
    final db = MockDatabase();

    migrator.call(db: db, defined: defined.iterator);

    expect(IterableEquality().equals(defined, db.applied), isTrue);
  });

  test("Wrong order throws", () {
    final defined = [
      Migration(definedAt: DateTime(2025, 3, 6), up: null, down: null),
      Migration(definedAt: DateTime(2025, 3, 7), up: null, down: null),
      Migration(definedAt: DateTime(2025, 3, 5), up: null, down: null),
    ];
    final db = MockDatabase();

    expect(() => migrator.call(db: db, defined: defined.iterator), throwsA(isA<StateError>()));

    // Ensure that the database is still empty (rollback was successful).
    expect(db.applied, isEmpty);
  });

  test('Rollback no common', () {
    final db = MockDatabase([
      Migration(definedAt: DateTime(2025, 3, 6), up: null, down: null),
      Migration(definedAt: DateTime(2025, 3, 7), up: null, down: null),
      Migration(definedAt: DateTime(2025, 3, 8), up: null, down: null),
    ]);

    SyncMigrator<Null>().call(db: db, defined: <Migration<Null>>[].iterator);

    expect(db.applied, isEmpty);
  });

  test('Rollback some common', () {
    final defined = [
      Migration(definedAt: DateTime(2025, 3, 6), up: null, down: null),
      Migration(definedAt: DateTime(2025, 3, 9), up: null, down: null),
    ];

    final db = MockDatabase([
      Migration(definedAt: DateTime(2025, 3, 6), up: null, down: null),
      Migration(definedAt: DateTime(2025, 3, 7), up: null, down: null),
      Migration(definedAt: DateTime(2025, 3, 8), up: null, down: null),
    ]);

    SyncMigrator<Null>().call(db: db, defined: defined.iterator);

    expect(IterableEquality().equals(db.applied, defined), isTrue);
  });
}
