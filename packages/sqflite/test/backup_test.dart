import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_migrations_with_multiverse_time_travel/sqflite_migrations_with_multiverse_time_travel.dart';
import 'package:test/test.dart';
import 'package:mutex/mutex.dart';

/// Prevents concurrency issues with file creation / deletion
final mutex = Mutex();

void main() {
  late Database db;
  late SqfliteDatabase wrapper;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await mutex.acquire();
    if (await databaseExists("test.db")) {
      await deleteDatabase("test.db");
    }
    db = await openDatabase("test.db");
    wrapper = SqfliteDatabase(db, transactor: BackupTransactionDelegate());
    await wrapper.initializeMigrationsTable();
  });

  tearDown(() async {
    await db.close();
    if (await databaseExists(db.path)) {
      await deleteDatabase(db.path);
    }
    mutex.release();
  });

  test("Regular stuff works", retry: 3, () async {
    final migrations = [
      Migration(definedAt: DateTime.utc(2000, 11, 3), up: 'select(0)', down: 'select(0)'),
    ];
    await wrapper.migrate(migrations);
  });

  test("Reopen after commit", retry: 3, () async {
    final migrations = [
      Migration(definedAt: DateTime.utc(2003, 1, 5, 4), up: '''
create table users (
  id integer primary key autoincrement,
  name text
);
''', down: '''
drop table users;
'''),
      Migration(definedAt: DateTime.utc(2007), up: '''
insert into users (name) values ('peter'), ('hans');
''', down: '''
delete from users;
''')
    ];
    await wrapper.migrate(migrations);

    expect(db.isOpen, isFalse);

    db = await openDatabase(db.path);

    await expectLater(db.query('users'), completion(hasLength(2)));
  });

  test("Rollback", retry: 3, () async {
    final migrations = [
      Migration(definedAt: DateTime.utc(2005), up: '''
create table farmers(
  id integer primary key autoincrement,
  name text
);

create table sheep(
  id integer primary key autoincrement,
  name text,
  farmer_id integer,
  foreign key (farmer_id) references farmers(id)
);
''', down: '''
drop table sheep;
drop table farmers;
'''),
      Migration(
        definedAt: DateTime.utc(2006),
        alwaysApply: true,
        name: 'check foreign keys',
        up: "pragma foreign_keys=1;",
        down: "pragma foreign_keys=0;",
      ),
      Migration(definedAt: DateTime.utc(2007), up: '''
insert into farmers ('id', 'name') values (0, 'bob');
insert into sheep ('name', 'farmer_id') values ('shaun', 0);
''', down: '''
delete from sheep where 'name'='shaun';
delete from farmers where 'name'='bob';
'''),
      Migration(
        definedAt: DateTime.utc(2008),
        name: 'add hank',
        up: "insert into sheep ('name', 'farmer_id') values ('hank', 0);",
        down: "delete from sheep where name = 'hank';",
      ),
    ];

    await wrapper.migrate(migrations);

    db = await openDatabase(db.path);
    wrapper = SqfliteDatabase(db, transactor: BackupTransactionDelegate());

    await expectLater(db.query('sheep'), completion(hasLength(2)));
    await expectLater(db.query('sheep', where: "name = 'hank'"), completion(hasLength(1)));

    final migrations2 = [
      Migration.undo(definedAt: DateTime.utc(2010), migration: migrations.last),
      Migration(
        definedAt: DateTime.utc(2011),
        name: 'faulty migration',
        up: 'delete from farmers;',
        down: 'select(0);',
      )
    ];

    await expectLater(wrapper.migrate(migrations + migrations2), throwsA(anything));

    db = await openDatabase(db.path);
    wrapper = SqfliteDatabase(db, transactor: BackupTransactionDelegate());

    await expectLater(wrapper.retrieveAllMigrations().last, completion(migrations.last));
    await expectLater(db.query('sheep'), completion(hasLength(2)));
    await expectLater(db.query('sheep', where: "name = 'hank'"), completion(hasLength(1)));

    // And just to make sure that the deletion would have worked, if not for the faulty migration:

    await wrapper.migrate(migrations + [migrations2.first]);

    db = await openDatabase(db.path);
    wrapper = SqfliteDatabase(db, transactor: BackupTransactionDelegate());

    await expectLater(wrapper.retrieveAllMigrations().last, completion(migrations2.first));
    await expectLater(db.query('sheep'), completion(hasLength(1)));
    await expectLater(db.query('sheep', where: "name = 'hank'"), completion(isEmpty));
  });
}
