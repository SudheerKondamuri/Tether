import 'dart:async';
import 'dart:io';
import 'package:tether/core/networking/packet_protocol.dart';
import 'package:tether/shared/constants.dart';

/// Outgoing TLS TCP client that connects to a peer.
class TcpClient {
  SecureSocket? _socket;
  final PacketCodec _codec = PacketCodec();
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  String? _host;
  int? _port;
  String _deviceId = '';
  String? _trustedCertPem;

  bool get isConnected => _socket != null;
  String? get host => _host;
  int? get port => _port;

  /// Callback when a packet is received.
  void Function(Packet packet)? onPacket;

  /// Callback when connection state changes.
  void Function(bool connected)? onConnectionChanged;

  /// Connect to a peer at the given host:port.
  Future<bool> connect({
    required String host,
    required int port,
    required String deviceId,
    String? trustedCertPem,
    bool Function(X509Certificate cert)? onBadCertificate,
  }) async {
    _host = host;
    _port = port;
    _deviceId = deviceId;
    _trustedCertPem = trustedCertPem;

    try {
      _socket = await SecureSocket.connect(
        host,
        port,
        onBadCertificate: onBadCertificate ??
            (cert) {
              // During pairing, we accept any cert and verify fingerprint later
              return true;
            },
        timeout: const Duration(seconds: 10),
      );

      _reconnectAttempts = 0;
      _codec.reset();

      _socket!.listen(
        (data) {
          final packets = _codec.decode(data);
          for (final packet in packets) {
            onPacket?.call(packet);
          }
        },
        onError: (e) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
      );

      _startHeartbeat();
      onConnectionChanged?.call(true);
      return true;
    } catch (e) {

}}}
