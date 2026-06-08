import 'dart:isolate';
import 'dart:ui';
import 'package:drift/isolate.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/core/database/app_database.dart';
import 'package:tether/shared/constants.dart';
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
      SendPort? port =
          IsolateNameServer.lookupPortByName('tether_db_isolate');

      int attempts = 0;
      while (port == null && attempts < 20) {
        if (attempts == 0) {
          // First attempt: wake the foreground service if it isn't running yet
          try {
            await const MethodChannel(TetherConstants.foregroundServiceChannel)
                .invokeMethod('startService');
          } catch (_) {
            // Service might already be running — safe to ignore
          }
        }
        await Future.delayed(const Duration(milliseconds: 200));
        port = IsolateNameServer.lookupPortByName('tether_db_isolate');
        attempts++;
      }

      if (port == null) {
        throw StateError(
          'Fatal: Background Database Server failed to initialize '
          'after ${attempts * 200}ms. The foreground service may have '
          'been killed by the OS.',
        );
      }

      final driftIsolate = DriftIsolate.fromConnectPort(port);
      _dbInstance = AppDatabase.connect(await driftIsolate.connect());
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
