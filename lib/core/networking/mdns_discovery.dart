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


}}
