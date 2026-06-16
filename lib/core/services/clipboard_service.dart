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

/// Type classification for clipboard content.
enum ClipType { text, url, otp, filePath, code, other }

/// Single clipboard history entry.
class ClipEntry {
  final int? id;
  final String content;
  final ClipType type;
  final String source; // 'local' or device name
  final DateTime timestamp;
  final bool pinned;

  ClipEntry({
    this.id,
    required this.content,
    required this.type,
    required this.source,
    DateTime? timestamp,
    this.pinned = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Watches the system clipboard, detects changes, syncs with peer,
/// and maintains local history in SQLite.
class ClipboardService {
  final ConnectionManager _connectionManager;
  final AppDatabase _db;
  Timer? _pollTimer;
  String _lastClipboard = '';
  bool _isRunning = false;

  static const _channel = MethodChannel(TetherConstants.clipboardChannel);

  final _historyController = StreamController<List<ClipEntry>>.broadcast();
  Stream<List<ClipEntry>> get historyStream => _historyController.stream;

  final List<ClipEntry> _history = [];
  List<ClipEntry> get history => List.unmodifiable(_history);

  ClipboardService({
    required ConnectionManager connectionManager,
    required AppDatabase db,
  })  : _connectionManager = connectionManager,
        _db = db;

  /// Start polling/listening to the system clipboard.
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // Listen for incoming clipboard packets from peer
    _connectionManager.packetStream
        .where((p) => p.type == PacketType.clipboardUpdate)
        .listen(_handleIncomingClipboard);

    if (Platform.isAndroid) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onClipboardChanged') {
          final text = call.arguments['text'] as String? ?? '';
          _onLocalClipboardChanged(text);
        }
      });
      _channel.invokeMethod('startListening');
    } else {
      // Poll system clipboard for Linux/non-Android
      _pollTimer = Timer.periodic(
        TetherConstants.clipboardPollInterval,
        (_) => _checkClipboard(),
      );
    }
  }

  /// Stop the clipboard service.
  void stop() {
    _isRunning = false;
    if (Platform.isAndroid) {
      _channel.invokeMethod('stopListening');
      _channel.setMethodCallHandler(null);
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  /// Check system clipboard for changes (Linux fallback).
  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      await _onLocalClipboardChanged(text);
    } catch (_) {
      // Clipboard access may fail on some platforms
    }
  }

  /// Handle local clipboard changed event.
  Future<void> _onLocalClipboardChanged(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed == _lastClipboard) return;

    _lastClipboard = trimmed;
    final type = _detectType(trimmed);
    final entry = ClipEntry(
      content: trimmed,
      type: type,
      source: 'local',
    );

    _addToHistory(entry);
    _syncToPeer(entry);

    // Save to database
    await _db.insertClipboardEntry(ClipboardEntriesCompanion(
      content: Value(trimmed),
      dataType: Value(type.name),
      sourceDevice: Value('local'),
      timestamp: Value(DateTime.now()),
    ));
  }

  /// Handle incoming clipboard update from peer.
  void _handleIncomingClipboard(Packet packet) {
    final payload = packet.payload;
    final text = payload['content'] as String? ?? '';
    if (text.isEmpty) return;

    final type = _detectType(text);
    final source = _connectionManager.peer?.name ?? 'remote';

    final entry = ClipEntry(
      content: text,
      type: type,
      source: source,
    );

    _addToHistory(entry);

    // Update the local clipboard
    _lastClipboard = text;
    if (Platform.isAndroid) {
      _channel.invokeMethod('setClipboard', {'text': text});
    } else {
      Clipboard.setData(ClipboardData(text: text));
    }

    // Save to database
    _db.insertClipboardEntry(ClipboardEntriesCompanion(
      content: Value(text),
      dataType: Value(type.name),
      sourceDevice: Value(source),
      timestamp: Value(DateTime.now()),
    ));
  }

  /// Send clipboard content to the connected peer.
  void _syncToPeer(ClipEntry entry) {
    if (!_connectionManager.isConnected) return;

    _connectionManager.sendPacket(Packet(
      type: PacketType.clipboardUpdate,
      deviceId: _connectionManager.deviceId,
      payload: {
        'content': entry.content,
        'type': entry.type.name,
        'source': entry.source,
      },
    ));
  }

  /// Add an entry to the in-memory history ring buffer.
  void _addToHistory(ClipEntry entry) {
    _history.insert(0, entry);
    if (_history.length > TetherConstants.clipboardMaxHistory) {
      _history.removeLast();
    }
    _historyController.add(List.unmodifiable(_history));
  }

  /// Detect the type of clipboard content.
  ClipType _detectType(String text) {
    if (TetherConstants.otpRegex.hasMatch(text) && text.length <= 8) {
      return ClipType.otp;
    }
    if (TetherConstants.urlRegex.hasMatch(text)) {
      return ClipType.url;
    }
    if (TetherConstants.filePathRegex.hasMatch(text)) {
      return ClipType.filePath;
    }
    // Simple code detection: contains common code patterns
    if (text.contains('{') && text.contains('}') ||
        text.contains('function') ||
        text.contains('class ') ||
        text.contains('import ')) {
      return ClipType.code;
    }
    return ClipType.text;
  }

  /// Copy a history entry back to the system clipboard.
  Future<void> copyToClipboard(ClipEntry entry) async {
    _lastClipboard = entry.content;
    if (Platform.isAndroid) {
      await _channel.invokeMethod('setClipboard', {'text': entry.content});
    } else {
      await Clipboard.setData(ClipboardData(text: entry.content));
    }
  }

  /// Clear all history.
  void clearHistory() {
    _history.clear();
    _historyController.add([]);
  }

  void dispose() {
    stop();
    _historyController.close();
  }
}

// ─── Riverpod Providers ───

final clipboardServiceProvider = Provider<ClipboardService>((ref) {
  final connManager = ref.watch(connectionManagerProvider);
  final db = ref.watch(databaseProvider);
  final service = ClipboardService(
    connectionManager: connManager,
    db: db,
  );
  ref.onDispose(() => service.dispose());
  return service;
});

final clipboardHistoryProvider = StreamProvider<List<ClipboardEntry>>((ref) {
  final db = ref.watch(databaseProvider);

  if (Platform.isAndroid) {
    // CRITICAL: Kotlin writes clipboard entries directly to SQLite via
    // TetherDatabase.kt, bypassing Drift's internal change notification
    // system. Use periodic polling so the UI sees entries written by the
    // native foreground service.
    return Stream.periodic(const Duration(seconds: 1), (i) => i)
        .asyncMap((_) => db.getClipboardEntries());
  }

  // Desktop: Drift's watch() works because Dart writes the entries itself
  return db.watchClipboardEntries();
});
