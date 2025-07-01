import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_migrations_with_multiverse_time_travel/sqflite_migrations_with_multiverse_time_travel.dart';
import 'package:test/test.dart';

void main() {
  late Database db;
  late SqfliteDatabase wrapper;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    wrapper = SqfliteDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Initialize works', () async {
    await wrapper.initializeMigrationsTable();
    expect(await wrapper.isMigrationsTableInitialized(), isTrue);
  });

  test('Initialize has table', () async {
    await wrapper.initializeMigrationsTable();
    expect(await db.rawQuery('select * from sqlite_master where type = "table" and name = "migrations"'), isNotEmpty);
  });

  group('After initialization', () {
    setUp(() async {
      await wrapper.initializeMigrationsTable();
    });

    group('Insert migration', () {
      test('Insertion', () async {
        final migration = Migration(
          definedAt: DateTime.utc(2021, 1, 1),
          name: 'test',
          description: 'test',
          appliedAt: DateTime.utc(2021, 1, 1, 12, 31),
          up: 'CREATE TABLE tbl (a TEXT)',
          down: 'DROP TABLE tbl',
        );
        await wrapper.storeMigrations([migration].cast());

        final result = await db.query('migrations');
        expect(result, hasLength(1));
        expect(result[0], containsPair('defined_at', migration.definedAt.millisecondsSinceEpoch));
        expect(result[0], containsPair('name', migration.name));
        expect(result[0], containsPair('description', migration.description));
        expect(result[0], containsPair('applied_at', migration.appliedAt!.millisecondsSinceEpoch));
        expect(result[0], containsPair('up', migration.up));
        expect(result[0], containsPair('down', migration.down));
      });
    });

    group('Always apply', () {
      final migrations = <Migration>[
        Migration(name: 'Create users and notes tables', definedAt: DateTime.utc(2025, 6, 23), up: '''
CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT);
CREATE TABLE notes (id INTEGER PRIMARY KEY AUTOINCREMENT, note TEXT, user_id INTEGER, FOREIGN KEY (user_id) REFERENCES users (id));
''', down: '''
DROP TABLE notes;
DROP TABLE users;
'''),
        Migration(name: 'Insert users', definedAt: DateTime.utc(2025, 6, 23, 12, 0), up: '''
INSERT INTO users (name) VALUES ('Alice'), ('Bob'), ('Charlie');
''', down: '''
DELETE FROM users WHERE name IN ('Alice', 'Bob', 'Charlie');
'''),
        Migration(name: 'Insert notes', definedAt: DateTime.utc(2025, 6, 23, 12, 1), up: '''
INSERT INTO notes (note, user_id) VALUES ('is cool', 1), ('sucks', 2), ('is awesome', 1);
''', down: '''
DELETE FROM notes WHERE note IN ('is cool', 'sucks', 'is awesome');
'''),
      ];

      test('Basic', () async {
        await expectLater(() => db.query('notes'), throwsA(anything),
            reason: 'Database should not have notes table before migration');

        await wrapper.migrate(migrations);

        final result = await db.query('notes');
        expect(result, hasLength(3));
      });

      group("Insert orphan", () {
        test("Foreign keys aren't enforced by default", () async {
          await wrapper.migrate(migrations);

          // Insert a note with a non-existing user_id
          await db.execute('INSERT INTO notes (note, user_id) VALUES (?, ?)', ['orphan note', 999]);

          final result = await db.query('notes');
          expect(result, hasLength(4)); // Should include the orphan note
        });

        test("Throws when foreign keys are enforced", () async {
          await wrapper.migrate(migrations);
          await db.execute('PRAGMA foreign_keys = ON');

          await expectLater(
            () => db.execute('INSERT INTO notes (note, user_id) VALUES (?, ?)', ['orphan note', 999]),
            throwsA(anything),
            reason: 'Should throw when trying to insert a note with a non-existing user_id',
          );
        });
      });

      group("PRAGMA foreign_keys", () {
        Matcher foreignKeysEnabled = isA<List<Map<String, dynamic>>>().having(
          (it) => it.first['foreign_keys'],
          'foreign_keys',
          equals(1),
        );

        Matcher foreignKeysDisabled = isA<List<Map<String, dynamic>>>().having(
          (it) => it.first['foreign_keys'],
          'foreign_keys',
          equals(0),
        );

        test("Setting and reading works", () async {
          await expectLater(db.rawQuery("PRAGMA foreign_keys"), completion(foreignKeysDisabled));
          await db.execute('PRAGMA foreign_keys = ON');
          await expectLater(db.rawQuery("PRAGMA foreign_keys"), completion(foreignKeysEnabled));
          await db.execute('PRAGMA foreign_keys = OFF');
          await expectLater(db.rawQuery("PRAGMA foreign_keys"), completion(foreignKeysDisabled));
        });

        test("Noops inside of a transaction", () async {
          await db.transaction((txn) async {
            await expectLater(txn.rawQuery("PRAGMA foreign_keys"), completion(foreignKeysDisabled));
            await txn.execute('PRAGMA foreign_keys = ON');
            await expectLater(txn.rawQuery("PRAGMA foreign_keys"), completion(foreignKeysDisabled));
          });
          await db.execute('PRAGMA foreign_keys = ON');
          await db.transaction((txn) async {
            await expectLater(txn.rawQuery("PRAGMA foreign_keys"), completion(foreignKeysEnabled));
            await txn.execute('PRAGMA foreign_keys = OFF');
            await expectLater(txn.rawQuery("PRAGMA foreign_keys"), completion(foreignKeysEnabled));
          });
        });
      });

      test('With always apply', () async {
        wrapper = SqfliteDatabase(db, transactor: NoTransactionDelegate());
        final migrations2 = <Migration>[
          Migration(name: 'Make orphan note', definedAt: DateTime.utc(2025, 6, 23, 12, 2), up: '''
INSERT INTO notes (note, user_id) VALUES ('orphan note', 999);
''', down: '''
DELETE FROM notes WHERE note = 'orphan note' AND user_id = 999;
'''),
          Migration(
              name: 'Enforce foreign keys',
              alwaysApply: true,
              definedAt: DateTime.utc(2025, 6, 23, 12, 3),
              up: '''
PRAGMA foreign_keys = ON;
''',
              down: '''
PRAGMA foreign_keys = OFF;
'''),
        ];

        await wrapper.migrate(migrations + migrations2);

        await expectLater(() => db.delete('users'), throwsA(anything));
      });
    });
  });
}
