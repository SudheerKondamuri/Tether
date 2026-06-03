import 'dart:convert';
import 'dart:typed_data';

/// All packet types in the Tether protocol.
enum PacketType {
  handshake,
  heartbeat,
  clipboardUpdate,
  notification,
  notificationReply,
  fileListRequest,
  fileListResponse,
  fileChunk,
  fileChunkAck,
  adbStatus,
  disconnect,
}

extension PacketTypeExt on PacketType {
  String get wire {
    switch (this) {
      case PacketType.handshake:
        return 'HANDSHAKE';
      case PacketType.heartbeat:
        return 'HEARTBEAT';
      case PacketType.clipboardUpdate:
        return 'CLIPBOARD_UPDATE';
      case PacketType.notification:
        return 'NOTIFICATION';
      case PacketType.notificationReply:
        return 'NOTIFICATION_REPLY';
      case PacketType.fileListRequest:
        return 'FILE_LIST_REQUEST';
      case PacketType.fileListResponse:
        return 'FILE_LIST_RESPONSE';
      case PacketType.fileChunk:
        return 'FILE_CHUNK';
      case PacketType.fileChunkAck:
        return 'FILE_CHUNK_ACK';
      case PacketType.adbStatus:
        return 'ADB_STATUS';
      case PacketType.disconnect:
        return 'DISCONNECT';
    }
  }

  static PacketType fromWire(String wire) {
    for (final type in PacketType.values) {
      if (type.wire == wire) return type;
    }
    throw FormatException('Unknown packet type: $wire');
  }
}

/// A single protocol packet.
class Packet {
  final PacketType type;
  final String deviceId;
  final int timestamp;
  final Map<String, dynamic> payload;

  Packet({
    required this.type,
    required this.deviceId,
    int? timestamp,
    this.payload = const {},
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  factory Packet.fromJson(Map<String, dynamic> json) {
    return Packet(
      type: PacketTypeExt.fromWire(json['type'] as String),
      deviceId: json['device_id'] as String,
      timestamp: json['timestamp'] as int,
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.wire,
        'device_id': deviceId,
        'timestamp': timestamp,
        'payload': payload,
      };

  /// Encode to newline-delimited JSON bytes.
  Uint8List encode() {
    return Uint8List.fromList(utf8.encode('${jsonEncode(toJson())}\n'));
  }

  @override
  String toString() => 'Packet(${type.wire}, deviceId=$deviceId)';
}

/// Newline-delimited JSON codec for the TCP stream.
/// Buffers incoming byte data and emits complete [Packet] objects.
class PacketCodec {
  final StringBuffer _buffer = StringBuffer();

  /// Feed raw bytes from the socket into the codec.
  /// Returns a list of fully parsed packets.
  List<Packet> decode(List<int> data) {
    _buffer.write(utf8.decode(data, allowMalformed: true));
    final packets = <Packet>[];

    while (true) {
      final content = _buffer.toString();
      final newlineIndex = content.indexOf('\n');
      if (newlineIndex == -1) break;

      final line = content.substring(0, newlineIndex).trim();
      _buffer.clear();
      _buffer.write(content.substring(newlineIndex + 1));

      if (line.isNotEmpty) {
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          packets.add(Packet.fromJson(json));
        } catch (e) {
          // Malformed packet — skip it
          // In production, log this
        }
      }
    }

    return packets;
  }

  /// Reset the internal buffer.
  void reset() {
    _buffer.clear();
  }
}

// ─── Payload Helper Constructors ───

class HandshakePayload {
  final String name;
  final String platform;
  final String version;

  HandshakePayload({
    required this.name,
    required this.platform,
    required this.version,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'platform': platform,
        'version': version,
      };

  factory HandshakePayload.fromJson(Map<String, dynamic> json) {
    return HandshakePayload(
      name: json['name'] as String,
      platform: json['platform'] as String,
      version: json['version'] as String,
    );
  }
}

class HeartbeatPayload {

}
