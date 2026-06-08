import 'dart:ui';
import 'package:drift/isolate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/core/database/app_database.dart';
import 'package:tether/shared/platform_utils.dart';

/// Pre-initialized database singleton. Set via [initDatabase] before any
/// ProviderContainer or runApp call.
AppDatabase? _dbInstance;

/// Initialize the database with the correct strategy for the current platform
/// and isolate role.
///
/// On Android:
///   - **Background isolate**: Spawns the DriftIsolate server that owns the
///     single NativeDatabase file. Registers the connect port via
///     IsolateNameServer so the UI isolate can find it.
///   - **UI isolate**: Polls IsolateNameServer for the background server's
///     connect port. If the port isn't available (cold start), it kicks the
///     foreground service via MethodChannel and waits up to 4 seconds. The UI
///     **never** opens a direct disk lock on the database file.
///
/// On Desktop (Linux/macOS/Windows):
///   - Opens a direct single-process NativeDatabase. No isolate sharing needed.
Future<void> initDatabase({bool isBackground = false}) async {
  if (PlatformUtils.isAndroid) {
    if (isBackground) {
      // ── Background Isolate: Absolute owner of the database file ──
      _dbInstance = await AppDatabase.openShared();
    } else {
      // ── UI Isolate: Poll for the background server ──
      // The foreground service is started eagerly from
      // MainActivity.configureFlutterEngine(), so by the time main() runs,
      // the background engine is already being created.

      int attempts = 0;
      const maxAttempts = 30; // 6 seconds max
      const pollInterval = Duration(milliseconds: 200);

      while (attempts < maxAttempts) {
        final port =
            IsolateNameServer.lookupPortByName('tether_db_isolate');

        if (port != null) {
          try {
            final driftIsolate = DriftIsolate.fromConnectPort(port);
            _dbInstance = AppDatabase.connect(await driftIsolate.connect());
            return;
          } catch (_) {
            // Port might be stale from a hot restart — the old DriftIsolate
            // is dead. Clear it and keep polling for the new one.
            IsolateNameServer.removePortNameMapping('tether_db_isolate');
          }
        }

        await Future.delayed(pollInterval);
        attempts++;
      }

      throw StateError(
        'Fatal: Background Database Server failed to initialize '
        'after ${maxAttempts * pollInterval.inMilliseconds}ms. '
        'The foreground service may have been killed by the OS.',
      );
    }
  } else {
    // ── Desktop: Single-process, direct NativeDatabase ──
    _dbInstance = AppDatabase();
  }
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
