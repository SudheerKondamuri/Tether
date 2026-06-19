import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:tether/core/database/app_database.dart';
import 'package:tether/core/networking/connection_manager.dart';
import 'package:tether/core/networking/packet_protocol.dart';

/// Notification model for in-memory display.
class TetherNotification {
  final int? id;
  final String appName;
  final String title;
  final String body;
  final String? iconBase64;
  final DateTime timestamp;
  final bool isRead;

  TetherNotification({
    this.id,
    required this.appName,
    required this.title,
    required this.body,
    this.iconBase64,
    DateTime? timestamp,
    this.isRead = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Listens for notification packets from the Android peer (on Linux)
/// and forwards notifications from the Android OS to the peer (on Android).
///
/// **Flutter-free**: depends only on `ConnectionManager` and `AppDatabase` via
/// constructor injection. No `Ref`, no `MethodChannel`, no `package:flutter`.
class NotificationBridgeService {
  final ConnectionManager _connectionManager;
  final AppDatabase _db;
  StreamSubscription<Packet>? _sub;
  bool _isRunning = false;

  /// Optional callbacks for Android notification access.
  Future<bool> Function()? androidIsPermissionGranted;
  Future<void> Function()? androidRequestPermission;
  Future<void> Function()? androidStartListening;
  Future<void> Function()? androidStopListening;
  void Function(void Function(dynamic args)? onNotification)? androidSetupCallback;

  final _notifController =
      StreamController<List<TetherNotification>>.broadcast();
  Stream<List<TetherNotification>> get notificationStream =>
      _notifController.stream;

  final List<TetherNotification> _notifications = [];
  List<TetherNotification> get notifications =>
      List.unmodifiable(_notifications);

  NotificationBridgeService({
    required ConnectionManager connectionManager,
    required AppDatabase db,
  })  : _connectionManager = connectionManager,
        _db = db;

  /// Start the notification service.
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    if (Platform.isAndroid) {
      if (androidSetupCallback != null) {
        androidSetupCallback!(_sendNotificationToPeer);
      }

      final granted = await isPermissionGranted();
      if (granted) {
        await startListening();
      }
    } else {
      _sub = _connectionManager.packetStream
          .where((p) => p.type == PacketType.notification)
          .listen(_handleNotification);
    }
  }

  /// Stop the notification service.
  void stop() {
    _isRunning = false;
    _sub?.cancel();
    _sub = null;
    if (Platform.isAndroid) {
      if (androidSetupCallback != null) {
        androidSetupCallback!(null);
      }
      stopListening();
    }
  }

  /// Check if Android Notification Access permission is granted.
  Future<bool> isPermissionGranted() async {
    if (!Platform.isAndroid) return true;
    if (androidIsPermissionGranted != null) {
      return await androidIsPermissionGranted!();
    }
    return false;
  }

  /// Request Android Notification Access permission.
  Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    if (androidRequestPermission != null) {
      await androidRequestPermission!();
    }
  }

  /// Start listening to native notifications on Android.
  Future<void> startListening() async {
    if (!Platform.isAndroid) return;
    if (androidStartListening != null) {
      await androidStartListening!();
    }
  }

  /// Stop listening to native notifications on Android.
  Future<void> stopListening() async {
    if (!Platform.isAndroid) return;
    if (androidStopListening != null) {
      await androidStopListening!();
    }
  }

  void _sendNotificationToPeer(dynamic arguments) {
    if (!_connectionManager.isConnected) return;
    try {
      final data = Map<String, dynamic>.from(arguments as Map);
      _connectionManager.sendPacket(Packet(
        type: PacketType.notification,
        deviceId: _connectionManager.deviceId,
        payload: data,
      ));
    } catch (_) {}
  }

  void _handleNotification(Packet packet) {
    final payload = packet.payload;
    final notif = TetherNotification(
      appName: payload['app_name'] as String? ?? payload['app'] as String? ?? 'Unknown',
      title: payload['title'] as String? ?? '',
      body: payload['body'] as String? ?? payload['text'] as String? ?? '',
      iconBase64: payload['icon'] as String? ?? payload['icon_b64'] as String?,
    );

    _notifications.insert(0, notif);

    // Keep max 100 in memory
    if (_notifications.length > 100) {
      _notifications.removeLast();
    }

    _notifController.add(List.unmodifiable(_notifications));

    // Persist to SQLite
    _db.insertNotification(NotificationHistoryCompanion(
      appName: Value(notif.appName),
      packageName: Value(payload['package'] as String? ?? notif.appName),
      title: Value(notif.title),
      body: Value(notif.body),
      iconB64: Value(notif.iconBase64),
      timestamp: Value(notif.timestamp),
    ));

    // Show native Linux desktop notification
    _showNativeNotification(
      appName: notif.appName,
      title: notif.title,
      body: notif.body,
      iconB64: notif.iconBase64,
    );
  }

  Future<void> _showNativeNotification({
    required String appName,
    required String title,
    required String body,
    String? iconB64,
  }) async {
    if (!Platform.isLinux) return;

    final args = <String>[];
    args.add('-a');
    args.add(appName);

    File? tempIconFile;
    if (iconB64 != null && iconB64.isNotEmpty) {
      try {
        final decoded = base64Decode(iconB64);
        final tempDir = Directory.systemTemp;
        tempIconFile = File('${tempDir.path}/tether_notif_${DateTime.now().microsecondsSinceEpoch}.png');
        await tempIconFile.writeAsBytes(decoded);
        args.add('-i');
        args.add(tempIconFile.path);
      } catch (_) {
        // Ignore icon decoding failures
      }
    }

    args.add(title);
    if (body.isNotEmpty) {
      args.add(body);
    }

    try {
      await Process.run('notify-send', args);
    } catch (_) {
      // notify-send might not be installed
    } finally {
      // Clean up the temp icon file after a short delay
      if (tempIconFile != null) {
        Future.delayed(const Duration(seconds: 5), () async {
          try {
            if (await tempIconFile!.exists()) {
              await tempIconFile.delete();
            }
          } catch (_) {}
        });
      }
    }
  }

  /// Mark a notification as read.
  void markRead(int index) {
    if (index < 0 || index >= _notifications.length) return;
    final old = _notifications[index];
    _notifications[index] = TetherNotification(
      id: old.id,
      appName: old.appName,
      title: old.title,
      body: old.body,
      iconBase64: old.iconBase64,
      timestamp: old.timestamp,
      isRead: true,
    );
    _notifController.add(List.unmodifiable(_notifications));
  }

  /// Clear all notifications.
  void clearAll() {
    _notifications.clear();
    _notifController.add([]);
    _db.clearNotifications();
  }

  void dispose() {
    stop();
    _notifController.close();
  }
}


