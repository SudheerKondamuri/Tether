import 'dart:isolate';
import 'dart:ui';
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
import 'package:tether/core/database/app_database.dart';
import 'package:tether/core/database/database_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      // Start foreground service on Android UI startup
      const MethodChannel(TetherConstants.foregroundServiceChannel)
          .invokeMethod('startService');
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

// Separate Headless Engine Entrypoint
@pragma('vm:entry-point')
void backgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  AppDatabase.isBackground = true;
  
  final container = ProviderContainer();
  // Eagerly initialize database and sync channels
  container.read(databaseProvider);
  
  final ReceivePort backgroundReceivePort = ReceivePort();
  
  // Expose memory port across isolates
  IsolateNameServer.registerPortWithName(
    backgroundReceivePort.sendPort, 
    'tether_background_rpc'
  );

  // Initialize network stack scoped exclusively inside background engine
  final connectionManager = container.read(connectionManagerProvider);
  final mdns = container.read(mdnsDiscoveryProvider);

  // Mark this as the background isolate
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

  backgroundReceivePort.listen((message) {
    if (message is Map<String, dynamic>) {
      final command = message['command'];
      if (command == 'CONNECT_TO') {
        connectionManager.connectTo(
          host: message['host'], 
          port: message['port'] ?? TetherConstants.tcpPort,
        );
      }
    }
  });

  // Periodically run passive checkpoint on the SQLite database to prevent WAL file bloat.
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
