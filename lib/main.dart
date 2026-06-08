import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/platform_utils.dart';
import 'package:tether/features/shell/linux_shell.dart';
import 'package:tether/features/shell/android_shell.dart';
import 'package:tether/core/services/clipboard_service.dart';
import 'package:tether/core/services/notification_bridge_service.dart';
import 'package:tether/core/services/file_service.dart';
import 'package:tether/core/networking/connection_manager.dart';
import 'package:tether/core/networking/mdns_discovery.dart';
import 'package:tether/shared/constants.dart';
import 'package:tether/core/database/database_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database before anything else.
  // On Android, this polls for the background DriftIsolate server
  // (kicking the foreground service if needed) and connects as a client.
  // On Desktop, this opens a direct single-process NativeDatabase.
  await initDatabase();

  runApp(const ProviderScope(child: TetherApp()));
}

class TetherApp extends ConsumerStatefulWidget {
  const TetherApp({super.key});

  @override
  ConsumerState<TetherApp> createState() => _TetherAppState();
}

class _TetherAppState extends ConsumerState<TetherApp> {
  @override
  void initState() {
    super.initState();
    // Schedule service startup after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initServices();
    });
  }

  Future<void> _initServices() async {
    if (PlatformUtils.isAndroid) {
      // On Android, the foreground service is already running (started during
      // initDatabase cold-start polling). The background Dart engine handles
      // all networking. The UI process only reads state from the shared DB.
      return;
    }

    // Start connection manager (TCP server)
    final connectionManager = ref.read(connectionManagerProvider);
    await connectionManager.init();
    await connectionManager.startServer();

    // Start clipboard sync
    final clipboardService = ref.read(clipboardServiceProvider);
    clipboardService.start();

    // Start notification sync
    final notificationService = ref.read(notificationBridgeProvider);
    await notificationService.start();

    // Start file serving
    final fileService = ref.read(fileServiceProvider);
    await fileService.start();

    // Start mDNS broadcast and discovery
    final mdns = ref.read(mdnsDiscoveryProvider);
    await mdns.startBroadcast(
      deviceName: connectionManager.deviceName,
      port: TetherConstants.tcpPort,
    );
    await mdns.startDiscovery();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tether',
      debugShowCheckedModeBanner: false,
      theme: TetherTheme.darkTheme,
      home: PlatformUtils.platformWidget(
        linux: () => const LinuxShell(),
        android: () => const AndroidShell(),
        // Future: windows: () => const WindowsShell(),
        // Future: macos: () => const MacShell(),
        fallback: () => const LinuxShell(),
      ),
    );
  }
}

// ─── Headless Background Engine Entrypoint ───

@pragma('vm:entry-point')
void backgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the DriftIsolate server — this isolate owns the database file.
  // The UI isolate will find the connect port via IsolateNameServer.
  await initDatabase(isBackground: true);

  final container = ProviderContainer();

  // Initialize network stack scoped exclusively inside background engine
  final connectionManager = container.read(connectionManagerProvider);
  final mdns = container.read(mdnsDiscoveryProvider);

  // Mark this as the background isolate for routing decisions
  ConnectionManager.isBackgroundIsolate = true;

  await connectionManager.init();
  await connectionManager.startServer();
  await mdns.startBroadcast(
    deviceName: connectionManager.deviceName,
    port: TetherConstants.tcpPort,
  );
  await mdns.startDiscovery();

  // Start clipboard sync
  final clipboardService = container.read(clipboardServiceProvider);
  clipboardService.start();

  // Start notification sync
  final notificationService = container.read(notificationBridgeProvider);
  await notificationService.start();

  // Start file serving
  final fileService = container.read(fileServiceProvider);
  await fileService.start();

  // MethodChannel command handler for cross-isolate commands from UI
  const MethodChannel(TetherConstants.foregroundServiceChannel)
      .setMethodCallHandler((call) async {
    if (call.method == 'onBackgroundCommand') {
      final args = call.arguments;
      if (args is Map) {
        final command = args['command'];
        final commandArgs = args['args'];
        if (command == 'CONNECT_TO' && commandArgs is Map) {
          final host = commandArgs['host'];
          final port = commandArgs['port'];
          if (host != null) {
            connectionManager.connectTo(
              host: host as String,
              port: (port as int?) ?? TetherConstants.tcpPort,
            );
          }
        } else if (command == 'DISCONNECT') {
          connectionManager.disconnect();
        }
      }
    }
  });

  // Periodically run passive checkpoint on the SQLite database to prevent
  // WAL file bloat. The DriftIsolate server handles the actual DB writes,
  // but the checkpoint pragma is safe to issue from any client.
  Timer.periodic(const Duration(minutes: 30), (_) async {
    try {
      final db = container.read(databaseProvider);
      await db.customStatement('PRAGMA wal_checkpoint(PASSIVE);');
      developer.log('SQLite WAL passive checkpoint completed.');
    } catch (e) {
      developer.log('SQLite WAL checkpoint failed: $e');
    }
  });
}
