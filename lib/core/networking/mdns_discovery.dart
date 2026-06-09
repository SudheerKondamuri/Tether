import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:bonsoir/bonsoir.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/shared/constants.dart';
import 'package:tether/shared/platform_utils.dart';
import 'package:tether/core/database/database_provider.dart';
import 'package:tether/core/networking/tls_manager.dart';

/// Rotating cryptographic hashes for secure peer identification.
class CryptoUtils {
  /// Compute a discovery hash for a given cert fingerprint.
  /// Uses 5-minute time-epoch salt so the hash rotates every 5 minutes.
  static String computeDiscoveryHash(String certFingerprint) {
    final epoch = DateTime.now().millisecondsSinceEpoch ~/ (5 * 60 * 1000);
    final input = '$certFingerprint:$epoch';
    return sha256.convert(utf8.encode(input)).toString().substring(0, 16);
  }

  /// Verify if a received hash matches any of the given cert fingerprints.
  /// Checks both current and previous time epochs to handle clock boundary.
  static String? verifyDiscoveryHash(
      String receivedHash, List<String> knownFingerprints) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final currentEpoch = nowMs ~/ (5 * 60 * 1000);
    final previousEpoch = currentEpoch - 1;

    for (final fp in knownFingerprints) {
      final currentInput = '$fp:$currentEpoch';
      final currentHash =
          sha256.convert(utf8.encode(currentInput)).toString().substring(0, 16);
      if (currentHash == receivedHash) return fp;

      final prevInput = '$fp:$previousEpoch';
      final prevHash =
          sha256.convert(utf8.encode(prevInput)).toString().substring(0, 16);
      if (prevHash == receivedHash) return fp;
    }
    return null;
  }
}

/// A discovered Tether device on the local network.
class DiscoveredDevice {
  final String name;
  final String ip;
  final int port;
  final int nonce;
  final String? discoveryHash;
  final DateTime discoveredAt;

  DiscoveredDevice({
    required this.name,
    required this.ip,
    required this.port,
    required this.nonce,
    this.discoveryHash,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  @override
  bool operator ==(Object other) =>
      other is DiscoveredDevice && other.ip == ip && other.port == port;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode;

  @override
  String toString() => 'DiscoveredDevice($name@$ip:$port, nonce: $nonce)';

  Map<String, dynamic> toJson() => {
        'name': name,
        'ip': ip,
        'port': port,
        'nonce': nonce,
        'discoveryHash': discoveryHash,
        'discoveredAt': discoveredAt.toIso8601String(),
      };

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json) {
    return DiscoveredDevice(
      name: json['name'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int,
      nonce: json['nonce'] as int,
      discoveryHash: json['discoveryHash'] as String?,
      discoveredAt: json['discoveredAt'] != null
          ? DateTime.parse(json['discoveredAt'] as String)
          : null,
    );
  }
}

/// mDNS and UDP Broadcast service for discovering and advertising Tether instances.
class MdnsDiscovery {
  final Ref ref;

  // Ephemeral session identification
  final int discoverySessionNonce = Random.secure().nextInt(10000000);

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  
  RawDatagramSocket? _udpListenerSocket;
  RawDatagramSocket? _udpDiscoverySocket;
  Timer? _udpPingTimer;
  Timer? _staleCleanupTimer;
  int _consecutiveSilenceCycles = 0;

  String? _currentBroadcastName;
  int _currentBroadcastPort = TetherConstants.tcpPort;

  final _devicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();
  final Set<DiscoveredDevice> _discovered = {};

  Stream<List<DiscoveredDevice>> get devicesStream =>
      _devicesController.stream;
  List<DiscoveredDevice> get devices => _discovered.toList();

  MdnsDiscovery({required this.ref});

  String? _ownCertFingerprint;

  /// Compute our own discovery hash for broadcasting.
  Future<String?> _getOwnDiscoveryHash() async {
    if (_ownCertFingerprint == null) {
      final (certPath, _) = await TlsManager.ensureCertificate();
      _ownCertFingerprint = await TlsManager.fingerprint(certPath);
    }
    return CryptoUtils.computeDiscoveryHash(_ownCertFingerprint!);
  }

  void resetSilenceCounter() {
    _consecutiveSilenceCycles = 0;
  }

  void _updateDevicesInSettings() {
    try {
      final db = ref.read(databaseProvider);
      final jsonStr = jsonEncode(_discovered.map((d) => d.toJson()).toList());
      db.setSetting('discovered_devices', jsonStr);
    } catch (_) {
      // Container may be disposed during shutdown — safe to ignore.
    }
  }

  Future<RawDatagramSocket?> _bindUdpWithRetry(InternetAddress address, int port) async {
    int retries = 0;
    while (retries < 5) {
      try {
        final socket = await RawDatagramSocket.bind(address, port);
        socket.broadcastEnabled = true;
        return socket;
      } catch (e) {
        retries++;
        if (retries >= 5) rethrow;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return null;
  }

  /// Start broadcasting this device as a Tether service (mDNS + UDP).
  Future<void> startBroadcast({
    required String deviceName,
    int port = TetherConstants.tcpPort,
  }) async {
    await stopBroadcast();

    _currentBroadcastName = deviceName;
    _currentBroadcastPort = port;

    final discoveryHash = await _getOwnDiscoveryHash();

    // ─── mDNS Broadcast ───
    try {
      final service = BonsoirService(
        name: deviceName,
        type: TetherConstants.mdnsServiceType,
        port: port,
        attributes: {
          'nonce': discoverySessionNonce.toString(),
          if (discoveryHash != null) 'dh': discoveryHash,
        },
      );

      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.ready;
      await _broadcast!.start();
    } catch (_) {
      // If mDNS fails (e.g. unsupported platform features), proceed to UDP
    }

    // ─── UDP Broadcast Listener ───
    try {
      _udpListenerSocket = await _bindUdpWithRetry(InternetAddress.anyIPv4, 5281);
      _udpListenerSocket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpListenerSocket!.receive();
          if (datagram != null) {
            final text = String.fromCharCodes(datagram.data);
            if (text.startsWith("TETHER_DISCOVER:")) {
              _getOwnDiscoveryHash().then((hash) {
                final reply = "TETHER_REPLY:$deviceName:$port:$discoverySessionNonce:${hash ?? ''}"; 
                _udpListenerSocket!.send(reply.codeUnits, datagram.address, datagram.port);
              });
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
    resetSilenceCounter();

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
          final nonceStr = resolved.attributes['nonce'] ?? '0';
          final nonce = int.tryParse(nonceStr) ?? 0;
          final discoveryHash = resolved.attributes['dh'];
          final device = DiscoveredDevice(
            name: resolved.name,
            ip: resolved.host ?? '',
            port: resolved.port,
            nonce: nonce,
            discoveryHash: discoveryHash,
          );
          if (device.ip.isNotEmpty) {
            resetSilenceCounter();
            _discovered.add(device);
            _devicesController.add(_discovered.toList());
            _updateDevicesInSettings();
          }
        } else if (event.type ==
            BonsoirDiscoveryEventType.discoveryServiceLost) {
          _discovered.removeWhere(
              (d) => d.name == event.service?.name);
          _devicesController.add(_discovered.toList());
          _updateDevicesInSettings();
        }
      });

      await _discovery!.start();
    } catch (_) {}

    // ─── Stale Device Cleanup ───
    // Remove discovered devices that haven't re-announced in 30 seconds.
    _staleCleanupTimer?.cancel();
    _staleCleanupTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final cutoff = DateTime.now().subtract(const Duration(seconds: 30));
      final before = _discovered.length;
      _discovered.removeWhere((d) => d.discoveredAt.isBefore(cutoff));
      if (_discovered.length != before) {
        _devicesController.add(_discovered.toList());
        _updateDevicesInSettings();
      }
    });

    // ─── UDP Broadcast Discovery ───
    try {
      _udpDiscoverySocket = await _bindUdpWithRetry(InternetAddress.anyIPv4, 0);

      _udpPingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        final ping = "TETHER_DISCOVER:$discoverySessionNonce";
        
        try {
          _udpDiscoverySocket?.send(ping.codeUnits, InternetAddress("255.255.255.255"), 5281);
        } catch (e) {
          // Ignore exceptions on restricted hotspot interfaces. 
          // The unicast fallback below will handle discovery.
        }
        
        _consecutiveSilenceCycles++;
        if (_consecutiveSilenceCycles >= 3) { // 9 seconds of network silence
          _executeUnicastSubnetProbing();
        }
      });

      _udpDiscoverySocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpDiscoverySocket!.receive();
          if (datagram != null) {
            final text = String.fromCharCodes(datagram.data);
            if (text.startsWith("TETHER_REPLY:")) {
              final parts = text.split(":");
              if (parts.length >= 4) {
                final name = parts[1];
                final port = int.tryParse(parts[2]) ?? TetherConstants.tcpPort;
                final nonce = int.tryParse(parts[3]) ?? 0;
                final discoveryHash = parts.length >= 5 && parts[4].isNotEmpty
                    ? parts[4]
                    : null;
                final device = DiscoveredDevice(
                  name: name,
                  ip: datagram.address.address,
                  port: port,
                  nonce: nonce,
                  discoveryHash: discoveryHash,
                );
                resetSilenceCounter();
                _discovered.add(device);
                _devicesController.add(_discovered.toList());
                _updateDevicesInSettings();
              }
            }
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _executeUnicastSubnetProbing() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false, 
        type: InternetAddressType.IPv4
      );
      
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          final ip = addr.address;
          if (ip.startsWith("127.")) continue;
          
          final subnetBase = ip.substring(0, ip.lastIndexOf('.'));
          
          // Asynchronously sweep the subnet scope point-to-point (Unicast bypasses driver drops)
          for (int hostToken = 1; hostToken < 255; hostToken++) {
            final targetDest = "$subnetBase.$hostToken";
            if (targetDest == ip) continue; // Skip self
            
            _udpDiscoverySocket?.send(
              "TETHER_DISCOVER:$discoverySessionNonce".codeUnits,
              InternetAddress(targetDest),
              5281
            );
          }
        }
      }
    } catch (_) {}
  }

  /// Stop discovering.
  Future<void> stopDiscovery() async {
    await _discovery?.stop();
    _discovery = null;

    _udpPingTimer?.cancel();
    _udpPingTimer = null;

    _staleCleanupTimer?.cancel();
    _staleCleanupTimer = null;

    _udpDiscoverySocket?.close();
    _udpDiscoverySocket = null;

    _discovered.clear();
    _updateDevicesInSettings();
  }

  /// Force a fresh re-announcement. Call after a disconnect event to ensure
  /// peers see us with an updated nonce/hash immediately.
  Future<void> refreshBroadcast() async {
    if (_currentBroadcastName != null) {
      await startBroadcast(
        deviceName: _currentBroadcastName!,
        port: _currentBroadcastPort,
      );
    }
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
  final discovery = MdnsDiscovery(ref: ref);
  ref.onDispose(() => discovery.dispose());
  return discovery;
});

final discoveredDevicesProvider = StreamProvider<List<DiscoveredDevice>>((ref) {
  if (PlatformUtils.isAndroid) {
    final db = ref.watch(databaseProvider);
    return db.watchSetting('discovered_devices').map((val) {
      if (val == null || val.isEmpty) return [];
      try {
        final List<dynamic> list = jsonDecode(val) as List<dynamic>;
        return list
            .map((item) =>
                DiscoveredDevice.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    });
  }
  final discovery = ref.watch(mdnsDiscoveryProvider);
  return discovery.devicesStream;
});
