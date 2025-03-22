import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_migrations_with_multiverse_time_travel/sqflite_migrations_with_multiverse_time_travel.dart';
import 'package:test/test.dart';

void main() {
  late Database db;
  late SqfliteDatabase wrapper;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    wrapper = SqfliteDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Initialize works', () async {
    await wrapper.initializeMigrationsTable();
    expect(await wrapper.isMigrationsTableInitialized(), isTrue);
  });

  test('Initialize has table', () async {
    await wrapper.initializeMigrationsTable();
    expect(await db.rawQuery('select * from sqlite_master where type = "table" and name = "migrations"'), isNotEmpty);
  });

  group('After initialization', () {
    setUp(() async {
      await wrapper.initializeMigrationsTable();
    });

    group('Insert migration', () {
      test('Insertion', () async {
        final migration = Migration<String>(
          definedAt: DateTime.utc(2021, 1, 1),
          name: 'test',
          description: 'test',
          appliedAt: DateTime.utc(2021, 1, 1, 12, 31),
          up: 'CREATE TABLE tbl (a TEXT)',
          down: 'DROP TABLE tbl',
        );
        await wrapper.storeMigrations([migration]);

        final result = await db.query('migrations');
        expect(result, hasLength(1));
        expect(result[0], containsPair('defined_at', migration.definedAt.millisecondsSinceEpoch));
        expect(result[0], containsPair('name', migration.name));
        expect(result[0], containsPair('description', migration.description));
        expect(result[0], containsPair('applied_at', migration.appliedAt!.millisecondsSinceEpoch));
        expect(result[0], containsPair('up', migration.up));
        expect(result[0], containsPair('down', migration.down));
      });
    });
  });
}
