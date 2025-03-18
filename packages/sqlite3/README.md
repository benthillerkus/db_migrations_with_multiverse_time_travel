# Sqlite3 Migrations with Multiverse Time Travel

This is an integration for [db_migrations_with_multiverse_time_travel](https://pub.dev/packages/db_migrations_with_multiverse_time_travel).

## Usage

```dart
import 'package:sqlite3_migrations_with_multiverse_time_travel/sqlite3_migrations_with_multiverse_time_travel.dart';

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

final db = sqlite3.openInMemory();

Sqlite3Database(db).migrate(migrations);

for (final row in db.select('select * from users').rows) {
  print(row);
}
```
