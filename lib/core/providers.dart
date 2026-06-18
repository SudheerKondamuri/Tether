import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tether/core/database/app_database.dart';
import 'package:tether/core/database/database_provider.dart';
import 'package:tether/core/networking/connection_manager.dart';
import 'package:tether/core/networking/mdns_discovery.dart';
import 'package:tether/core/networking/daemon_client.dart';
import 'package:tether/core/services/clipboard_service.dart';
import 'package:tether/core/services/file_service.dart';
import 'package:tether/core/services/notification_bridge_service.dart';
import 'package:tether/shared/constants.dart';
import 'package:tether/shared/platform_utils.dart';

// ─── Database Providers ───

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = getDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// ─── mDNS Providers ───

final mdnsDiscoveryProvider = Provider<MdnsDiscovery>((ref) {
  final db = ref.read(databaseProvider);
  final discovery = MdnsDiscovery(db: db);
  ref.onDispose(() => discovery.dispose());
  return discovery;
});

final discoveredDevicesProvider = StreamProvider<List<DiscoveredDevice>>((ref) {
  if (PlatformUtils.isAndroid) {
    final db = ref.watch(databaseProvider);
    return Stream.periodic(const Duration(milliseconds: 500), (i) => i)
        .asyncMap((_) => db.getSetting('discovered_devices'))
        .map((val) {
      if (val == null || val.isEmpty) return [];
      try {
        final List<dynamic> list = jsonDecode(val) as List<dynamic>;
        return list
            .map((item) =>
                DiscoveredDevice.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    });
  }
  final discovery = ref.watch(mdnsDiscoveryProvider);
  return discovery.devicesStream;
});

// ─── Connection Manager Providers ───

final connectionManagerProvider = Provider<ConnectionManager>((ref) {
  final db = ref.read(databaseProvider);
  final mdns = ref.read(mdnsDiscoveryProvider);
  final manager = ConnectionManager(db: db, mdns: mdns);
  
  if (PlatformUtils.isAndroid) {
    manager.androidConnectTo = (host, port) async {
      await const MethodChannel(TetherConstants.foregroundServiceChannel)
          .invokeMethod('connectTo', {
        'host': host,
        'port': port,
      });
      return true;
    };
    manager.androidDisconnect = () async {
      await const MethodChannel(TetherConstants.foregroundServiceChannel)
          .invokeMethod('disconnect');
    };
  }

  ref.onDispose(() => manager.dispose());
  return manager;
});

final connectionStateProvider = StreamProvider<TetherConnectionState>((ref) {
  if (PlatformUtils.isAndroid) {
    final db = ref.watch(databaseProvider);
    return Stream.periodic(const Duration(milliseconds: 500), (i) => i)
        .asyncMap((_) => db.getSetting('connection_state'))
        .map((val) {
      if (val == null) return TetherConnectionState.disconnected;
      return TetherConnectionState.values.firstWhere(
        (e) => e.name == val,
        orElse: () => TetherConnectionState.disconnected,
      );
    }).distinct();
  }
  
  if (PlatformUtils.isLinux) {
    return ref.watch(daemonClientProvider).stateStream;
  }

  final manager = ref.watch(connectionManagerProvider);
  return manager.stateStream;
});

final connectedDeviceProvider = StreamProvider<ConnectedDevice?>((ref) {
  if (PlatformUtils.isAndroid) {
    final db = ref.watch(databaseProvider);
    return Stream.periodic(const Duration(milliseconds: 500), (i) => i)
        .asyncMap((_) => db.getSetting('connected_peer'))
        .map((val) {
      if (val == null || val.isEmpty) return null;
      try {
        return ConnectedDevice.fromJson(jsonDecode(val) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).distinct((a, b) {
      if (a == null && b == null) return true;
      if (a == null || b == null) return false;
      return a.deviceId == b.deviceId && a.ip == b.ip;
    });
  }

  if (PlatformUtils.isLinux) {
    return ref.watch(daemonClientProvider).peerStream;
  }

  final manager = ref.watch(connectionManagerProvider);
  return manager.peerStream;
});

// ─── Clipboard Providers ───

final clipboardServiceProvider = Provider<ClipboardService>((ref) {
  final connManager = ref.watch(connectionManagerProvider);
  final db = ref.watch(databaseProvider);
  final service = ClipboardService(
    connectionManager: connManager,
    db: db,
  );

  if (PlatformUtils.isAndroid) {
    service.platformSetClipboard = (text) async {
      await const MethodChannel(TetherConstants.clipboardChannel)
          .invokeMethod('setClipboard', {'text': text});
    };
    service.androidStartListening = (onChanged) {
      const MethodChannel(TetherConstants.clipboardChannel)
          .setMethodCallHandler((call) async {
        if (call.method == 'onClipboardChanged') {
          final text = call.arguments['text'] as String? ?? '';
          onChanged(text);
        }
      });
      const MethodChannel(TetherConstants.clipboardChannel)
          .invokeMethod('startListening');
    };
    service.androidStopListening = () {
      const MethodChannel(TetherConstants.clipboardChannel)
          .invokeMethod('stopListening');
      const MethodChannel(TetherConstants.clipboardChannel)
          .setMethodCallHandler(null);
    };
  } else {
    service.platformGetClipboard = () async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text ?? '';
    };
    service.platformSetClipboard = (text) async {
      await Clipboard.setData(ClipboardData(text: text));
    };
  }

  ref.onDispose(() => service.dispose());
  return service;
});

final clipboardHistoryProvider = StreamProvider<List<ClipboardEntry>>((ref) {
  final db = ref.watch(databaseProvider);

  if (PlatformUtils.isAndroid) {
    return Stream.periodic(const Duration(seconds: 1), (i) => i)
        .asyncMap((_) => db.getClipboardEntries());
  }

  if (PlatformUtils.isLinux) {
    final client = ref.watch(daemonClientProvider);
    final controller = StreamController<List<ClipboardEntry>>();
    
    Future<void> fetch() async {
      try {
        final entries = await db.getClipboardEntries();
        if (!controller.isClosed) controller.add(entries);
      } catch (_) {}
    }

    fetch();

    final sub = client.dbUpdateStream.where((table) => table == 'clipboard').listen((_) {
      fetch();
    });

    ref.onDispose(() {
      sub.cancel();
      controller.close();
    });

    return controller.stream;
  }

  return db.watchClipboardEntries();
});

// ─── File Service Providers ───

final fileServiceProvider = Provider<FileService>((ref) {
  final connManager = ref.watch(connectionManagerProvider);
  final service = FileService(connectionManager: connManager);
  
  if (PlatformUtils.isLinux) {
    service.getPeerOverride = () => ref.read(daemonClientProvider).peer;
  } else if (PlatformUtils.isAndroid) {
    service.getPeerOverride = () => ref.read(connectedDeviceProvider).valueOrNull;
  }
  
  getApplicationSupportDirectory().then((supportDir) {
    service.serveDirOverride = PlatformUtils.isAndroid ? '/storage/emulated/0' : Platform.environment['HOME'];
  });
  
  getDownloadsDirectory().then((downloadsDir) {
    if (downloadsDir != null) {
      service.downloadDirOverride = downloadsDir.path;
    }
  });

  ref.onDispose(() => service.dispose());
  return service;
});

// ─── Notification Providers ───

final notificationBridgeProvider = Provider<NotificationBridgeService>((ref) {
  final connManager = ref.watch(connectionManagerProvider);
  final db = ref.watch(databaseProvider);
  final service = NotificationBridgeService(
    connectionManager: connManager,
    db: db,
  );

  if (PlatformUtils.isAndroid) {
    const channel = MethodChannel(TetherConstants.notificationChannel);
    service.androidIsPermissionGranted = () async {
      return await channel.invokeMethod<bool>('isPermissionGranted') ?? false;
    };
    service.androidRequestPermission = () async {
      await channel.invokeMethod('requestPermission');
    };
    service.androidStartListening = () async {
      await channel.invokeMethod('startListening');
    };
    service.androidStopListening = () async {
      await channel.invokeMethod('stopListening');
    };
    service.androidSetupCallback = (onNotif) {
      if (onNotif == null) {
        channel.setMethodCallHandler(null);
      } else {
        channel.setMethodCallHandler((call) async {
          if (call.method == 'onNotificationPosted') {
            onNotif(call.arguments);
          }
        });
      }
    };
  }

  ref.onDispose(() => service.dispose());
  return service;
});

final notificationsProvider = StreamProvider<List<NotificationHistoryData>>((ref) {
  final db = ref.watch(databaseProvider);

  if (PlatformUtils.isLinux) {
    final client = ref.watch(daemonClientProvider);
    final controller = StreamController<List<NotificationHistoryData>>();
    
    Future<void> fetch() async {
      try {
        final entries = await db.getNotifications();
        if (!controller.isClosed) controller.add(entries);
      } catch (_) {}
    }

    fetch();

    final sub = client.dbUpdateStream.where((table) => table == 'notifications').listen((_) {
      fetch();
    });

    ref.onDispose(() {
      sub.cancel();
      controller.close();
    });

    return controller.stream;
  }

  return db.watchNotifications();
});
