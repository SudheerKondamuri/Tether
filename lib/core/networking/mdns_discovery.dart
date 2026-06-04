import 'dart:async';
import 'dart:io';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/shared/constants.dart';

/// A discovered Tether device on the local network.
class DiscoveredDevice {
  final String name;
  final String ip;
  final int port;
  final DateTime discoveredAt;

  DiscoveredDevice({
    required this.name,
    required this.ip,
    required this.port,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  @override
  bool operator ==(Object other) =>
      other is DiscoveredDevice && other.ip == ip && other.port == port;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode;

  @override
  String toString() => 'DiscoveredDevice($name@$ip:$port)';
}

/// mDNS and UDP Broadcast service for discovering and advertising Tether instances.
class MdnsDiscovery {
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  
  RawDatagramSocket? _udpListenerSocket;
  RawDatagramSocket? _udpDiscoverySocket;
  Timer? _udpPingTimer;

  final _devicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();
  final Set<DiscoveredDevice> _discovered = {};

  Stream<List<DiscoveredDevice>> get devicesStream =>
      _devicesController.stream;
  List<DiscoveredDevice> get devices => _discovered.toList();

  /// Start broadcasting this device as a Tether service (mDNS + UDP).
  Future<void> startBroadcast({
    required String deviceName,
    int port = TetherConstants.tcpPort,
  }) async {
    await stopBroadcast();

    // ─── mDNS Broadcast ───
    try {
      final service = BonsoirService(
        name: deviceName,
        type: TetherConstants.mdnsServiceType,
        port: port,
      );

      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.ready;
      await _broadcast!.start();
    } catch (_) {
      // If mDNS fails (e.g. unsupported platform features), proceed to UDP
    }

    // ─── UDP Broadcast Listener ───
    try {
      _udpListenerSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 5281);
      _udpListenerSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpListenerSocket!.receive();
          if (datagram != null) {
            final text = String.fromCharCodes(datagram.data);
            if (text.startsWith("TETHER_DISCOVER:")) {
              final reply = "TETHER_REPLY:$deviceName:$port";
              _udpListenerSocket!.send(reply.codeUnits, datagram.address, datagram.port);
            }
          }
        }
      });
    } catch (_) {}
  }

  /// Stop broadcasting.
  Future<void> stopBroadcast() async {
    await _broadcast?.stop();
    _broadcast = null;

    _udpListenerSocket?.close();
    _udpListenerSocket = null;
  }

  /// Start discovering other Tether devices on the network (mDNS + UDP).
  Future<void> startDiscovery() async {
    await stopDiscovery();

    // ─── mDNS Discovery ───
    try {
      _discovery = BonsoirDiscovery(
        type: TetherConstants.mdnsServiceType,
      );
      await _discovery!.ready;

      _discovery!.eventStream!.listen((event) {
        if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
          event.service!.resolve(_discovery!.serviceResolver);
        } else if (event.type ==
            BonsoirDiscoveryEventType.discoveryServiceResolved) {
          final resolved = event.service as ResolvedBonsoirService;
          final device = DiscoveredDevice(
            name: resolved.name,
            ip: resolved.host ?? '',
            port: resolved.port,
          );
          if (device.ip.isNotEmpty) {
            _discovered.add(device);
            _devicesController.add(_discovered.toList());
          }
        } else if (event.type ==
            BonsoirDiscoveryEventType.discoveryServiceLost) {
          _discovered.removeWhere(
              (d) => d.name == event.service?.name);
          _devicesController.add(_discovered.toList());
        }
      });

      await _discovery!.start();
    } catch (_) {}

    // ─── UDP Broadcast Discovery ───
    try {
      _udpDiscoverySocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _udpDiscoverySocket!.broadcastEnabled = true;

      _udpPingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        const ping = "TETHER_DISCOVER:ping";
        _udpDiscoverySocket?.send(ping.codeUnits, InternetAddress("255.255.255.255"), 5281);
      });

      _udpDiscoverySocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpDiscoverySocket!.receive();
          if (datagram != null) {
            final text = String.fromCharCodes(datagram.data);
            if (text.startsWith("TETHER_REPLY:")) {
              final parts = text.split(":");
              if (parts.length >= 3) {
                final name = parts[1];
                final port = int.tryParse(parts[2]) ?? TetherConstants.tcpPort;
                final device = DiscoveredDevice(
                  name: name,
                  ip: datagram.address.address,
                  port: port,
                );
                _discovered.add(device);
                _devicesController.add(_discovered.toList());
              }
            }
          }
        }
      });
    } catch (_) {}
  }

  /// Stop discovering.
  Future<void> stopDiscovery() async {
    await _discovery?.stop();
    _discovery = null;

    _udpPingTimer?.cancel();
    _udpPingTimer = null;

    _udpDiscoverySocket?.close();
    _udpDiscoverySocket = null;

    _discovered.clear();
  }

  /// Stop everything and clean up.
  Future<void> dispose() async {
    await stopBroadcast();
    await stopDiscovery();
    await _devicesController.close();
  }
}

// ─── Riverpod Providers ───

final mdnsDiscoveryProvider = Provider<MdnsDiscovery>((ref) {
  final discovery = MdnsDiscovery();
  ref.onDispose(() => discovery.dispose());
  return discovery;
});

final discoveredDevicesProvider = StreamProvider<List<DiscoveredDevice>>((ref) {
  final discovery = ref.watch(mdnsDiscoveryProvider);
  return discovery.devicesStream;
});
