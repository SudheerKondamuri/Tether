// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:tether/core/networking/connection_manager.dart';
import 'package:tether/shared/constants.dart';
import 'package:tether/shared/platform_utils.dart';

const String _socketPath = '/tmp/tetherd.sock';

/// Client bridge that connects the Flutter GUI process to the background `tetherd` daemon.
/// Handles auto-spawning the daemon if not running, UDS communication, and exposes
/// streams mirroring the core connection layer.
class DaemonClient {
  Socket? _socket;
  bool _isConnecting = false;

  final _stateController = StreamController<TetherConnectionState>.broadcast();
  final _peerController = StreamController<ConnectedDevice?>.broadcast();
  final _dbUpdateController = StreamController<String>.broadcast();

  Stream<TetherConnectionState> get stateStream => _stateController.stream;
  Stream<ConnectedDevice?> get peerStream => _peerController.stream;
  Stream<String> get dbUpdateStream => _dbUpdateController.stream;

  TetherConnectionState _state = TetherConnectionState.disconnected;
  ConnectedDevice? _peer;

  TetherConnectionState get state => _state;
  ConnectedDevice? get peer => _peer;
  bool get isConnected => _state == TetherConnectionState.connected;

  DaemonClient() {
    if (PlatformUtils.isLinux) {
      _connectWithRetry();
    }
  }

  Future<void> _connectWithRetry() async {
    if (_isConnecting) return;
    _isConnecting = true;

    int attempts = 0;
    while (_socket == null && _isConnecting) {
      try {
        _socket = await Socket.connect(InternetAddress(_socketPath, type: InternetAddressType.unix), 0);
        _isConnecting = false;
        _handleSocketConnection(_socket!);
        break;
      } catch (_) {
        attempts++;
        if (attempts == 1) {
          // Attempt to spawn the daemon since it's not running
          try {
            await _spawnDaemon();
          } catch (e) {
            print('Failed to spawn tetherd: $e');
          }
        }
        
        if (attempts >= 10) {
          // Timeout or persistent failure
          _stateController.add(TetherConnectionState.disconnected);
          _isConnecting = false;
          break;
        }
        
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  void _handleSocketConnection(Socket socket) {
    print('Connected to tetherd IPC socket.');
    
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          _handleIpcMessage(line);
        }, onError: (e) {
          print('IPC socket error: $e');
          _onSocketDisconnected();
        }, onDone: () {
          print('IPC socket disconnected.');
          _onSocketDisconnected();
        });
  }

  void _handleIpcMessage(String line) {
    if (line.isEmpty) return;
    try {
      final msg = jsonDecode(line) as Map<String, dynamic>;
      final type = msg['type'] as String?;

      if (type == 'state') {
        final stateStr = msg['connectionState'] as String?;
        final peerJson = msg['peer'] as Map<String, dynamic>?;

        final newState = TetherConnectionState.values.firstWhere(
          (e) => e.name == stateStr,
          orElse: () => TetherConnectionState.disconnected,
        );

        final newPeer = peerJson != null ? ConnectedDevice.fromJson(peerJson) : null;

        _state = newState;
        _peer = newPeer;

        _stateController.add(newState);
        _peerController.add(newPeer);
      } else if (type == 'db_update') {
        final table = msg['table'] as String? ?? '';
        _dbUpdateController.add(table);
      }
    } catch (e) {
      print('Failed to parse IPC message: $line, error: $e');
    }
  }

  void _onSocketDisconnected() {
    _socket?.destroy();
    _socket = null;
    _state = TetherConnectionState.disconnected;
    _peer = null;
    _stateController.add(TetherConnectionState.disconnected);
    _peerController.add(null);
    
    // Retry connecting
    _connectWithRetry();
  }

  Future<void> connectTo({required String host, int port = TetherConstants.tcpPort}) async {
    final msg = {
      'command': 'connectTo',
      'host': host,
      'port': port,
    };
    _sendIpcMessage(msg);
  }

  Future<void> disconnect() async {
    final msg = {
      'command': 'disconnect',
    };
    _sendIpcMessage(msg);
  }

  void _sendIpcMessage(Map<String, dynamic> msg) {
    if (_socket == null) {
      print('Warning: socket not connected, cannot send IPC command.');
      return;
    }
    try {
      _socket!.write('${jsonEncode(msg)}\n');
    } catch (e) {
      print('Failed to send IPC message: $e');
    }
  }

  Future<void> _spawnDaemon() async {
    // 1. Try adjacent to resolved executable path (production release bundle)
    final resolvedPath = Platform.resolvedExecutable;
    final parentDir = Directory(p.dirname(resolvedPath));
    final adjacentExec = File(p.join(parentDir.path, 'tetherd'));
    if (await adjacentExec.exists()) {
      await Process.start(adjacentExec.path, [], mode: ProcessStartMode.detached);
      return;
    }

    // 2. Try searching upwards from resolved executable to find project root (development/debug mode)
    var dir = Directory(parentDir.path);
    while (true) {
      // Check for compiled CLI bundle in build directory
      final devFile = File(p.join(dir.path, 'build', 'cli', 'bundle', 'bin', 'tetherd'));
      if (await devFile.exists()) {
        await Process.start(
          devFile.path,
          [],
          mode: ProcessStartMode.detached,
          workingDirectory: p.dirname(devFile.path),
        );
        return;
      }

      // Check for source file in project root
      final devSrc = File(p.join(dir.path, 'bin', 'tetherd.dart'));
      if (await devSrc.exists()) {
        await Process.start(
          'dart',
          ['run', 'bin/tetherd.dart'],
          mode: ProcessStartMode.detached,
          workingDirectory: dir.path,
        );
        return;
      }

      final parent = dir.parent;
      if (parent.path == dir.path) {
        break; // Reached system root
      }
      dir = parent;
    }

    // 3. Last resort fallback to current directory ./tetherd or bin/tetherd.dart
    final localExec = File('./tetherd');
    if (await localExec.exists()) {
      await Process.start('./tetherd', [], mode: ProcessStartMode.detached);
      return;
    }

    final devPath = File('bin/tetherd.dart');
    if (await devPath.exists()) {
      await Process.start('dart', ['run', 'bin/tetherd.dart'], mode: ProcessStartMode.detached);
      return;
    }

    throw StateError('Cannot locate tetherd executable or source code to spawn daemon.');
  }

  void dispose() {
    _isConnecting = false;
    _socket?.destroy();
    _socket = null;
    _stateController.close();
    _peerController.close();
    _dbUpdateController.close();
  }
}

// ─── Riverpod Providers ───

final daemonClientProvider = Provider<DaemonClient>((ref) {
  final client = DaemonClient();
  ref.onDispose(() => client.dispose());
  return client;
});

final daemonConnectionStateProvider = StreamProvider<TetherConnectionState>((ref) {
  final client = ref.watch(daemonClientProvider);
  return client.stateStream;
});

final daemonConnectedDeviceProvider = StreamProvider<ConnectedDevice?>((ref) {
  final client = ref.watch(daemonClientProvider);
  return client.peerStream;
});
