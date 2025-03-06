import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
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
