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

}}
