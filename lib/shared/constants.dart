/// App-wide constants — ports, timeouts, channel names, limits.
class TetherConstants {
  TetherConstants._();

  // ─── App Info ───
  static const String appName = 'Tether';
  static const String appVersion = '1.0.0';

  // ─── Networking ───
  static const int tcpPort = 5280;
  static const int httpFilePort = 5281;
  static const String mdnsServiceType = '_continuumlink._tcp';

  // ─── Heartbeat ───
  static const Duration heartbeatInterval = Duration(seconds: 5);
  static const Duration heartbeatTimeout = Duration(seconds: 15);
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const int maxReconnectAttempts = 10;

  // ─── Clipboard ───
  static const Duration clipboardPollInterval = Duration(milliseconds: 800);
  static const int clipboardMaxHistory = 15;
  static const Duration otpSnackbarDuration = Duration(seconds: 30);

  // ─── File Transfer ───
  static const int fileChunkSize = 1024 * 1024; // 1 MB
  static const int fileChunkThreshold = 5 * 1024 * 1024; // 5 MB

}
