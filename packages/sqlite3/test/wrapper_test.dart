import 'dart:ffi';

import 'package:fake_async/fake_async.dart';
import 'package:file/local.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_migrations_with_multiverse_time_travel/sqlite3_migrations_with_multiverse_time_travel.dart';
import 'package:sqlite3_test/sqlite3_test.dart';
import 'package:test/test.dart';

void main() {
  late Database db;
  late Sqlite3Database wrapper;
  late TestSqliteFileSystem vfs;

  setUpAll(() {
    open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open('winsqlite3.dll'));
    vfs = TestSqliteFileSystem(fs: const LocalFileSystem());
    sqlite3.registerVirtualFileSystem(vfs);
  });

  tearDownAll(() {
    sqlite3.unregisterVirtualFileSystem(vfs);
  });

  setUp(() {
    db = sqlite3.openInMemory(vfs: vfs.name);
    wrapper = Sqlite3Database(db);
  });

  tearDown(() {
    db.dispose();
  });

  test('Initialize works', () {
    wrapper.initializeMigrationsTable();
    expect(wrapper.isMigrationsTableInitialized(), isTrue);
  });

  test('Initialize has table', () {
    wrapper.initializeMigrationsTable();
    expect(db.select('select * from sqlite_master where type = "table" and name = "migrations"'), isNotEmpty);
  });

  group('After initialization', () {
    setUp(() {
      wrapper.initializeMigrationsTable();
    });

    group('Insert migration', () {
      test('Insertion', () {
        final migration = Migration<String>(
          definedAt: DateTime.utc(2021, 1, 1),
          name: 'test',
          description: 'test',
          appliedAt: DateTime.utc(2021, 1, 1, 12, 31),
          up: 'CREATE TABLE tbl (a TEXT)',
          down: 'DROP TABLE tbl',
        );
        wrapper.storeMigrations([migration]);

        final result = db.select('SELECT * FROM migrations');
        expect(result, hasLength(1));
        expect(result[0], containsPair('defined_at', migration.definedAt.millisecondsSinceEpoch));
        expect(result[0], containsPair('name', migration.name));
        expect(result[0], containsPair('description', migration.description));
        expect(result[0], containsPair('applied_at', migration.appliedAt!.millisecondsSinceEpoch));
        expect(result[0], containsPair('up', migration.up));
        expect(result[0], containsPair('down', migration.down));
      });

      test('Auto fill in applied_at', () {
        final moonLanding = DateTime.utc(1969, 7, 20, 20, 18, 04);
        FakeAsync(initialTime: moonLanding).run((_) {
          wrapper.storeMigrations([
            Migration<String>(
              definedAt: DateTime.utc(1902, 1, 1),
              up: 'CREATE TABLE tbl (a TEXT)',
              down: 'DROP TABLE tbl',
            ),
          ]);

          final result = db.select('SELECT * FROM migrations');
          expect(result, hasLength(1));
          expect(result[0], containsPair('applied_at', -14182916));
        });
      });
    });
  });
}
