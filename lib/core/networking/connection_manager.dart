import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:tether/core/networking/tcp_server.dart';
import 'package:tether/core/networking/tcp_client.dart';
import 'package:tether/core/networking/packet_protocol.dart';
import 'package:tether/shared/constants.dart';
import 'package:tether/shared/platform_utils.dart';

/// Represents a connected peer device.
class ConnectedDevice {
  final String deviceId;
  final String name;
  final String platform;
  final String ip;
  final int port;
  int? battery;
  int? wifiStrength;
  DateTime lastSeen;

  ConnectedDevice({
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.ip,
    required this.port,
    this.battery,
    this.wifiStrength,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();
}

/// Connection state enum — prefixed to avoid collision with Flutter's ConnectionState.
enum TetherConnectionState { disconnected, searching, connecting, connected }

/// Orchestrates TCP server + client, manages connection lifecycle.
class ConnectionManager {
  final TcpServer _server = TcpServer();
  final TcpClient _client = TcpClient();
  final String deviceId;
  final String deviceName;

  ConnectedDevice? _peer;
  TetherConnectionState _state = TetherConnectionState.disconnected;

  final _stateController = StreamController<TetherConnectionState>.broadcast();
  final _peerController = StreamController<ConnectedDevice?>.broadcast();
  final _packetController = StreamController<Packet>.broadcast();

  Stream<TetherConnectionState> get stateStream => _stateController.stream;
  Stream<ConnectedDevice?> get peerStream => _peerController.stream;
  Stream<Packet> get packetStream => _packetController.stream;

  TetherConnectionState get state => _state;
  ConnectedDevice? get peer => _peer;
  bool get isConnected => _state == TetherConnectionState.connected;

  ConnectionManager({
    String? deviceId,
    String? deviceName,
  })  : deviceId = deviceId ?? const Uuid().v4(),
        deviceName = deviceName ?? Platform.localHostname;

  /// Start the TCP server and begin accepting connections.
  Future<void> startServer() async {
    _server.onPacket = _handleServerPacket;
    _server.onConnect = (socket) {
      _updateState(TetherConnectionState.connecting);
    };
    _server.onDisconnect = (socket) {
      _peer = null;
      _peerController.add(null);
      _updateState(TetherConnectionState.disconnected);
    };

    await _server.start();
    _updateState(TetherConnectionState.searching);
  }

  /// Connect to a peer device as a client.
  Future<bool> connectTo({
    required String host,
    int port = TetherConstants.tcpPort,
  }) async {
    _updateState(TetherConnectionState.connecting);

    _client.onPacket = _handleClientPacket;
    _client.onConnectionChanged = (connected) {
      if (!connected) {
        _peer = null;
        _peerController.add(null);
        _updateState(TetherConnectionState.disconnected);
      }
    };

    final success = await _client.connect(
      host: host,
      port: port,
      deviceId: deviceId,
    );

    if (success) {
      // Send handshake
      _client.send(Packet(
        type: PacketType.handshake,
        deviceId: deviceId,
        payload: HandshakePayload(
          name: deviceName,
          platform: PlatformUtils.platformName,
          version: TetherConstants.appVersion,
        ).toJson(),
      ));
    } else {
      _updateState(TetherConnectionState.disconnected);
    }

    return success;
  }

  void _handleServerPacket(Packet packet, SecureSocket socket) {
    if (packet.type == PacketType.handshake) {
      final hs = HandshakePayload.fromJson(packet.payload);
      _peer = ConnectedDevice(
        deviceId: packet.deviceId,
        name: hs.name,
        platform: hs.platform,
        ip: socket.remoteAddress.address,
        port: socket.remotePort,
      );
      _peerController.add(_peer);
      _updateState(TetherConnectionState.connected);

      // Send our handshake back
      _server.broadcast(Packet(
        type: PacketType.handshake,
        deviceId: deviceId,
        payload: HandshakePayload(
          name: deviceName,
          platform: PlatformUtils.platformName,
          version: TetherConstants.appVersion,
        ).toJson(),
      ));
    } else if (packet.type == PacketType.heartbeat) {
      final hb = HeartbeatPayload.fromJson(packet.payload);
      if (_peer != null) {
        _peer!.battery = hb.battery;
        _peer!.wifiStrength = hb.wifiStrength;
        _peer!.lastSeen = DateTime.now();
        _peerController.add(_peer);
      }
    }

    _packetController.add(packet);
  }

  void _handleClientPacket(Packet packet) {
    if (packet.type == PacketType.handshake) {
      final hs = HandshakePayload.fromJson(packet.payload);
      _peer = ConnectedDevice(
        deviceId: packet.deviceId,
        name: hs.name,
        platform: hs.platform,
        ip: _client.host ?? '',
        port: _client.port ?? TetherConstants.tcpPort,
      );
      _peerController.add(_peer);
      _updateState(TetherConnectionState.connected);
    } else if (packet.type == PacketType.heartbeat) {
      final hb = HeartbeatPayload.fromJson(packet.payload);
      if (_peer != null) {
        _peer!.battery = hb.battery;
        _peer!.wifiStrength = hb.wifiStrength;
        _peer!.lastSeen = DateTime.now();
        _peerController.add(_peer);
      }
    }

    _packetController.add(packet);
  }

  /// Send a packet to the connected peer.
  void sendPacket(Packet packet) {
    if (_client.isConnected) {
      _client.send(packet);
    } else if (_server.isRunning) {
      _server.broadcast(packet);
    }
  }

  void _updateState(TetherConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Disconnect and stop everything.
  Future<void> dispose() async {
    await _client.disconnect();
    await _server.stop();
    await _stateController.close();
    await _peerController.close();
    await _packetController.close();
  }
}

// ─── Riverpod Providers ───

final connectionManagerProvider = Provider<ConnectionManager>((ref) {
  final manager = ConnectionManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

final connectionStateProvider = StreamProvider<TetherConnectionState>((ref) {
  final manager = ref.watch(connectionManagerProvider);
  return manager.stateStream;
});

final connectedDeviceProvider = StreamProvider<ConnectedDevice?>((ref) {
  final manager = ref.watch(connectionManagerProvider);
  return manager.peerStream;
});
