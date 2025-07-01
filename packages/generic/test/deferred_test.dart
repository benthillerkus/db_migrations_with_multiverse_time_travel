import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';
import 'package:test/test.dart';

import 'logging.dart';

void main() {
  setUpAll(() {
    setUpLogging();
  });

  test("Can directly access up on regular migration", () {
    final mig = SyncMigration<void, String>(
      definedAt: DateTime.utc(2025, 3, 6),
      up: 'up',
      down: 'down',
    );

    expect(mig.up, 'up');
    expect(mig.down, 'down');
  });

  test("Accessing up on uninitialized deferred migration throws", () {
    final mig = SyncMigration<void, String>.deferred(
      definedAt: DateTime.utc(2025, 3, 6),
      builder: (_) => (up: 'up', down: 'down'),
    );

    expect(() => mig.up, throwsA(isA<UninitializedMigrationError>()));
    expect(() => mig.down, throwsA(isA<UninitializedMigrationError>()));
  });

  test("Accessing up on initialized deferred migration works", () {
    final mig = SyncMigration<void, String>.deferred(
      definedAt: DateTime.utc(2025, 3, 6),
      builder: (_) => (up: 'up', down: 'down'),
    );

    mig.buildInstructions(null);

    expect(mig.up, 'up');
    expect(mig.down, 'down');
  });
}
