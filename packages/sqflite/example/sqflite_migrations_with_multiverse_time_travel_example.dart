import 'package:sqflite_migrations_with_multiverse_time_travel/sqflite_migrations_with_multiverse_time_travel.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final migrations = [
  Migration(
    definedAt: DateTime.utc(2025, 3, 14, 1),
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

Future<void> main() async {
  sqfliteFfiInit();

  var databaseFactory = databaseFactoryFfi;

  final wrapper = SqfliteDatabase((_) => databaseFactory.openDatabase(inMemoryDatabasePath));
  await wrapper.migrate(migrations);

  for (final row in await (await wrapper.db).query('users')) {
    print(row);
  }

  await (await wrapper.db).close();
}
