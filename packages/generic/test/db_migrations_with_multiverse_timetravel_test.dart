import 'package:db_migrations_with_multiverse_timetravel/db_migrations_with_multiverse_timetravel.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    final migration = Migration<void>(definedAt: DateTime(2025, 3, 6), up: null, down: null);

    setUp(() {
      // Additional setup goes here.
    });

    test('DateTime is being preserved', () {
      expect(migration.definedAt.toLocal(), DateTime(2025, 3, 6));
    });
  });
}
