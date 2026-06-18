import 'package:tether/core/database/app_database.dart';

/// Pre-initialized database singleton. Set via [initDatabase] before any
/// ProviderContainer or runApp call.
AppDatabase? _dbInstance;

/// Initialize the database with a direct single-process connection.
///
/// On Android:
///   The native Kotlin ForegroundService accesses the same `tether.db` file
///   via `android.database.sqlite`. Both sides use WAL journal mode, which
///   allows concurrent readers + one writer safely. No DriftIsolate needed.
///
/// On Desktop (Linux/macOS/Windows):
///   Opens a direct single-process NativeDatabase.
///   `AppDatabase.dbPathOverride` must already be set before calling this.
Future<void> initDatabase({bool isBackground = false}) async {
  _dbInstance = AppDatabase();
}

/// Initialize the database with an explicit file path (daemon mode).
/// No Flutter platform channels needed.
Future<void> initDatabaseAtPath(String dbPath) async {
  _dbInstance = AppDatabase.atPath(dbPath);
}

/// Get the current database instance without Riverpod.
/// Used by the daemon and any code that runs outside a ProviderContainer.
AppDatabase getDatabase() {
  if (_dbInstance == null) {
    throw StateError(
      'Database not initialized. Call initDatabase() or initDatabaseAtPath() '
      'before accessing getDatabase().',
    );
  }
  return _dbInstance!;
}


