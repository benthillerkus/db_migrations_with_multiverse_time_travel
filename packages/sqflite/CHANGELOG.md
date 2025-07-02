## 0.2.0

- Bumps `db_migrations_with_multiverse_time_travel` dependency to 2.0.0.
- BREAKING: Adds a typedef for `Migration` so that generic parameters don't have to specified anymore.
- BREAKING: The `Sqlite3Database` wrapper is now constructed with a closure that returns a `Database` instance, allowing the wrapper to reestablish the connection on its own.
- Adds an optional alternative transaction mode that uses a separate backup.db instead of SQLite's SQL transactions.

## 0.1.1

- Bumped minimum version of `sqflite_common` to `2.4.1` to ensure that query cursors are available.

## 0.1.0

- Initial version.
