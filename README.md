# Tether — Linux ↔ Android Ecosystem Bridge

> A developer utility that connects your Linux desktop and Android phone over local Wi-Fi.
> No cloud. No accounts. No internet required.

```
┌─────────────┐    TLS/TCP    ┌─────────────┐
│  Linux PC   │◄────────────►│   Android   │
│  Flutter    │   port 5280   │   Flutter   │
│  Desktop    │               │    App      │
└─────────────┘               └─────────────┘
```

## Features

| Module | v1 | v2 (planned) |
|---|---|---|
| **Clipboard Sync** | ✅ Bi-directional, OTP detection, type badges | Smart clipboard rules |
| **File Transfer** | ✅ Chunked HTTP, drag-and-drop, progress bar | Folder sync |
| **Notification Mirror** | ✅ Forward Android notifications to Linux | Quick reply, mute rules |
| **Screen Mirror** | ✅ ADB + scrcpy integration | Native MediaProjection stream |
| **Device Discovery** | ✅ mDNS (zero-config) + manual IP | QR + NFC pairing |
| **Security** | ✅ TLS 1.3, PIN pairing, cert fingerprint | mTLS, key rotation |

## Architecture

```
lib/
├── core/
│   ├── database/           # drift SQLite (tables, queries, providers)
│   └── networking/         # TCP server/client, protocol, TLS, mDNS, HTTP file server
├── features/
│   ├── clipboard/          # Clipboard sync + history screen
│   ├── dashboard/          # System overview + stats
│   ├── files/              # File browser + transfer
│   ├── mirror/             # ADB/scrcpy screen mirror
│   ├── notifications/      # Android notification forwarding
│   ├── pairing/            # QR code + PIN pairing flow
│   ├── settings/           # All configuration
│   └── shell/              # Platform-adaptive app shells
│       ├── linux_shell.dart    # Three-column desktop layout
│       └── android_shell.dart  # Bottom-nav mobile layout
└── shared/
    ├── theme.dart          # Dark-only design system
    ├── constants.dart      # Ports, timeouts, limits
    ├── platform_utils.dart # Cross-platform abstraction
    └── widgets/            # Shared components
```

## Protocol

All communication uses **newline-delimited JSON** over **TLS 1.3 TCP sockets**.

```
Packet Types:
  HANDSHAKE         → Device identification + version exchange
  HEARTBEAT         → Keep-alive with battery/wifi telemetry
  CLIPBOARD_UPDATE  → Clipboard content sync
  NOTIFICATION      → Android notification forwarding
  NOTIFICATION_REPLY→ Reply to a notification
  FILE_LIST_REQUEST → Request remote directory listing
  FILE_LIST_RESPONSE→ Directory listing response
  FILE_CHUNK        → Base64-encoded file chunk (1MB)
  FILE_CHUNK_ACK    → Chunk receipt acknowledgment
  ADB_STATUS        → ADB connection status
  DISCONNECT        → Graceful disconnect
```

## Tech Stack

| Component | Technology |
|---|---|
| UI Framework | Flutter (Dart) |
| Android Native | Kotlin plugins |
| Linux Native | C++ plugins |
| Database | SQLite via drift |
| Networking | dart:io TCP sockets |
| Discovery | bonsoir (mDNS) |
| File Transfer | shelf HTTP server |
| Encryption | TLS 1.3 (openssl/pointycastle) |
| State Management | Riverpod |
| QR Codes | qr_flutter + mobile_scanner |

## Build

```bash
# Dependencies
flutter pub get
dart run build_runner build

# Linux Desktop
flutter build linux

# Android
flutter build apk

# Development
flutter run -d linux
flutter run -d <android-device-id>
```

## Configuration

| Setting | Default | Description |
|---|---|---|
| TCP Port | 5280 | Main protocol socket |
| HTTP Port | 5281 | File transfer server |
| mDNS Service | `_continuumlink._tcp` | Discovery broadcast |
| Clipboard History | 15 items | Ring buffer max |
| Heartbeat Interval | 5 seconds | Keep-alive frequency |
| Reconnect Attempts | 10 | Auto-reconnect limit |

## Pairing Flow

1. Linux device displays QR code containing `{ip, port, pin, cert_fingerprint}`
2. Android scans QR or enters 6-digit PIN manually
3. TLS handshake validates certificate fingerprint
4. Devices exchange HANDSHAKE packets with name/platform/version
5. Paired device saved to SQLite for auto-reconnect

## Cross-Platform Strategy

The architecture is designed for future **Windows** and **macOS** support:
- `PlatformUtils` abstracts all platform checks
- `platformWidget()` routes to platform-specific shells
- Pure Dart networking (no native dependencies for core protocol)
- `bonsoir` handles mDNS across all platforms
- TLS cert generation: openssl CLI (Linux/macOS) with pointycastle fallback (Android/Windows)

## v2 Roadmap

Features locked behind `V2LockedButton` widgets:
- **SMS Gateway** — Read/send SMS from Linux
- **Remote Shell** — Terminal access to Android
- **Audio Routing** — Forward Android audio to Linux
- **Hotspot Toggle** — Control Android hotspot from Linux
- **Native Screen Stream** — MediaProjection + H.264 (no scrcpy)
- **Touch Input Relay** — Control Android screen from Linux

## License

MIT
