import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/platform_utils.dart';
import 'package:tether/features/shell/linux_shell.dart';
import 'package:tether/features/shell/android_shell.dart';
import 'package:tether/core/networking/tls_manager.dart';
import 'package:tether/shared/constants.dart';
import 'package:tether/core/database/app_database.dart';
import 'package:tether/core/database/database_provider.dart';
import 'package:tether/core/networking/daemon_client.dart';
import 'package:tether/core/providers.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set path overrides BEFORE database/TLS initialization.
  // On Linux, GUI and Daemon must share the exact same paths under ~/.config/tether/
  if (PlatformUtils.isLinux) {
    final home = Platform.environment['HOME'] ?? '/tmp';
    final configDir = p.join(home, '.config', 'tether');
    AppDatabase.dbPathOverride = p.join(configDir, TetherConstants.databaseName);
    TlsManager.certDirOverride = p.join(configDir, 'certs');
  } else {
    // Resolve data directories via path_provider (only place that imports it).
    final docsDir = await getApplicationDocumentsDirectory();
    final supportDir = await getApplicationSupportDirectory();
    AppDatabase.dbPathOverride = p.join(docsDir.path, TetherConstants.databaseName);
    TlsManager.certDirOverride = p.join(supportDir.path, 'certs');
  }

  // Initialize database.
  // On Android: opens a direct single-process NativeDatabase (the native
  // Kotlin service accesses tether.db via android.database.sqlite, WAL
  // mode ensures concurrent access safety).
  // On Desktop: opens a direct single-process NativeDatabase.
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
      // On Android, request permissions first
      await Permission.notification.request();
      await Permission.manageExternalStorage.request();
      
      // Initialize file service so local shared directory is correctly resolved
      await ref.read(fileServiceProvider).start();
      return;
    }

    if (PlatformUtils.isLinux) {
      // On Linux, all core services are run by the background daemon (tetherd).
      // The GUI simply initializes the DaemonClient UDS socket bridge.
      ref.read(daemonClientProvider);
      return;
    }

    // Other Desktop (macOS/Windows): start the Dart networking stack directly in GUI
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
      home: PlatformUtils.isAndroid
          ? const AndroidShell()
          : const LinuxShell(),
    );
  }
}

