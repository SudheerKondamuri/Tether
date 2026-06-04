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

}}
