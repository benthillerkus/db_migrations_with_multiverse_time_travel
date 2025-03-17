// ignore_for_file: unused_import

import 'dart:ffi';

import 'package:file/local.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_test/sqlite3_test.dart';
import 'package:test/test.dart';

void main() {
  late Database db;

  setUpAll(() {
    open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open('winsqlite3.dll'));
  });

  setUp(() {
    db = sqlite3.openInMemory();
  });

  tearDown(() {
    db.dispose();
  });

  test('Database works', () {
    expect(db.userVersion, 0);
  });

  test('User version', () {
    db.userVersion = 1;
    expect(db.userVersion, 1);
  });

  test('Insertion', () {
    db.execute('CREATE TABLE tbl (a TEXT)');
    db.execute('INSERT INTO tbl (a) VALUES (?)', ['hello']);
    expect(db.select('SELECT * FROM tbl'), [
      {'a': 'hello'},
    ]);
    db.execute('INSERT INTO tbl (a) VALUES (?)', ['world']);
    expect(db.select('SELECT * FROM tbl'), [
      {'a': 'hello'},
      {'a': 'world'},
    ]);
  });

  group('Transactions', () {
    test('A', () {
      db.execute('BEGIN TRANSACTION');
      db.execute('CREATE TABLE tbl (a TEXT)');
      db.execute('INSERT INTO tbl (a) VALUES (?)', ['hello']);
      expect(db.select('SELECT * FROM tbl'), [
        {'a': 'hello'},
      ]);
      db.execute('ROLLBACK');
      expect(
        db.select("SELECT * FROM sqlite_master WHERE type='table' AND name='tbl'"),
        <dynamic>[],
      );
    });
  });
}
