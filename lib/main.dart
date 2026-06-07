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
    // Start connection manager (TCP server)
    final connectionManager = ref.read(connectionManagerProvider);
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
