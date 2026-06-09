import 'dart:ui';
import 'package:drift/isolate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/core/database/app_database.dart';
import 'package:tether/shared/platform_utils.dart';
import 'package:flutter/services.dart';

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
///     foreground service via MethodChannel and waits up to 6 seconds.
///
/// On Desktop (Linux/macOS/Windows):
///   - Opens a direct single-process NativeDatabase. No isolate sharing needed.
Future<void> initDatabase({bool isBackground = false}) async {
  if (PlatformUtils.isAndroid) {
    if (isBackground) {
      _dbInstance = await AppDatabase.openShared();
    } else {
      int attempts = 0;
      const maxAttempts = 30; // 6 seconds max
      const pollInterval = Duration(milliseconds: 200);

      while (attempts < maxAttempts) {
        // Kick the native Android service into action on the first attempt
        if (attempts == 0) {
          try {
            const platform = MethodChannel('com.tether/foreground');
            await platform.invokeMethod('startService');
          } catch (_) { /* Ignore */ }
        }

        final port = IsolateNameServer.lookupPortByName('tether_db_isolate');
        if (port != null) {
          try {
            final driftIsolate = DriftIsolate.fromConnectPort(port);
            _dbInstance = AppDatabase.connect(await driftIsolate.connect());
            return;
          } catch (_) {
            IsolateNameServer.removePortNameMapping('tether_db_isolate');
          }
        }
        await Future.delayed(pollInterval);
        attempts++;
      }
      throw StateError('Fatal: Background Database Server failed to initialize.');
    }
  } else {
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
