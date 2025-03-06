import 'dart:ffi';
// import 'dart:io';

import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
// import 'package:path/path.dart';

void main() {
  setUpAll(() {
    open.overrideFor(OperatingSystem.linux, () {
      return DynamicLibrary.open('sqlite3.so');
    });
  });

  late Database db;

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
}
