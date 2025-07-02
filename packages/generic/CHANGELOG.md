## 2.0.0

- Adds support for migrations that have to run on every connection start, even if they have already been applied.
- Adds support for migrations that generate their instructions by querying the database.

## 1.1.0

- Adds AsyncMigrator for databases with async connections

## 1.0.1

- Loosen various dependency constraints.
- Automatically set `applied_at` when inserting

## 1.0.0

- Initial version.
