# MeshLink v3.2.0

**AES-256 Encrypted Peer-to-Peer Bluetooth Mesh Messenger**

No servers. No internet. No third parties. Just Bluetooth.

---

## What's New in v3.2

### Account System
- **Create accounts** with display name, 4+ digit PIN (SHA-256 hashed), and emoji avatar
- **Login/logout** — switch between multiple accounts on the same device
- **Guest mode** — skip login for quick access
- **Long-press to delete** accounts from the selection screen

### Chat Sessions
- **Create named sessions** — organize conversations by topic or group
- **Switch between sessions** — each preserves its own messages and encryption key
- **Pin important chats** to the top of the list
- **Archive old chats** (recoverable) or **delete permanently**
- **Session metadata** — message count, last activity, peer names, who created it

### Bug Fixes
| # | Severity | Fix |
|---|----------|-----|
| 1 | Critical | Scroll-to-bottom button was outside `ScrollViewReader` — couldn't access scroll proxy. Moved inside `ZStack` within `ScrollViewReader`. |
| 2 | Critical | `startAdvertising()` silently failed if Bluetooth wasn't ready at launch. Added `pendingAdvertisingName` with retry in `peripheralManagerDidUpdateState`. |
| 3 | Critical | `leaveMesh()` called `messages.removeAll()` but never persisted — old messages reappeared on relaunch. Now saves before clearing. |
| 4 | Performance | `DateFormatter()` allocated on every `.timeString` / `.dateSectionLabel` / log render. Replaced with 3 static cached formatters. |
| 5 | Bug | `encryptionEnabled` toggle was never persisted — always reset to `true` on relaunch. Now saved/restored via UserDefaults. |
| 6 | Performance | `CIContext()` created on every QR code generation. Now cached as instance property. |

---

## Features

- **AES-256-GCM** end-to-end encryption with shared key
- **BLE Mesh** relay — messages hop through intermediate nodes (TTL-based)
- **NFC Key Sharing** — tap phones to exchange encryption keys
- **QR Code Exchange** — scan/generate QR codes for key sharing
- **Image Sharing** — send photos over encrypted Bluetooth
- **Notifications** — background alerts for new messages
- **Auto-Reconnect** — reconnects to known MeshLink peers
- **Account Login** — PIN-protected accounts with emoji avatars
- **Chat Sessions** — multiple sessions per account with archive/pin
- **Peer Nicknames** — long-press peers to set custom names
- **Signal Bars** — visual RSSI strength indicators
- **Device Filter** — show all BLE devices or MeshLink-only
- **Debug Logs** — real-time console with color-coded levels

## Architecture

```
MeshLinkApp.swift              — App entry + Theme
├── LoginView.swift             — Account creation/login       (NEW)
├── SetupView.swift             — Node name + encryption key
├── MainView.swift              — Header, tabs, settings
│   ├── ChatView.swift          — Messages, bubbles, input
│   ├── PeersView.swift         — Device list, connect/disconnect
│   ├── LogsView.swift          — Debug log console
│   └── SessionsView.swift      — Chat session management     (NEW)
├── QRScannerView.swift         — Camera QR code scanner
├── Models.swift                — Message, Peer, Session, Account
├── AccountService.swift        — Account + session persistence (NEW)
├── BLEService.swift            — CoreBluetooth central + peripheral
├── MeshViewModel.swift         — App state + business logic
├── CryptoService.swift         — AES-256-GCM encryption
├── NFCService.swift            — NFC NDEF read/write
├── HapticService.swift         — Haptic feedback
├── SoundService.swift          — Audio feedback
└── NotificationService.swift   — Push notifications
```

## Build

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
open MeshLink.xcodeproj
```

Build target: iOS 16.0+, Swift 5.9

## App Flow

```
Login → Setup → Main
  │       │       │
  │       │       ├── Chat (with session label)
  │       │       ├── Peers
  │       │       ├── Logs
  │       │       └── Sessions Sheet (create/switch/archive/delete)
  │       │
  │       └── Node name + encryption key + NFC/QR
  │
  └── Create account / Select account + PIN / Guest
```
