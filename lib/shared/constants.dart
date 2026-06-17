/// App-wide constants — ports, timeouts, channel names, limits.
class TetherConstants {
  TetherConstants._();

  // ─── App Info ───
  static const String appName = 'Tether';
  static const String appVersion = '1.0.0';

  // ─── Networking ───
  static const int tcpPort = 5280;
  static const int httpFilePort = 5282;
  static const String mdnsServiceType = '_continuumlink._tcp';

  // ─── Heartbeat ───
  static const Duration heartbeatInterval = Duration(seconds: 5);
  static const Duration heartbeatTimeout = Duration(seconds: 15);
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const int maxReconnectAttempts = 10;

  // ─── Clipboard ───
  static const Duration clipboardPollInterval = Duration(milliseconds: 800);
  static const int clipboardMaxHistory = 10;
  static const Duration otpSnackbarDuration = Duration(seconds: 30);

  // ─── File Transfer ───
  static const int fileChunkSize = 1024 * 1024; // 1 MB
  static const int fileChunkThreshold = 5 * 1024 * 1024; // 5 MB
  static const int maxFileTransferRetries = 3;

  // ─── Method Channels ───
  static const String clipboardChannel = 'com.tether/clipboard';
  static const String notificationChannel = 'com.tether/notifications';
  static const String adbChannel = 'com.tether/adb';
  static const String foregroundServiceChannel = 'com.tether/foreground';

  // ─── Pairing ───
  static const double qrCodeSize = 240.0;
  static const int pinLength = 6;
  static const Duration pairingTimeout = Duration(minutes: 5);

  // ─── QR Data Keys ───
  static const String qrKeyIp = 'ip';
  static const String qrKeyPort = 'port';
  static const String qrKeyPin = 'pin';
  static const String qrKeyFingerprint = 'fingerprint';

  // ─── OTP Detection ───
  static final RegExp otpRegex = RegExp(r'\b\d{4,8}\b');
  static final RegExp urlRegex = RegExp(r'^https?://');
  static final RegExp filePathRegex = RegExp(r'^(/|file://)');

  // ─── Database ───
  static const String databaseName = 'tether.db';
}
