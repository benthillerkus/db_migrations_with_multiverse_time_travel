// LLM generated code
//
// This is just intended to "harden" the test suite
// and entrench current behavior.
//
// Since there is no intention behind these
// they can just be removed and regenerated
// if they conflict with future changes.

import 'dart:async';

import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';
import 'package:test/test.dart';

import 'logging.dart';
import 'mock_database.dart';

class FailingMockDatabase extends SyncMockDatabase {
  FailingMockDatabase({
    this.shouldFailOnTransaction = false,
    this.shouldFailOnCommit = false,
    this.shouldFailOnRollback = false,
    this.shouldFailOnExecute = false,
    this.shouldFailOnTableInit = false,
  });

  final bool shouldFailOnTransaction;
  final bool shouldFailOnCommit;
  final bool shouldFailOnRollback;
  final bool shouldFailOnExecute;
  final bool shouldFailOnTableInit;

  @override
  void beginTransaction() {
    if (shouldFailOnTransaction) {
      throw Exception('Transaction failed');
    }
    super.beginTransaction();
  }

  @override
  void commitTransaction() {
    if (shouldFailOnCommit) {
      throw Exception('Commit failed');
    }
    super.commitTransaction();
  }

  @override
  void rollbackTransaction() {
    if (shouldFailOnRollback) {
      throw Exception('Rollback failed');
    }
    super.rollbackTransaction();
  }

  @override
  void executeInstructions(Symbol migration) {
    if (shouldFailOnExecute) {
      throw Exception('Execute instructions failed');
    }
    super.executeInstructions(migration);
  }

  @override
  void initializeMigrationsTable() {
    if (shouldFailOnTableInit) {
      throw Exception('Table initialization failed');
    }
    super.initializeMigrationsTable();
  }
}

class FailingAsyncMockDatabase extends AsyncMockDatabase {
  FailingAsyncMockDatabase({
    this.shouldFailOnTransaction = false,
    this.shouldFailOnCommit = false,
    this.shouldFailOnRollback = false,
    this.shouldFailOnExecute = false,
    this.shouldFailOnTableInit = false,
  });

  final bool shouldFailOnTransaction;
  final bool shouldFailOnCommit;
  final bool shouldFailOnRollback;
  final bool shouldFailOnExecute;
  final bool shouldFailOnTableInit;

  @override
  Future<void> beginTransaction() async {
    if (shouldFailOnTransaction) {
      throw Exception('Transaction failed');
    }
    await super.beginTransaction();
  }

  @override
  Future<void> commitTransaction() async {
    if (shouldFailOnCommit) {
      throw Exception('Commit failed');
    }
    await super.commitTransaction();
  }

  @override
  Future<void> rollbackTransaction() async {
    if (shouldFailOnRollback) {
      throw Exception('Rollback failed');
    }
    await super.rollbackTransaction();
  }

  @override
  Future<void> executeInstructions(Symbol migration) async {
    if (shouldFailOnExecute) {
      throw Exception('Execute instructions failed');
    }
    await super.executeInstructions(migration);
  }

  @override
  Future<void> initializeMigrationsTable() async {
    if (shouldFailOnTableInit) {
      throw Exception('Table initialization failed');
    }
    await super.initializeMigrationsTable();
  }
}

void main() {
  setUpAll(() {
    setUpLogging();
  });

  group('Sync Error Handling', () {
    test('handles transaction failure gracefully', () {
      final migrator = SyncMigrator<dynamic, Symbol>();
      final defined = [
        Mig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
      ];
      final db = FailingMockDatabase(shouldFailOnTransaction: true);

      expect(() => migrator.call(db: db, defined: defined.iterator), throwsException);
      expect(db.applied, isEmpty);
    });

    test('handles commit failure with rollback', () {
      final migrator = SyncMigrator<dynamic, Symbol>();
      final defined = [
        Mig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
      ];
      final db = FailingMockDatabase(shouldFailOnCommit: true);

      expect(() => migrator.call(db: db, defined: defined.iterator), throwsException);
      // Should have attempted rollback
      expect(db.applied, isEmpty);
    });

    test('handles execute instructions failure with rollback', () {
      final migrator = SyncMigrator<dynamic, Symbol>();
      final defined = [
        Mig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
      ];
      final db = FailingMockDatabase(shouldFailOnExecute: true);

      expect(() => migrator.call(db: db, defined: defined.iterator), throwsException);
      expect(db.applied, isEmpty);
    });

    test('handles table initialization failure', () {
      final migrator = SyncMigrator<dynamic, Symbol>();
      final defined = [
        Mig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
      ];
      final db = FailingMockDatabase(shouldFailOnTableInit: true);
      db.migrationsTableInitialized = false;

      expect(() => migrator.call(db: db, defined: defined.iterator), throwsException);
    });

    test('handles deferred migration build failure', () {
      final migrator = SyncMigrator<dynamic, Symbol>();
      final defined = [
        SyncMigration<dynamic, Symbol>.deferred(
          definedAt: DateTime.utc(2025, 3, 6),
          builder: (_) => throw Exception('Build failed'),
        ),
      ];
      final db = SyncMockDatabase();

      expect(() => migrator.call(db: db, defined: defined.iterator), throwsException);
      expect(db.applied, isEmpty);
    });
  });

  group('Async Error Handling', () {
    test('handles concurrent modification error', () async {
      final migrator = AsyncMigrator<dynamic, Symbol>();
      final defined = [
        AMig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
      ];
      final db = AsyncMockDatabase();

      // Start first migration
      final future1 = migrator.call(db: db, defined: defined.iterator);

      // Try to start second migration while first is running
      expect(
        () => migrator.call(db: db, defined: defined.iterator),
        throwsA(isA<ConcurrentModificationError>()),
      );

      await future1; // Complete first migration
    });

    test('handles transaction failure gracefully', () async {
      final migrator = AsyncMigrator<dynamic, Symbol>();
      final defined = [
        AMig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
      ];
      final db = FailingAsyncMockDatabase(shouldFailOnTransaction: true);

      await expectLater(
        () => migrator.call(db: db, defined: defined.iterator),
        throwsException,
      );
      expect(db.applied, isEmpty);
    });

    test('handles commit failure with rollback', () async {
      final migrator = AsyncMigrator<dynamic, Symbol>();
      final defined = [
        AMig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
      ];
      final db = FailingAsyncMockDatabase(shouldFailOnCommit: true);

      await expectLater(
        () => migrator.call(db: db, defined: defined.iterator),
        throwsException,
      );
      expect(db.applied, isEmpty);
    });

    test('handles execute instructions failure with rollback', () async {
      final migrator = AsyncMigrator<dynamic, Symbol>();
      final defined = [
        AMig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
      ];
      final db = FailingAsyncMockDatabase(shouldFailOnExecute: true);

      await expectLater(
        () => migrator.call(db: db, defined: defined.iterator),
        throwsException,
      );
      expect(db.applied, isEmpty);
    });

    test('handles deferred migration build failure', () async {
      final migrator = AsyncMigrator<dynamic, Symbol>();
      final defined = [
        AsyncMigration<dynamic, Symbol>.deferred(
          definedAt: DateTime.utc(2025, 3, 6),
          builder: (_) => throw Exception('Build failed'),
        ),
      ];
      final db = AsyncMockDatabase();

      await expectLater(
        () => migrator.call(db: db, defined: defined.iterator),
        throwsException,
      );
      expect(db.applied, isEmpty);
    });

    test('can work again after error', () async {
      final defined = [
        AMig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
      ];

      // First call fails
      final migrator1 = AsyncMigrator<dynamic, Symbol>();
      final failingDb = FailingAsyncMockDatabase(shouldFailOnExecute: true);
      await expectLater(
        () => migrator1.call(db: failingDb, defined: defined.iterator),
        throwsException,
      );

      // Second call with new migrator should work
      final migrator2 = AsyncMigrator<dynamic, Symbol>();
      final workingDb = AsyncMockDatabase();
      await migrator2.call(db: workingDb, defined: defined.iterator);
      expect(workingDb.applied, isNotEmpty);
    });
  });

  group('Applied migrations order validation', () {
    test('sync - throws when applied migrations are out of order', () {
      final migrator = SyncMigrator<dynamic, Symbol>();
      final defined = [
        Mig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        Mig(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
      ];

      // Create database with migrations in wrong order
      final db = SyncMockDatabase([
        Mig(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
        Mig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
      ]);

      expect(() => migrator.call(db: db, defined: defined.iterator), throwsA(isA<StateError>()));
    });

    test('async - throws when applied migrations are out of order', () async {
      final migrator = AsyncMigrator<dynamic, Symbol>();
      final defined = [
        AMig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
        AMig(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
      ];

      // Create database with migrations in wrong order
      final db = AsyncMockDatabase([
        AMig(definedAt: DateTime.utc(2025, 3, 7), up: #up, down: #down),
        AMig(definedAt: DateTime.utc(2025, 3, 6), up: #up, down: #down),
      ]);

      await expectLater(
        () => migrator.call(db: db, defined: defined.iterator),
        throwsA(isA<StateError>()),
      );
    });
  });
}
