import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart';

void main() {
  var migration = Migration(definedAt: DateTime(2025, 3, 6), up: 'up', down: 'down');
  print('awesome: ${migration.definedAt}');
}
