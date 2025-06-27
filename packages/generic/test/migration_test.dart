import 'package:test/test.dart';

import 'logging.dart';
import 'mock_database.dart';

void main() {
  setUpAll(() {
    setUpLogging();
  });

  final migration = EmptyMigration(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down);

  test('UTC', () {
    final a = DateTime(2025, 3, 6);
    if (a.timeZoneOffset == Duration.zero) markTestSkipped("This test won't work inside of UTC");

    final b = DateTime.utc(2025, 3, 6);
    expect(a, isNot(b));
  });

  test('Throw if not UTC', () {
    expect(() => EmptyMigration(definedAt: DateTime(2025, 3, 6), up: #up, down: #down), throwsA(isA<ArgumentError>()));
  });

  test('DateTime is being preserved', () {
    expect(migration.definedAt, DateTime.utc(2025, 3, 6));
  });

  test('Dataclass-ish equality', () {
    final migration2 = EmptyMigration(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down);
    final migration3 = EmptyMigration(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down);

    expect(migration, migration2);
    expect(migration, isNot(migration3));
  });

  test('Equality is defined by definedAt', () {
    final migration = EmptyMigration(definedAt: DateTime.utc(2025, 3, 6), up: #o, down: #o);
    final migration2 = EmptyMigration(definedAt: DateTime.utc(2025, 3, 6), up: #i, down: #i);
    final migration3 = EmptyMigration(definedAt: DateTime.utc(2025, 3, 7), up: #o, down: #o);

    expect(migration, migration2);
    expect(migration, isNot(migration3));
  });

  test('Hashcode is correctly implemented', () {
    final migration = EmptyMigration(definedAt: DateTime.utc(1970, 0, 1), up: #up, down: #down);

    expect({migration}, contains(migration));
  });

  test('Order is defined by definedAt', () {
    final migration1 = EmptyMigration(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down);
    final migration2 = EmptyMigration(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down);
    final migration3 = EmptyMigration(definedAt: DateTime.utc(2025, 3, 8), up: #up, down: #down);

    expect(migration1 < migration2, isTrue);
    expect(migration2 > migration1, isTrue);
    expect(migration1 >= migration1, isTrue);
    expect(migration3 <= migration3, isTrue);
  });

  test('Undo', () {
    final migration = EmptyMigration(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down) as StaticEmptyMigration;
    final undoMigration =
        EmptyMigration.undo(definedAt: DateTime.utc(2025, 3, 9), migration: migration) as StaticEmptyMigration;

    expect(undoMigration.up, migration.down);
    expect(undoMigration.down, migration.up);
  });
}
