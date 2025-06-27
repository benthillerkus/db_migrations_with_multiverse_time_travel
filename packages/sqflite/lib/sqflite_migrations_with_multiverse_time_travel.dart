/// A library for managing SQLite database migrations with multiverse time travel.
library;

import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart' as p;
import 'package:sqflite_common/sqflite.dart';

export 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart'
    show AsyncMigrateExt;

export 'src/database.dart';
export 'src/transaction.dart';

/// Typedef for [p.Migration] of [String].
///
/// {@macro dmwmt.migration}
typedef Migration = p.Migration<Database, String>;
