import 'dart:ffi';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_migrations_with_multiverse_time_travel/sqlite3_migrations_with_multiverse_time_travel.dart';
import 'package:test/test.dart';

extension<T> on Iterator<T> {
  List<T> toList() => [for (; moveNext();) current];
}

void main() {
  setUpAll(() {
    open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open('winsqlite3.dll'));
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      print('${record.loggerName}/${record.level.name}  \t${record.message}');
    });
  });

  late Database db;

  setUp(() {
    db = sqlite3.openInMemory();
  });

  tearDown(() {
    db.dispose();
  });

  test('Journey', () {
    final log = Logger("journey");

    log.info("On the main branch the following migrations are defined");
    final migrationsMain = [
      Migration(
        name: "create users table",
        definedAt: DateTime.utc(2025, 3, 17, 17, 45),
        up: """
          create table users (
            identifier integer primary key autoincrement,
            name text not null
          );""",
        down: "drop table users;",
      ),
    ];

    log.info("In development the app is now started and the migrations are applied");
    {
      Sqlite3Database((_) => db).migrate(migrationsMain);

      expect(
        db.select("select * from sqlite_master where type='table' and name='users' limit 1"),
        isNotEmpty,
      );

      log.info("Running the app, some data is inserted");
      db.execute("insert into users (name) values ('Alice'), ('Bob'), ('Steward'), ('Mallory');");

      final users = db
          .select("select name from users order by identifier asc")
          .map((row) => row.values.first)
          .cast<String>()
          .toList();

      expect(users, ['Alice', 'Bob', 'Steward', 'Mallory']);

      expect(Sqlite3Database((_) => db).retrieveAllMigrations().toList(), migrationsMain);
    }

    log.info("On a branch we now add posts as a feature");
    final migrationsBranchPosts = [
      ...migrationsMain,
      Migration(
        name: "create posts table",
        definedAt: DateTime.utc(2025, 3, 17, 21, 31),
        up: """
          create table posts (
            id integer primary key autoincrement,
            user_id integer not null references users(identifier),
            content text not null
          );""",
        down: "drop table posts;",
      ),
      Migration(
        name: "add created_at column to posts",
        definedAt: DateTime.utc(2025, 3, 18, 9, 12),
        up: "alter table posts add column created_at timestamp not null default current_timestamp;",
        down: "alter table posts drop column created_at;",
      ),
    ];
    {
      Sqlite3Database((_) => db).migrate(migrationsBranchPosts);

      expect(
        db.select("select * from sqlite_master where type='table' and name='posts' limit 1"),
        isNotEmpty,
        reason: "because the posts table should have been created in the migration",
      );

      db.execute("insert into posts (user_id, content) values (1, 'Hello, World!'), (2, 'Hi!');");

      expect(Sqlite3Database((_) => db).retrieveAllMigrations().toList(), migrationsBranchPosts);
    }

    log.info("On a different branch we want to rename users.identifier to users.id");
    final migrationsBranchRenameIdentifier = [
      ...migrationsMain,
      Migration(
        name: "rename users.identifier to users.id",
        definedAt: DateTime.utc(2025, 3, 17, 22, 0),
        up: "alter table users rename column identifier to id;",
        down: "alter table users rename column id to identifier;",
      ),
    ];
    {
      Sqlite3Database((_) => db).migrate(migrationsBranchRenameIdentifier);

      expect(
        db.select("select * from sqlite_master where type='table' and name='users' limit 1"),
        isNotEmpty,
      );

      expect(
        db.select("select * from sqlite_master where type='table' and name='posts' limit 1"),
        isEmpty,
      );

      expect(db.select("select id from users"), isNotEmpty);

      expect(
        Sqlite3Database((_) => db).retrieveAllMigrations().toList(),
        migrationsBranchRenameIdentifier,
      );
    }

    log.info("Meanwhile for the posts branch we add another new feature: likes");
    {
      final migrationsBranchLikes = [
        ...migrationsBranchPosts,
        Migration(
          name: "add likes column to posts",
          definedAt: DateTime.utc(2025, 3, 18, 11, 03),
          up: "alter table posts add column likes integer non null default 0;",
          down: "alter table posts drop column likes;",
        ),
      ];

      Sqlite3Database((_) => db).migrate(migrationsBranchLikes);

      log.info("The app is now running on the likes branch");
      db.execute("insert into posts (user_id, content) values (1, 'Hello, World!'), (2, 'Hi!');");
      db.execute("update posts set likes = 42 where id = 1;");

      final posts = db
          .select("select content, likes from posts order by id asc")
          .map((row) => row.values)
          .cast<List<dynamic>>()
          .toList();

      expect(posts, [
        ['Hello, World!', 42],
        ['Hi!', 0],
      ]);

      expect(Sqlite3Database((_) => db).retrieveAllMigrations().toList(), migrationsBranchLikes);
    }

    log.info("Now the rename branch has been merged into main");
    migrationsMain.clear();
    migrationsMain.addAll(migrationsBranchRenameIdentifier);

    log.info("We check out main");
    {
      Sqlite3Database((_) => db).migrate(migrationsMain);

      expect(
        db.select("select * from sqlite_master where type='table' and name='users' limit 1"),
        isNotEmpty,
      );

      expect(
        db.select("select * from sqlite_master where type='table' and name='posts' limit 1"),
        isEmpty,
      );

      expect(db.select("select id from users"), isNotEmpty);

      expect(Sqlite3Database((_) => db).retrieveAllMigrations().toList(), migrationsMain);
    }

    log.info("Now we have to update our posts branch to include the changes from the main branch");
    final migrationsBranchPostsUpdated = [
      ...migrationsMain,
      Migration(
        name: "create posts table",
        definedAt: DateTime.utc(2025, 3, 18, 11, 15), // updated
        up: """
          create table posts (
            id integer primary key autoincrement,
            user_id integer not null references users(id),
            content text not null,
            created_at timestamp not null default current_timestamp
          );""",
        down: "drop table posts;",
      ),
    ];

    log.info("And we open the app on the posts branch");
    {
      Sqlite3Database((_) => db).migrate(migrationsBranchPostsUpdated);

      expect(
        db.select("select * from sqlite_master where type='table' and name='posts' limit 1"),
        isNotEmpty,
        reason: "because the posts table should have been created in the migration",
      );

      db.execute("insert into posts (user_id, content) values (1, 'Hello, World!'), (2, 'Hi!');");

      expect(Sqlite3Database((_) => db).retrieveAllMigrations().toList(), migrationsBranchPostsUpdated);
    }

    log.info("Now we merge the posts branch into main");
    migrationsMain.clear();
    migrationsMain.addAll(migrationsBranchPostsUpdated);
    log.info("We check out main");
    {
      Sqlite3Database((_) => db).migrate(migrationsMain);

      expect(
        db.select("select * from sqlite_master where type='table' and name='users' limit 1"),
        isNotEmpty,
      );

      expect(
        db.select("select * from sqlite_master where type='table' and name='posts' limit 1"),
        isNotEmpty,
      );

      expect(
        db.select("select * from posts"),
        isNotEmpty,
        reason: "because we added sample data on the posts 'branch', before we merged on main",
      );

      expect(Sqlite3Database((_) => db).retrieveAllMigrations().toList(), migrationsMain);
    }

    log.info("Now we merge main into the likes branch, to prepare it for merging into main");
    log.info("unfortunately we forget to update the definedAt field");
    log.info(
      "which means that the migration would have been applied before the posts table was created",
    );
    log.info("opening the app...");
    {
      log.info("would end up throwing an error");
      expect(
        () => Sqlite3Database((_) => db).migrate([
          ...migrationsMain,
          Migration(
            name: "add likes column to posts",
            definedAt: DateTime.utc(
              2025,
              3,
              18,
              11,
              03,
            ), // we should have updated this to ensure the correct order
            up: "alter table posts add column likes integer non null default 0;",
            down: "alter table posts drop column likes;",
          ),
        ]),
        throwsStateError,
        reason: "because a migration was provided in the wrong order",
      );

      expect(
        db.select("select name from pragma_table_info('posts')").map((row) => row.values.first),
        ["id", "user_id", "content", "created_at"],
        reason: "because the migration should not have been applied",
      );

      log.info("but even if we put the migrations in the correct order - the operation would fail");
      log.info("because the sql statement would fail due to the missing posts table");

      final sorted = [
        ...migrationsMain,
        Migration(
          name: "add likes column to posts",
          definedAt: DateTime.utc(2025, 3, 18, 11, 03),
          up: "alter table posts add column likes integer non null default 0;",
          down: "alter table posts drop column likes;",
        ),
      ].sorted((a, b) => a.compareTo(b));
      expect(sorted.first < sorted.last, isTrue);
      expect(
        () => Sqlite3Database((_) => db).migrate(sorted),
        throwsA(
          isA<SqliteException>().having((e) => e.message, "message", contains("no such table")),
        ),
        reason: "because the migration should not have been applied",
      );
    }
    log.info("So we update the definedAt field in the migrations table and then merge to main");
    {
      final migrationsBranchLikesUpdated = [
        ...migrationsBranchPostsUpdated,
        Migration(
          name: "add likes column to posts",
          definedAt: DateTime.utc(2025, 3, 18, 12, 00), // updated
          up: "alter table posts add column likes integer non null default 0;",
          down: "alter table posts drop column likes;",
        ),
      ];

      Sqlite3Database((_) => db).migrate(migrationsBranchLikesUpdated);

      expect(
        db.select("select name from pragma_table_info('posts')").map((row) => row.values.first),
        ["id", "user_id", "content", "created_at", "likes"],
      );
      expect(Sqlite3Database((_) => db).retrieveAllMigrations().toList(), migrationsBranchLikesUpdated);
    }
  });
}
