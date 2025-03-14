import 'dart:ffi';

import 'package:db_migrations_with_multiverse_timetravel/db_migrations_with_multiverse_timetravel.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_migrations_with_multiverse_timetravel/sqlite3_migrations_with_multiverse_timetravel.dart';

final migrations = [
  Migration(
    definedAt: DateTime(2025, 3, 14, 1),
    up: """
create table users (
  id integer primary key autoincrement,
  name text not null
);

insert into users (name) values ('Alice');
insert into users (name) values ('Bob');
""",
    down: """
drop table users;
""",
  ),
];

void main() {
  open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open('winsqlite3.dll'));
  final db = sqlite3.openInMemory();

  Sqlite3Database(db).migrate(migrations);

  for (final row in db.select('select * from users').rows) {
    print(row);
  }

  db.dispose();
}
