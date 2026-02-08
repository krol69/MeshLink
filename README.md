# MeshLink — Encrypted Bluetooth Mesh Messaging for iOS

AES-256 encrypted peer-to-peer messaging over Bluetooth. No internet. No servers. No third parties.

[![Build MeshLink IPA](../../actions/workflows/build.yml/badge.svg)](../../actions/workflows/build.yml)

---

## Get the App on Your iPhone (Step-by-Step from Your Phone)

### Step 1: Get Your IPA

The GitHub Actions workflow builds the .ipa automatically every time you push code.

1. Tap the **Actions** tab at the top of this repo
2. Tap the latest **"Build MeshLink IPA"** workflow run (green checkmark = success)
3. Scroll down to **Artifacts**
4. Tap **MeshLink-IPA** to download the zip
5. Open the zip — inside is `MeshLink.ipa`

### Step 2: Upload to Signulous

1. Open **Signulous** on your iPhone
2. Go to **My Apps** → **Upload IPA**
3. Select the `MeshLink.ipa` file from your Downloads
4. Signulous re-signs it with your certificate
5. Tap **Install**

### Step 3: First Launch

1. Open MeshLink on your home screen
2. **Allow Bluetooth** when prompted (required!)
3. Enter your node name and encryption key
4. Tap **Join Mesh**
5. Go to Peers → Scan for Devices
6. Connect to nearby MeshLink devices

---

## Features

- **AES-256-GCM** end-to-end encryption (CryptoKit + PBKDF2)
- **Core Bluetooth** BLE scanning, connecting, and messaging
- **Multi-peer** — connect to several devices at once
- **Typing indicators** — see when peers are typing
- **Delivery confirmations** — sent ✓ and delivered ✓✓
- **Message persistence** — survives app restarts
- **Audio notifications** — distinct sounds for messages, connect, disconnect
- **Signal strength** — RSSI bars for each peer
- **Background Bluetooth** — receive messages while app is minimized
- **Dark UI** — MeshLink design system

## Connecting to the Python Companion

Someone on a laptop can run:
```bash
python meshlink_server.py --mode bt-server --name Laptop --key "same-key"
```
Your iPhone will discover "Laptop" when scanning. Same key = messages decrypt on both sides.

## Project Structure

```
MeshLink/
├── .github/workflows/build.yml  ← Auto-builds your IPA
├── project.yml                  ← XcodeGen config
└── MeshLink/
    ├── MeshLinkApp.swift        ← App entry + theme
    ├── Info.plist               ← Bluetooth permissions
    ├── Models/Models.swift      ← Data models
    ├── Services/
    │   ├── BLEService.swift     ← Core Bluetooth
    │   ├── CryptoService.swift  ← AES-256-GCM
    │   ├── SoundService.swift   ← Audio
    │   └── MeshViewModel.swift  ← Main logic
    └── Views/
        ├── SetupView.swift
        ├── MainView.swift
        ├── ChatView.swift
        ├── PeersView.swift
        └── LogsView.swift
```
