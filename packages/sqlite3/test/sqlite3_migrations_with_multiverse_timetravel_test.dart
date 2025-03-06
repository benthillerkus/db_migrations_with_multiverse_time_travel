import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:path/path.dart';

void main() {
  setUpAll(() {
    open.overrideFor(OperatingSystem.linux, () {
      final scriptDir = File(Platform.script.toFilePath()).parent;
      final libraryNextToScript = File(join(scriptDir.path, 'sqlite3.so'));
      return DynamicLibrary.open(libraryNextToScript.path);
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
