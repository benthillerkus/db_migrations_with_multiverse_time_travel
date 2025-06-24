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
  late Database db;
  late Sqlite3Database wrapper;
  late TestSqliteFileSystem vfs;

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
    db = sqlite3.openInMemory(vfs: vfs.name);
    wrapper = Sqlite3Database(db);
    addTearDown(db.dispose);

    expect(() => wrapper.migrate(migrations), throwsA(isA<SqliteException>()));

    // Transaction should rollback, so the tbl table should not exist
    final result = db.select("SELECT name FROM sqlite_master WHERE type = 'table' and name = 'tbl'");
    expect(result, isEmpty);
  });

  test("NoTransaction", () {
    db = sqlite3.openInMemory(vfs: vfs.name);
    wrapper = Sqlite3Database(db, transactor: const NoTransactionDelegate());
    addTearDown(db.dispose);

    expect(() => wrapper.migrate(migrations), throwsA(isA<SqliteException>()));

    // No transaction cannot do any rollback, so the tbl table should exist
    final result = db.select("SELECT name FROM sqlite_master WHERE type = 'table' and name = 'tbl'");
    expect(result, isNotEmpty);
  });

  group("BackupTransaction", retry: 3, () {
    test("test.db", retry: 3, () {
      if (File("test.db").existsSync()) {
        File("test.db").deleteSync();
      }
      db = sqlite3.open("test.db");
      wrapper = Sqlite3Database(db, transactor: BackupTransactionDelegate());
      addTearDown(() {
        db.dispose();
        File("test.db").deleteSync();
      });
      db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)"); // Should be included in the backup
      var usersResult = db.select("SELECT name FROM sqlite_master WHERE type = 'table' and name = 'users'");
      expect(usersResult, isNotEmpty, reason: "The users table should be created before migration");

      expect(() => wrapper.migrate(migrations), throwsA(isA<SqliteException>()));

      db = sqlite3.open("test.db");
      // Backup transaction should rollback, so the tbl table should not exist
      final result = db.select("SELECT name FROM sqlite_master WHERE type = 'table' and name = 'tbl'");
      expect(result, isEmpty);
      usersResult = db.select("SELECT name FROM sqlite_master WHERE type = 'table' and name = 'users'");
      expect(usersResult, isNotEmpty, reason: "The users table should exist after rollback");
    });

    test(":memory:", () {
      db = sqlite3.openInMemory();
      wrapper = Sqlite3Database(db, transactor: BackupTransactionDelegate());
      addTearDown(db.dispose);
      addTearDown(() {
        if (File("backup.db").existsSync()) {
          File("backup.db").deleteSync();
        }
      });
      db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)"); // Should be included in the backup
      var usersResult = db.select("SELECT name FROM sqlite_master WHERE type = 'table' and name = 'users'");
      expect(usersResult, isNotEmpty, reason: "The users table should be created before migration");

      expect(() => wrapper.migrate(migrations), throwsA(isA<SqliteException>()));

      // In memory cannot be opened again, but the backup file should be created and exist
      db = sqlite3.open("backup.db");
      final result = db.select("SELECT name FROM sqlite_master WHERE type = 'table' and name = 'tbl'");
      expect(result, isEmpty, reason: "The tbl table should not exist after rollback");
      usersResult = db.select("SELECT name FROM sqlite_master WHERE type = 'table' and name = 'users'");
      expect(usersResult, isNotEmpty, reason: "The users table should exist after rollback");
    });
  });
}
