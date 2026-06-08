import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:tether/core/networking/tcp_server.dart';
import 'package:tether/core/networking/tcp_client.dart';
import 'package:tether/core/networking/packet_protocol.dart';
import 'package:tether/shared/constants.dart';
import 'package:tether/shared/platform_utils.dart';
import 'package:tether/core/database/database_provider.dart';
import 'package:tether/core/database/app_database.dart';
import 'package:tether/core/networking/mdns_discovery.dart';

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

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'name': name,
        'platform': platform,
        'ip': ip,
        'port': port,
        'battery': battery,
        'wifiStrength': wifiStrength,
        'lastSeen': lastSeen.toIso8601String(),
      };

  factory ConnectedDevice.fromJson(Map<String, dynamic> json) {
    return ConnectedDevice(
      deviceId: json['deviceId'] as String,
      name: json['name'] as String,
      platform: json['platform'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int,
      battery: json['battery'] as int?,
      wifiStrength: json['wifiStrength'] as int?,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : null,
    );
  }
}

/// Connection state enum — prefixed to avoid collision with Flutter's ConnectionState.
enum TetherConnectionState { disconnected, searching, connecting, connected }

/// Orchestrates TCP server + client, manages connection lifecycle.
class ConnectionManager {
  final Ref ref;
  final TcpServer _server = TcpServer();
  final TcpClient _client = TcpClient();

  static bool isBackgroundIsolate = false;
  String _deviceId = const Uuid().v4();
  String _deviceName = Platform.localHostname;

  String get deviceId => _deviceId;
  String get deviceName => _deviceName;

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

  ConnectionManager({required this.ref});

  Future<void> init() async {
    final db = ref.read(databaseProvider);
    
    // Load or generate device ID
    var storedId = await db.getSetting('device_id');
    if (storedId == null || storedId.isEmpty) {
      storedId = const Uuid().v4();
      await db.setSetting('device_id', storedId);
    }
    _deviceId = storedId;

    // Load or generate device Name
    var storedName = await db.getSetting('device_name');
    if (storedName == null || storedName.isEmpty) {
      storedName = Platform.localHostname;
      await db.setSetting('device_name', storedName);
    }
    _deviceName = storedName;

    // Initialize state in database settings
    await db.setSetting('connection_state', _state.name);
    _updatePeerInSettings(_peer);

    // Listen to discovery events to evaluate peers for auto-connection
    ref.read(mdnsDiscoveryProvider).devicesStream.listen((devices) {
      if (_state == TetherConnectionState.connected || _state == TetherConnectionState.connecting) {
        return;
      }
      for (final device in devices) {
        evaluateDiscoveredPeer(device.name, device.ip, device.port, device.nonce, device.discoveryHash);
      }
    });
  }

  void evaluateDiscoveredPeer(String peerName, String host, int port, int peerNonce, String? discoveryHash) {
    final mdns = ref.read(mdnsDiscoveryProvider);
    final myNonce = mdns.discoverySessionNonce;

    if (myNonce == peerNonce) return; // Self detection protection

    // If peer broadcasts a discovery hash, check if it matches a known paired device
    if (discoveryHash != null && discoveryHash.isNotEmpty) {
      _tryAutoConnect(host, port, peerNonce, discoveryHash);
      return;
    }

    if (myNonce > peerNonce) {
      // Deterministic Client assignment
      connectTo(host: host, port: port);
    } else {
      // Deterministic Server lock -- yields execution path to let inbound socket attach cleanly
      developer.log("Yielding connection initialization role to peer node: $peerName");
    }
  }

  Future<void> _tryAutoConnect(String host, int port, int peerNonce, String discoveryHash) async {
    final db = ref.read(databaseProvider);
    final pairedDevices = await db.getPairedDevices();
    final knownFingerprints = pairedDevices.map((d) => d.certFingerprint).toList();

    final matchedFp = CryptoUtils.verifyDiscoveryHash(discoveryHash, knownFingerprints);
    if (matchedFp != null) {
      developer.log('Auto-connecting to paired device (fingerprint match: ${matchedFp.substring(0, 8)}...)');
      final mdns = ref.read(mdnsDiscoveryProvider);
      final myNonce = mdns.discoverySessionNonce;
      if (myNonce > peerNonce) {
        connectTo(host: host, port: port);
      } else {
        developer.log('Yielding auto-connect role to peer');
      }
    }
  }

  void _updatePeerInSettings(ConnectedDevice? peer) {
    final db = ref.read(databaseProvider);
    if (peer == null) {
      db.setSetting('connected_peer', '');
    } else {
      db.setSetting('connected_peer', jsonEncode(peer.toJson()));
    }
  }

  /// Start the TCP server and begin accepting connections.
  Future<void> startServer() async {
    _server.onPacket = _handleServerPacket;
    _server.onConnect = (socket) {
      _updateState(TetherConnectionState.connecting);
    };
    _server.onDisconnect = (socket) {
      _peer = null;
      _peerController.add(null);
      _updatePeerInSettings(null);
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
    if (PlatformUtils.isAndroid && !isBackgroundIsolate) {
      try {
        await const MethodChannel(TetherConstants.foregroundServiceChannel)
            .invokeMethod('sendBackgroundCommand', {
          'command': 'CONNECT_TO',
          'args': {
            'host': host,
            'port': port,
          },
        });
        return true;
      } catch (e) {
        developer.log('Failed to delegate connectTo to background service: $e');
        return false;
      }
    }

    _updateState(TetherConnectionState.connecting);

    _client.onPacket = _handleClientPacket;
    _client.onConnectionChanged = (connected) {
      if (!connected) {
        _peer = null;
        _peerController.add(null);
        _updatePeerInSettings(null);
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
      _updatePeerInSettings(_peer);
      _updateState(TetherConnectionState.connected);

      // Extract peer's TLS certificate fingerprint and store pairing record
      _storePairingRecord(packet.deviceId, hs.name, hs.platform, socket.peerCertificate, socket.remoteAddress.address, socket.remotePort);

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
        _updatePeerInSettings(_peer);
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
      _updatePeerInSettings(_peer);
      _updateState(TetherConnectionState.connected);

      // Extract peer's TLS certificate fingerprint and store pairing record
      _storePairingRecord(
        packet.deviceId, hs.name, hs.platform,
        _client.socket?.peerCertificate,
        _client.host ?? '', _client.port ?? TetherConstants.tcpPort,
      );
    } else if (packet.type == PacketType.heartbeat) {
      final hb = HeartbeatPayload.fromJson(packet.payload);
      if (_peer != null) {
        _peer!.battery = hb.battery;
        _peer!.wifiStrength = hb.wifiStrength;
        _peer!.lastSeen = DateTime.now();
        _peerController.add(_peer);
        _updatePeerInSettings(_peer);
      }
    }

    _packetController.add(packet);
  }

  /// Store or update a pairing record from the TLS handshake certificate.
  void _storePairingRecord(
    String peerDeviceId, String peerName, String peerPlatform,
    X509Certificate? cert, String ip, int port,
  ) {
    if (cert == null) return;
    final pem = cert.pem;
    final fingerprint = sha256.convert(cert.der).bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':');
    
    final db = ref.read(databaseProvider);
    db.upsertPairedDevice(PairedDevicesCompanion(
      deviceId: Value(peerDeviceId),
      name: Value(peerName),
      platform: Value(peerPlatform),
      certPem: Value(pem),
      certFingerprint: Value(fingerprint),
      lastIp: Value(ip),
      lastPort: Value(port),
      pairedAt: Value(DateTime.now()),
    ));
    developer.log('Stored pairing record for $peerName ($peerDeviceId)');
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
    // Write state to database settings for UI cross-isolate synchronization
    ref.read(databaseProvider).setSetting('connection_state', newState.name);
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
  final manager = ConnectionManager(ref: ref);
  ref.onDispose(() => manager.dispose());
  return manager;
});

final connectionStateProvider = StreamProvider<TetherConnectionState>((ref) {
  if (PlatformUtils.isAndroid) {
    final db = ref.watch(databaseProvider);
    return db.watchSetting('connection_state').map((val) {
      if (val == null) return TetherConnectionState.disconnected;
      return TetherConnectionState.values.firstWhere(
        (e) => e.name == val,
        orElse: () => TetherConnectionState.disconnected,
      );
    });
  }
  final manager = ref.watch(connectionManagerProvider);
  return manager.stateStream;
});

final connectedDeviceProvider = StreamProvider<ConnectedDevice?>((ref) {
  if (PlatformUtils.isAndroid) {
    final db = ref.watch(databaseProvider);
    return db.watchSetting('connected_peer').map((val) {
      if (val == null || val.isEmpty) return null;
      try {
        return ConnectedDevice.fromJson(jsonDecode(val) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    });
  }
  final manager = ref.watch(connectionManagerProvider);
  return manager.peerStream;
});
