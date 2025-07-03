import 'dart:ffi';
import 'dart:io';

import 'package:file/local.dart';
import 'package:logging/logging.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_migrations_with_multiverse_time_travel/sqlite3_migrations_with_multiverse_time_travel.dart';
import 'package:sqlite3_test/sqlite3_test.dart';
import 'package:test/test.dart';

void main() {
  late Sqlite3Database wrapper;
  late TestSqliteFileSystem vfs;
  final log = Logger('test');

  setUpAll(() {
    open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open('winsqlite3.dll'));
    vfs = TestSqliteFileSystem(fs: const LocalFileSystem());
    sqlite3.registerVirtualFileSystem(vfs);
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    });
  });

  tearDownAll(() {
    sqlite3.unregisterVirtualFileSystem(vfs);
  });

  final migrations = [
    Migration(
      definedAt: DateTime.utc(2021, 1, 1),
      up: 'CREATE TABLE tbl (a TEXT)',
      down: 'DROP TABLE tbl',
    ),
    Migration(
      definedAt: DateTime.utc(2021, 1, 2),
      up: 'not valid SQL',
      down: 'DROP TABLE tbl2',
    ),
  ];

  test("Transaction", () {
    wrapper = Sqlite3Database((_) => sqlite3.openInMemory(vfs: vfs.name));
    addTearDown(wrapper.db.dispose);

    expect(() => wrapper.migrate(migrations), throwsA(isA<SqliteException>()));

    // Transaction should rollback, so the tbl table should not exist
    final result = wrapper.db.select("SELECT name FROM sqlite_master WHERE type = 'table' and name = 'tbl'");
    expect(result, isEmpty);
  });

  test("NoTransaction", () {
    wrapper = Sqlite3Database((_) => sqlite3.openInMemory(vfs: vfs.name), transactor: const NoTransactionDelegate());
    addTearDown(wrapper.db.dispose);

    expect(() => wrapper.migrate(migrations), throwsA(isA<SqliteException>()));

    // No transaction cannot do any rollback, so the tbl table should exist
    final result = wrapper.db.select("SELECT name FROM sqlite_master WHERE type = 'table' and name = 'tbl'");
    expect(result, isNotEmpty);
  });

  group("BackupTransaction", retry: 3, () {
    test("test.db", retry: 3, () {
      final dbFile = File("test.db");
      final backupFile = File("backup.db");
      if (dbFile.existsSync()) {
        dbFile.deleteSync();
      }
      wrapper = Sqlite3Database(
        (_) => sqlite3.open("test.db"),
        transactor: BackupTransactionDelegate(dbFile: dbFile, backupFile: backupFile),
      );
      addTearDown(() {
        wrapper.db.dispose();
        dbFile.deleteSync();
      });
      wrapper.db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)"); // Should be included in the backup
      var usersResult = wrapper.db.select("SELECT name FROM sqlite_master WHERE type = 'table' and name = 'users'");
      expect(usersResult, isNotEmpty, reason: "The users table should be created before migration");

      expect(() => wrapper.migrate(migrations), throwsA(isA<SqliteException>()));

      // Backup transaction should rollback, so the tbl table should not exist
      final result = wrapper.db.select("SELECT name FROM sqlite_master WHERE type = 'table' and name = 'tbl'");
      expect(result, isEmpty);
      usersResult = wrapper.db.select("SELECT name FROM sqlite_master WHERE type = 'table' and name = 'users'");
      expect(usersResult, isNotEmpty, reason: "The users table should exist after rollback");
    });

    test(":memory:", () {
      final backupFile = File("backup.db");
      wrapper = Sqlite3Database(
        (_) => sqlite3.openInMemory(),
        transactor: BackupTransactionDelegate(dbFile: File(":memory:"), backupFile: backupFile),
      );
      addTearDown(wrapper.db.dispose);
      addTearDown(() {
        if (backupFile.existsSync()) {
          backupFile.deleteSync();
        }
      });
      log.info("Adding users table...");
      wrapper.db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)"); // Should be included in the backup
      wrapper.db.execute("INSERT INTO users (name) VALUES ('Alice'), ('Bob')");
      var usersResult = wrapper.db.select("SELECT name FROM sqlite_master WHERE type = 'table' and name = 'users'");
      expect(usersResult, isNotEmpty, reason: "The users table should be created before migration");

      expect(() => wrapper.migrate(migrations), throwsA(isA<SqliteException>()));

      // In memory cannot be opened again, but the backup file should be created and exist
      final result = wrapper.db.select("SELECT name FROM sqlite_master WHERE type = 'table' and name = 'tbl'");
      expect(result, isEmpty, reason: "The tbl table should not exist after rollback");
      usersResult = wrapper.db.select("SELECT name FROM sqlite_master WHERE type = 'table' and name = 'users'");
      expect(usersResult, isNotEmpty, reason: "The users table should exist after rollback");
    });

    test("Cannot open when backup file is a valid database", () {
      final file = File("backup2.db");
      addTearDown(() {
        if (file.existsSync()) {
          file.deleteSync();
        }
      });
      sqlite3.open("backup2.db")
        ..execute("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")
        ..dispose();

      wrapper = Sqlite3Database(
        (_) => sqlite3.openInMemory(),
        transactor: BackupTransactionDelegate(
          dbFile: File(":memory:"),
          backupFile: file,
        ),
      );

      addTearDown(() {
        wrapper.db.dispose();
      });

      expect(file.existsSync(), isTrue, reason: "Manufactured backup should exist before transaction");
      expect(() => wrapper.beginTransaction(), throwsA(isA<UncleanTransactionException>()));
      wrapper.transactor.rollback(wrapper);
      expect(file.existsSync(), isFalse, reason: "Backup file should be gone after rollback");
      wrapper.beginTransaction();
    });

    test("Integrity check works", () {
      final db = sqlite3.openInMemory();
      final ig = db.select("pragma integrity_check;");
      expect(
        ig,
        allOf(
          hasLength(1),
          isA<ResultSet>().having(
            (set) => set.first,
            "first and only row",
            containsPair("integrity_check", "ok"),
          ),
        ),
      );
    });

    test("Can open when backup file is not a database", () {
      final file = File("backup4.db")..writeAsStringSync("not a database");

      wrapper = Sqlite3Database(
        (_) => sqlite3.openInMemory(),
        transactor: BackupTransactionDelegate(
          dbFile: File(":memory:"),
          backupFile: file,
        ),
      );

      addTearDown(() {
        wrapper.db.dispose();
        if (file.existsSync()) {
          file.deleteSync();
        }
      });

      expect(file.readAsStringSync(), "not a database");
      wrapper.beginTransaction();
      expect(
        () => sqlite3.open(file.path),
        returnsNormally,
        reason: "Backup file should now be replaced with a valid database",
      );
      wrapper.commitTransaction();
      expect(file.existsSync(), isFalse, reason: "Backup file should be deleted after commit");
    });
  });
}
