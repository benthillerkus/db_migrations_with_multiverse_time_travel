import 'package:db_migrations_with_multiverse_timetravel/db_migrations_with_multiverse_timetravel.dart';
import 'package:test/test.dart';

void main() {
  final migration = Migration<void>(definedAt: DateTime(2025, 3, 6), up: null, down: null);

  test('DateTime is being preserved', () {
    expect(migration.definedAt.toLocal(), DateTime(2025, 3, 6));
  });

  test('Dataclass-ish equality', () {
    final migration2 = Migration<void>(definedAt: DateTime(2025, 3, 6), up: null, down: null);
    final migration3 = Migration<void>(definedAt: DateTime(2025, 3, 7), up: null, down: null);

    expect(migration, migration2);
    expect(migration, isNot(migration3));
  });

  
  test('Equality is defined by definedAt', () {
    final migration = Migration<int>(definedAt: DateTime(2025, 3, 6), up: 0, down: 0);
    final migration2 = Migration<int>(definedAt: DateTime(2025, 3, 6), up: 1, down: 1);
    final migration3 = Migration<int>(definedAt: DateTime(2025, 3, 7), up: 0, down: 0);

    expect(migration, migration2);
    expect(migration, isNot(migration3));
  });
}
