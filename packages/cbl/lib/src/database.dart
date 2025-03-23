import 'dart:async';

import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart' as m;
import 'package:cbl/cbl.dart';

class CouchbaseDatabase implements m.SyncDatabase<dynamic> {
  const CouchbaseDatabase(this._db);

  final SyncDatabase _db;

  @override
  void beginTransaction() {
    // TODO: implement beginTransaction
  }

  @override
  void commitTransaction() {
    // TODO: implement commitTransaction
  }

  @override
  void initializeMigrationsTable() {
    _db.createCollection("migrations", "migrations");
  }

  @override
  bool isMigrationsTableInitialized() {
    return _db.collection("migrations", "migrations") != null;
  }

  @override
  void performMigration(migration) {
    // TODO: implement performMigration
  }

  @override
  void removeMigrations(List<m.Migration> migrations) {
    // TODO: implement removeMigrations
  }

  @override
  Iterator<m.Migration> retrieveAllMigrations() {
    final collection = _db.collection("migrations", "migrations")!;
    collection.
  }

  @override
  void rollbackTransaction() {
    // TODO: implement rollbackTransaction
  }

  @override
  void storeMigrations(List<m.Migration<dynamic>> migrations) {
    final collection = _db.collection("migrations", "migrations")!;
    final now = DateTime.now();

    for (final migration in migrations) {
      final document = MutableDocument.withId(migration.definedAt.toIso8601String(), {
        "name": migration.name,
        "description": migration.description,
        "applied_at": (migration.appliedAt ?? now).toIso8601String(),
        "up": migration.up,
        "down": migration.down,
      });
      if (!collection.saveDocument(document)) {
        throw Exception("Failed to store migration ${migration.humanReadableId}");
      }
    }
  }
}
