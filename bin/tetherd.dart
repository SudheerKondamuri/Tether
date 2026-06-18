// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:tether/core/database/app_database.dart';
import 'package:tether/core/database/database_provider.dart';
import 'package:tether/core/networking/connection_manager.dart';
import 'package:tether/core/networking/mdns_discovery.dart';
import 'package:tether/core/networking/tls_manager.dart';
import 'package:tether/core/services/clipboard_service.dart';
import 'package:tether/core/services/file_service.dart';
import 'package:tether/core/services/notification_bridge_service.dart';
import 'package:tether/shared/constants.dart';

const String socketPath = '/tmp/tetherd.sock';
const String lockPath = '/tmp/tetherd.lock';

late final AppDatabase db;
late final MdnsDiscovery mdns;
late final ConnectionManager connectionManager;
late final ClipboardService clipboardService;
late final NotificationBridgeService notificationService;
late final FileService fileService;

ServerSocket? ipcServer;
final Set<Socket> activeConnections = {};

void main() async {
  // Ensure we are running on Linux
  if (!Platform.isLinux) {
    print('Error: tetherd is only supported on Linux.');
    exit(1);
  }

  // Check single instance lock
  final lockFile = File(lockPath);
  try {
    if (await lockFile.exists()) {
      // Check if process is actually running
      final pidStr = await lockFile.readAsString();
      final pid = int.tryParse(pidStr.trim());
      if (pid != null) {
        final results = await Process.run('ps', ['-p', '$pid']);
        if (results.exitCode == 0) {
          print('tetherd is already running with PID $pid.');
          exit(0);
        }
      }
    }
    await lockFile.writeAsString('$pid');
  } catch (e) {
    print('Warning: lock file check failed: $e');
  }

  print('Starting tetherd daemon...');

  // Setup directories
  final home = Platform.environment['HOME'] ?? '/tmp';
  final configDir = p.join(home, '.config', 'tether');
  await Directory(configDir).create(recursive: true);

  final dbPath = p.join(configDir, TetherConstants.databaseName);
  final certsDir = p.join(configDir, 'certs');

  // Set overrides
  AppDatabase.dbPathOverride = dbPath;
  TlsManager.certDirOverride = certsDir;

  print('Database path: $dbPath');
  print('Certs path: $certsDir');

  // Initialize DB
  await initDatabaseAtPath(dbPath);
  db = getDatabase();

  // Initialize Core Services
  mdns = MdnsDiscovery(db: db);
  connectionManager = ConnectionManager(db: db, mdns: mdns);
  clipboardService = ClipboardService(connectionManager: connectionManager, db: db);
  notificationService = NotificationBridgeService(connectionManager: connectionManager, db: db);
  fileService = FileService(connectionManager: connectionManager);

  // Configure file service paths
  fileService.downloadDirOverride = p.join(home, 'Downloads');
  fileService.serveDirOverride = home;

  // Start Core Services
  await connectionManager.init();
  await connectionManager.startServer();

  clipboardService.start();
  await notificationService.start();
  await fileService.start();

  await mdns.startBroadcast(
    deviceName: connectionManager.deviceName,
    port: TetherConstants.tcpPort,
  );
  await mdns.startDiscovery();

  print('Core services started successfully.');

  // Bind IPC socket
  final socketFile = File(socketPath);
  if (await socketFile.exists()) {
    try {
      await socketFile.delete();
    } catch (e) {
      print('Failed to delete existing socket file: $e');
    }
  }

  try {
    ipcServer = await ServerSocket.bind(InternetAddress(socketPath, type: InternetAddressType.unix), 0);
    print('IPC Unix Domain Socket server listening on $socketPath');
    ipcServer!.listen(_handleIpcConnection);
  } catch (e) {
    print('Fatal: Failed to bind IPC socket: $e');
    await shutdown();
    exit(1);
  }

  // Listen to connection manager state/peer updates to broadcast to GUI clients
  connectionManager.stateStream.listen((_) => _broadcastState());
  connectionManager.peerStream.listen((_) => _broadcastState());

  // Listen to local DB updates from core services to notify GUI clients
  // We hook into database writes by wrapping key operations
  // For clipboard/notification history, we notify connected GUI clients to reload
  _setupDatabaseNotificationHooks();

  // Graceful shutdown signals
  ProcessSignal.sigint.watch().listen((_) => _handleSignal(ProcessSignal.sigint));
  ProcessSignal.sigterm.watch().listen((_) => _handleSignal(ProcessSignal.sigterm));
}

void _handleSignal(ProcessSignal signal) async {
  print('\nReceived signal ${signal.name}, shutting down...');
  await shutdown();
  exit(0);
}

Future<void> shutdown() async {
  print('Stopping services...');
  
  // Close IPC server
  try {
    await ipcServer?.close();
  } catch (_) {}
  
  // Close active IPC client connections
  for (final conn in activeConnections) {
    try {
      conn.destroy();
    } catch (_) {}
  }
  activeConnections.clear();

  // Delete socket and lock files
  try {
    final socketFile = File(socketPath);
    if (await socketFile.exists()) await socketFile.delete();
  } catch (_) {}

  try {
    final lockFile = File(lockPath);
    if (await lockFile.exists()) await lockFile.delete();
  } catch (_) {}

  // Stop core services
  clipboardService.stop();
  notificationService.stop();
  await fileService.stop();
  await mdns.dispose();
  await connectionManager.dispose();

  // Close database
  try {
    await db.close();
  } catch (_) {}

  print('Shutdown complete.');
}

void _handleIpcConnection(Socket client) {
  print('GUI client connected via IPC.');
  activeConnections.add(client);

  // Send initial state immediately
  _sendStateTo(client);

  client
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        _handleIpcMessage(client, line);
      }, onError: (e) {
        print('IPC client error: $e');
        client.destroy();
        activeConnections.remove(client);
      }, onDone: () {
        print('GUI client disconnected from IPC.');
        activeConnections.remove(client);
      });
}

void _handleIpcMessage(Socket client, String line) {
  if (line.isEmpty) return;
  try {
    final msg = jsonDecode(line) as Map<String, dynamic>;
    final command = msg['command'] as String?;
    
    print('IPC Command received: $command');

    switch (command) {
      case 'connectTo':
        final host = msg['host'] as String?;
        final port = msg['port'] as int? ?? TetherConstants.tcpPort;
        if (host != null) {
          connectionManager.connectTo(host: host, port: port);
        }
        break;
      case 'disconnect':
        connectionManager.disconnect();
        break;
      case 'getState':
        _sendStateTo(client);
        break;
      default:
        print('Unknown IPC command: $command');
    }
  } catch (e) {
    print('Failed to parse IPC message: $line, error: $e');
  }
}

void _broadcastState() {
  for (final conn in activeConnections) {
    _sendStateTo(conn);
  }
}

void _sendStateTo(Socket client) {
  try {
    final payload = {
      'type': 'state',
      'connectionState': connectionManager.state.name,
      'peer': connectionManager.peer?.toJson(),
    };
    client.write('${jsonEncode(payload)}\n');
  } catch (e) {
    print('Failed to write state to IPC client: $e');
  }
}

void _broadcastDbUpdate(String table) {
  final payload = {
    'type': 'db_update',
    'table': table,
  };
  final json = '${jsonEncode(payload)}\n';
  for (final conn in activeConnections) {
    try {
      conn.write(json);
    } catch (_) {}
  }
}

void _setupDatabaseNotificationHooks() {
  // Let's hook into database tables if needed, or simply fire notifications
  // when connectionState or peers change.
  // Actually, we can poll the table count or watch them inside the daemon
  // and trigger broadcast if they change.
  // Let's implement a simple watch on clipboard/notification entries in the daemon
  // to broadcast db_updates to the GUI client!
  db.watchClipboardEntries().listen((_) {
    _broadcastDbUpdate('clipboard');
  });
  db.watchNotifications().listen((_) {
    _broadcastDbUpdate('notifications');
  });
}
