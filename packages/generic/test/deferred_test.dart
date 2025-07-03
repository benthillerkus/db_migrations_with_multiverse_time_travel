import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';
import 'package:test/test.dart';

import 'logging.dart';
import 'mock_database.dart';

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

  test("Initializing twice is forbidden", () {
    final mig = SyncMigration<void, String>.deferred(
      definedAt: DateTime.utc(2025, 3, 6),
      builder: (_) => (up: 'up', down: 'down'),
    );

    mig.buildInstructions(null);

    expect(() => mig.buildInstructions(null), throwsA(isA<AlreadyInitializedMigrationError>()));
  });

  test("Cannot call copyWith on uninitialized deferred migration", () {
    final mig = SyncMigration<void, String>.deferred(
      definedAt: DateTime.utc(2025, 3, 6),
      builder: (_) => (up: 'up', down: 'down'),
    );

    expect(() => mig.copyWith(appliedAt: DateTime.utc(2070)), throwsA(isA<UninitializedMigrationError>()));
  });

  group("Sync", () {
    test("Deferred migrations are being initialized during migration", () {
      log.info("Setting up stuff");
      makeSecondMigration() => SyncMigration<Map<Symbol, dynamic>, Symbol>.deferred(
            definedAt: DateTime.utc(2025, 4),
            ephemeral: true,
            builder: (db) {
              expect(db, contains(#first));
              if (db.containsKey(#second)) {
                db[#second] += 1;
              } else {
                db[#second] = 1;
              }
              return (up: #fourUp, down: #fourDown);
            },
          );

      expect(makeSecondMigration(), makeSecondMigration());
      expect(makeSecondMigration().hasInstructions, isFalse);

      final migrations = <SyncMigration<Map<Symbol, dynamic>, Symbol>>[
        SyncMigration.deferred(
          definedAt: DateTime.utc(2025, 3, 6),
          builder: (db) {
            expect(db, isEmpty);
            db[#first] = true;
            return (up: #oneUp, down: #oneDown);
          },
        ),
        makeSecondMigration(),
        SyncMigration(definedAt: DateTime.utc(2026), ephemeral: true, up: #twoUp, down: #twoDown),
        SyncMigration(definedAt: DateTime.utc(2036), up: #threeUp, down: #threeDown),
      ];

      log.info("Starting first migration");
      final migrator = SyncMigrator<dynamic, Symbol>();
      final db = SyncMockDatabase([], <Symbol, dynamic>{});
      migrator.call(db: db, defined: migrations.iterator);

      expect(db.db, allOf(containsPair(#first, true), containsPair(#second, 1)));

      log.info("Starting second migration");
      final db2 = SyncMockDatabase([], db.db);
      migrator.call(db: db2, defined: migrations.iterator);

      expect(
        db2.db,
        allOf(containsPair(#first, true), containsPair(#second, 1)),
        reason: "Deferred migrations should not be re-initialized if they have already been run.",
      );

      expect(
        migrations,
        everyElement(
          isA<SyncMigration<Map<Symbol, dynamic>, Symbol>>()
              .having((m) => m.hasInstructions, "has instructions", isTrue),
        ),
      );

      log.info("Starting third migration");
      // "Reset" the second migration so that it's uninitialized again.
      migrations.replaceRange(1, 2, [makeSecondMigration()]);
      expect(migrations[1].hasInstructions, isFalse);
      expect(migrations, hasLength(4));

      db.migrate(migrations);

      expect(db.db, allOf(containsPair(#first, true), containsPair(#second, 2)));
    });
  });
}
