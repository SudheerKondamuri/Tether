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
  final int? battery;
  final int? wifiStrength;

  HeartbeatPayload({this.battery, this.wifiStrength});

  Map<String, dynamic> toJson() => {
        'battery': battery,
        'wifi_strength': wifiStrength,
      };

  factory HeartbeatPayload.fromJson(Map<String, dynamic> json) {
    return HeartbeatPayload(
      battery: json['battery'] as int?,
      wifiStrength: json['wifi_strength'] as int?,
    );
  }
}

class ClipboardPayload {
  final String content;
  final String dataType;

  ClipboardPayload({required this.content, required this.dataType});

  Map<String, dynamic> toJson() => {
        'content': content,
        'data_type': dataType,
      };

  factory ClipboardPayload.fromJson(Map<String, dynamic> json) {
    return ClipboardPayload(
      content: json['content'] as String,
      dataType: json['data_type'] as String,
    );
  }
}

class NotificationPayload {
  final String app;
  final String package;
  final String title;
  final String text;
  final String? iconB64;
  final List<String> actions;

  NotificationPayload({
    required this.app,
    required this.package,
    required this.title,
    required this.text,
    this.iconB64,
    this.actions = const [],
  });

  Map<String, dynamic> toJson() => {
        'app': app,
        'package': package,
        'title': title,
        'text': text,
        'icon_b64': iconB64,
        'actions': actions,
      };

  factory NotificationPayload.fromJson(Map<String, dynamic> json) {
    return NotificationPayload(
      app: json['app'] as String,
      package: json['package'] as String,
      title: json['title'] as String,
      text: json['text'] as String,
      iconB64: json['icon_b64'] as String?,
      actions: (json['actions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

class NotificationReplyPayload {
  final String notificationId;
  final String replyText;

  NotificationReplyPayload({
    required this.notificationId,
    required this.replyText,
  });

  Map<String, dynamic> toJson() => {
        'notification_id': notificationId,
        'reply_text': replyText,
      };

  factory NotificationReplyPayload.fromJson(Map<String, dynamic> json) {
    return NotificationReplyPayload(
      notificationId: json['notification_id'] as String,
      replyText: json['reply_text'] as String,
    );
  }
}

class FileChunkPayload {
  final String transferId;
  final int chunkIndex;
  final int totalChunks;
  final String filename;
  final String dataB64;

  FileChunkPayload({
    required this.transferId,
    required this.chunkIndex,
    required this.totalChunks,
    required this.filename,
    required this.dataB64,
  });

  Map<String, dynamic> toJson() => {
        'transfer_id': transferId,
        'chunk_index': chunkIndex,
        'total_chunks': totalChunks,
        'filename': filename,
        'data_b64': dataB64,
      };

  factory FileChunkPayload.fromJson(Map<String, dynamic> json) {
    return FileChunkPayload(
      transferId: json['transfer_id'] as String,
      chunkIndex: json['chunk_index'] as int,
      totalChunks: json['total_chunks'] as int,
      filename: json['filename'] as String,
      dataB64: json['data_b64'] as String,
    );
  }
}

class FileEntry {
  final String name;
  final int size;
  final bool isDir;
  final int modified;

  FileEntry({
    required this.name,
    required this.size,
    required this.isDir,
    required this.modified,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'size': size,
        'is_dir': isDir,
        'modified': modified,
      };

  factory FileEntry.fromJson(Map<String, dynamic> json) {
    return FileEntry(
      name: json['name'] as String,
      size: json['size'] as int,
      isDir: json['is_dir'] as bool,
      modified: json['modified'] as int,
    );
  }
}
