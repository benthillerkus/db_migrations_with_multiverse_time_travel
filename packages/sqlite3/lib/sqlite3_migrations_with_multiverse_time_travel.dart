/// A library for managing SQLite database migrations with multiverse time travel.
library;

export 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart' show SyncMigrateExt;

import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart' as p;

export 'src/database.dart';

/// Typedef for [p.Migration] over [String].
/// 
/// {@macro dmwmt.migration}
typedef Migration = p.Migration<String>;