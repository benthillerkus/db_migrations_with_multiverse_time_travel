/// A library for managing SQLite database migrations with multiverse time travel.
library;

export 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart'
    show SyncMigrateExt;

import 'package:db_migrations_with_multiverse_time_travel/db_migrations_with_multiverse_time_travel.dart' as p;
import 'package:sqlite3/common.dart';

export 'src/database.dart';
export 'src/transaction.dart';

/// Typedef for [p.Migration] over [String].
///
/// {@macro dmwmt.migration}
typedef Migration = p.Migration<CommonDatabase, String>;
