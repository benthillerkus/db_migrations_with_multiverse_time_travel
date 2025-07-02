## 2.0.0

- Bumps `db_migrations_with_multiverse_time_travel` dependency to 2.0.0.
- BREAKING: Adds a typedef for `Migration` so that generic parameters don't have to specified anymore.
- BREAKING: The `Sqlite3Database` wrapper is now constructed with a closure that returns a `Database` instance, allowing the wrapper to reestablish the connection on its own.
- Adds an optional alternative transaction mode that uses a separate backup.db instead of SQLite's SQL transactions.

## 1.0.2

- Loosen various dependency constraints.
- Automatically set `applied_at` to `current_time` if left empty

## 1.0.1

- Import `package:sqlite3/common.dart` instead of `package:sqlite3/sqlite3.dart` which enables usage on web targets.

## 1.0.0

- Initial version.
