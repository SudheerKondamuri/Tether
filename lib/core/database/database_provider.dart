import 'package:flutter_riverpod/flutter_riverpod.dart';
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
Future<void> initDatabase({bool isBackground = false}) async {
  _dbInstance = AppDatabase();
}

/// Singleton database instance provider.
/// Requires [initDatabase] to have been called before the ProviderContainer
/// is created.
final databaseProvider = Provider<AppDatabase>((ref) {
  ref.onDispose(() => _dbInstance?.close());
  if (_dbInstance == null) {
    throw StateError(
      'Database not initialized. Call initDatabase() before accessing '
      'databaseProvider.',
    );
  }
  return _dbInstance!;
});
