import 'dart:async';
import 'dart:io';
import 'package:tether/core/networking/packet_protocol.dart';
import 'package:tether/core/networking/tls_manager.dart';
import 'package:tether/shared/constants.dart';

/// Callback for when a packet is received from a connected peer.
typedef PacketHandler = void Function(Packet packet, SecureSocket socket);

/// Callback for connection lifecycle events.
typedef ConnectionHandler = void Function(SecureSocket socket);

/// Always-on TLS TCP server that listens for incoming peer connections.
class TcpServer {
  SecureServerSocket? _server;
  final Map<String, SecureSocket> _clients = {};
  final Map<String, PacketCodec> _codecs = {};
  final Map<String, Timer> _heartbeatTimers = {};

  PacketHandler? onPacket;
  ConnectionHandler? onConnect;
  ConnectionHandler? onDisconnect;

  bool get isRunning => _server != null;
  int get clientCount => _clients.length;

  /// Start listening on the given port.
  Future<void> start({int port = TetherConstants.tcpPort}) async {
    if (_server != null) return;

    final ctx = await TlsManager.createServerContext();
    int retries = 0;
    while (retries < 5) {
      try {
        _server = await SecureServerSocket.bind(
          InternetAddress.anyIPv4,
          port,
          ctx,
          shared: true, // MANDATORY: Bypasses OS TIME_WAIT locks after process eviction
        );
        break;
      } catch (e) {
        retries++;
        if (retries >= 5) rethrow;
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    _server!.listen(
      _handleConnection,
      onError: (e) {
        // Log error, keep running
      },
      onDone: () {
        _server = null;
      },
    );
  }

  void _handleConnection(SecureSocket socket) {
    final remoteId = '${socket.remoteAddress.address}:${socket.remotePort}';
    _clients[remoteId] = socket;
    _codecs[remoteId] = PacketCodec();

    onConnect?.call(socket);
    _startHeartbeatMonitor(remoteId);

    socket.listen(
      (data) {
        final codec = _codecs[remoteId];
        if (codec == null) return;

        final packets = codec.decode(data);
        for (final packet in packets) {
          if (packet.type == PacketType.heartbeat) {
            _resetHeartbeatTimer(remoteId);
          }
          onPacket?.call(packet, socket);
        }
      },
      onError: (e) {
        _removeClient(remoteId);
      },
      onDone: () {
        _removeClient(remoteId);
      },
    );
  }

  void _startHeartbeatMonitor(String remoteId) {
    _heartbeatTimers[remoteId]?.cancel();
    _heartbeatTimers[remoteId] = Timer(
      TetherConstants.heartbeatTimeout,
      () => _removeClient(remoteId),
    );
  }

  void _resetHeartbeatTimer(String remoteId) {
    _startHeartbeatMonitor(remoteId);
  }

  void _removeClient(String remoteId) {
    final socket = _clients.remove(remoteId);
    _codecs.remove(remoteId);
    _heartbeatTimers.remove(remoteId)?.cancel();
    if (socket != null) {
      onDisconnect?.call(socket);
      socket.destroy();
    }
  }

  /// Send a packet to a specific client.
  void sendTo(String remoteId, Packet packet) {
    final socket = _clients[remoteId];
    if (socket != null) {
      socket.add(packet.encode());
    }
  }

  /// Broadcast a packet to all connected clients.
  void broadcast(Packet packet) {
    final encoded = packet.encode();
    for (final socket in _clients.values) {
      socket.add(encoded);
    }
  }

  /// Stop the server and disconnect all clients.
  Future<void> stop() async {
    for (final remoteId in _clients.keys.toList()) {
      _removeClient(remoteId);
    }
    await _server?.close();
    _server = null;
  }
}
