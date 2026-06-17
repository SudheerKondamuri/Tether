import 'package:flutter/material.dart';
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
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      // On Android, request notification permissions first so that the persistent
      // Foreground Service notification (which displays connection status and sync actions)
      // is visible to the user.
      await Permission.notification.request();
      return;
    }

    // Desktop: start the Dart networking stack
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
        fallback: () => const LinuxShell(),
      ),
    );
  }
}

