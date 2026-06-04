import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/core/database/app_database.dart';
import 'package:tether/core/database/database_provider.dart';
import 'package:tether/core/networking/connection_manager.dart';
import 'package:tether/core/networking/packet_protocol.dart';
import 'package:tether/shared/constants.dart';

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
class NotificationBridgeService {
  final ConnectionManager _connectionManager;
  final AppDatabase _db;
  StreamSubscription<Packet>? _sub;
  bool _isRunning = false;

  static const _channel = MethodChannel(TetherConstants.notificationChannel);

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
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onNotificationPosted') {
          _sendNotificationToPeer(call.arguments);
        }
      });

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
      _channel.setMethodCallHandler(null);
      stopListening();
    }
  }

  /// Check if Android Notification Access permission is granted.
  Future<bool> isPermissionGranted() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('isPermissionGranted') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request Android Notification Access permission.
  Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (_) {}
  }

  /// Start listening to native notifications on Android.
  Future<void> startListening() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startListening');
    } catch (_) {}
  }

  /// Stop listening to native notifications on Android.
  Future<void> stopListening() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopListening');
    } catch (_) {}
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
      appName: payload['app_name'] as String? ?? 'Unknown',
      title: payload['title'] as String? ?? '',
      body: payload['body'] as String? ?? '',
      iconBase64: payload['icon'] as String?,
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


// ─── Riverpod Providers ───

final notificationBridgeProvider = Provider<NotificationBridgeService>((ref) {
  final connManager = ref.watch(connectionManagerProvider);
  final db = ref.watch(databaseProvider);
  final service = NotificationBridgeService(
    connectionManager: connManager,
    db: db,
  );
  ref.onDispose(() => service.dispose());
  return service;
});

final notificationsProvider =
    StreamProvider<List<TetherNotification>>((ref) {
  final service = ref.watch(notificationBridgeProvider);
  return service.notificationStream;
});
