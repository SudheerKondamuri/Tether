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
