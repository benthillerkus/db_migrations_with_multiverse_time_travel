import 'dart:ffi';

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

  test("BackupTransaction", retry: 3, () {
    if (vfs.xAccess("test.db", 0) == 1) {
      vfs.xDelete("test.db", 1);
    }
    db = sqlite3.open("test.db", vfs: vfs.name);
    wrapper = Sqlite3Database(db, transactor: BackupTransactionDelegate());
    addTearDown(() {
      db.dispose();
      vfs.xDelete("test.db", 1);
    });
    expect(() => wrapper.migrate(migrations), throwsA(isA<SqliteException>()));
    db = sqlite3.open("test.db", vfs: vfs.name);
    // Backup transaction should rollback, so the tbl table should not exist
    final result = db.select("SELECT name FROM sqlite_master WHERE type = 'table' and name = 'tbl'");
    expect(result, isEmpty);
  });
}
