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
    _server = await SecureServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
      ctx,
    );

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

}}}
