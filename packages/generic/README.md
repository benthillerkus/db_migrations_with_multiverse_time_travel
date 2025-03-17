# Db Migrations with Multiverse Timetravel

Runs database migrations for apps with local / embedded databases like SQLite.
Helps with checking out different branches during development by storing the instructions to run down migrations alongside the data in the db.

## QA

### What does this package do?

It provides an implementation of an algorithm that can be run on a database to transition it from one state / schema into another.
The database is abstracted over with an interface that a consumer of this package would have to implement.
It is therefore agnostic to which database package you're using underneath.  

### How does it do that?

The developer (you) defines migrations that update the database inside of their app code.
Whenever a new change is made, a new migration is being defined.

When a user starts the app, all migrations are being run in sequence.
If the user already had an older version of the app installed, only the migrations that have been defined in the app code since that older version of the app released are being run.

### Ok, there are tons of packages that do this. What differentiates _Db Migrations with Multiverse Timetravel_?

_Db Migrations with Multiverse Timetravel_ solves a specific problem that other packages do not address:

During development, there will be multiple branches of your app code. And some branches may introduce changes to the database.
At first this is fine, the app code will automatically run the up migration when you check out a feature branch with a change to the db and you can just work.

But what happens when you now want to go back to the main branch or check out a different feature with a different change to the database?

The app code doesn't know would not know the state that the database is in. And it doesn't know how to bring it back into a state in which it can work with the database again.

_Db Migrations with Multiverse Timetravel_ addresses that problem by storing the information required to downgrade the database (like SQL code) inside of the database itself. So when it can first migrate the database back to a state that the app code knows how to work with. And then use the app code to run the remaining migrations.

### When should I not use this package?

You should **only** use _Db Migrations with Multiverse Timetravel_ when working with app / embedded / edge databases. That is databases that are only being accessed by a single instance of your app code.

You should **not** use this for live databases (perhaps running on a server) that are being accessed by multiple clients.

The strategy for migrations employed by this package lets the app code drive the database version. This cannot go well when there are a two clients with different versions trying to work with the database.

_In general, when working with a central database, down migrations are probably not what you are looking for. Imagine you made a mistake in your up migration -- what's the likelihood that your down migration is still correct? Could it not bring your database into an undefined state? Rollback and roll forward are more appropriate solutions here._

## Usage

Using [sqlite3](https://pub.dev/packages/sqlite3) and [sqlite3_migrations_with_multiverse_timetravel](sqlite3_migrations_with_multiverse_timetravel):
```dart
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
]

Sqlite3Database(db).migrate(migrations);
```

Else, if there is no pre-made adapter for you database package of preference:

```dart
class MyDatabase implements SyncDatabase {
  ...
}

final myDatabase = MyDatabase();
final migrator = SyncMigrator()(db: myDatabase, defined: migrations);
```

### What to do when there are two incompatible migrations on different branches?

Switching between branches is always fine, because the database will first be migrated down to the point where both branches diverged and then other bramch is being taken for the up migrations.

Imagine two feature branches `a` and `b` with different changes to the database and the `main` branch with neither change.
Assuming both feature branches are being kept up-to-date with `main`, when switching from `a` branch to `b`, the database is first being migrated using the down migrations of `a` to something that `main` understands _(because both branches diverge from there, **not** because this package has any understanding of your Git repository)_ and then migrated up using the migrations defined in `b`.

### What to do when I want to merge a branch with a diverging history?

Continuing from the example above, eventually branch `a` will be merged into `main`. This doesn't require any further intervention.

Now we want to merge `b` into `main`. If `b` touches different tables than `a` did you can just proceed.

If there are potential conflicts, like if one migration renamed a column and the other migration added a foreign key referencing that column, you will have to deal with that conflict:

First merge `main` into `b`.
Then update the migrations for `b` to be compatible with `main` and update the `definedAt` field. You can now merge `b` into `main`. 

If the database had the old migrations by `b`, but is now being driven by the code on `main`, after `a` and `b` had been merged into it, _Db Migrations with Multiverse Timetravel_ would see that the database has migrations applied that the app code doesn't know about and would then migrate these down until the database is at a migration the app code knows of. It can then run the remaining up migrations inside the app code.
