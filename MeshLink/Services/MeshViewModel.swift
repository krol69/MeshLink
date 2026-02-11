import Foundation
import SwiftUI
import Combine
import CoreImage.CIFilterBuiltins

// MARK: - Main ViewModel v3.2
final class MeshViewModel: ObservableObject {
    @Published var isSetup = false
    @Published var username = ""
    @Published var encryptionKey = ""
    @Published var showKey = false
    @Published var inputText = ""
    @Published var messages: [ChatMessage] = []
    @Published var logs: [LogEntry] = []
    @Published var activeTab: AppTab = .chat {
        didSet { showAbout = false; showSettings = false; showKeyShare = false }
    }
    @Published var showAbout = false
    @Published var showSettings = false
    @Published var showKeyShare = false
    @Published var showQRScanner = false
    @Published var showSessionsSheet = false
    @Published var encryptionEnabled = true
    @Published var soundEnabled = true
    @Published var typingPeers: Set<String> = []
    @Published var unreadCount = 0
    @Published var demoLoaded = false
    @Published var keyCopied = false
    @Published var isScanning: Bool = false
    @Published var bluetoothReady = false
    @Published var peerNicknames: [String: String] = [:]
    @Published var editingNicknamePeerId: String? = nil
    @Published var nicknameInput = ""
    
    enum AppTab { case chat, peers, logs }
    
    let ble = BLEService.shared
    let crypto = CryptoService.shared
    let sound = SoundService.shared
    let haptic = HapticService.shared
    let notifications = NotificationService.shared
    let nfc = NFCService.shared
    let accounts = AccountService.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var typingTimers: [String: Timer] = [:]
    private var lastTypingSent: Date?
    
    // FIX #6: Cache CIContext
    private let qrContext = CIContext()
    
    var isEncryptionActive: Bool {
        encryptionEnabled && !encryptionKey.isEmpty && crypto.isReady
    }
    
    init() {
        loadPersistedState()
        setupBLE()
        setupNFC()
        ble.$isScanning.assign(to: &$isScanning)
        ble.$bluetoothState.map { $0 == .poweredOn }.assign(to: &$bluetoothReady)
        notifications.requestPermission()
    }
    
    // MARK: - Setup
    func joinMesh() {
        let name = username.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        username = name
        if !encryptionKey.isEmpty {
            crypto.deriveKey(from: encryptionKey)
            addLog("AES-256-GCM encryption active", .success)
        } else {
            addLog("No encryption key — messages sent in plaintext", .warning)
            encryptionEnabled = false
        }
        isSetup = true
        ble.startAdvertising(name: name)
        addLog("Joined mesh as '\(name)'", .success)
        haptic.connect()
        savePersistedState()
        
        // Session: create or resume
        if accounts.activeSessionId == nil && !encryptionKey.isEmpty {
            let _ = accounts.createSession(title: "Chat", encryptionKey: encryptionKey)
        }
        if let sid = accounts.activeSessionId {
            let sessionMsgs = accounts.loadSessionMessages(sid)
            if !sessionMsgs.isEmpty { messages = sessionMsgs }
        }
    }
    
    func leaveMesh() {
        // FIX #3: Save messages BEFORE clearing
        saveMessages()
        ble.disconnectAll()
        ble.stopAdvertising()
        isSetup = false
        messages.removeAll()
        haptic.disconnect()
        addLog("Left mesh", .warning)
        // FIX #3: Persist the cleared state
        UserDefaults.standard.removeObject(forKey: "savedMessages")
    }
    
    // MARK: - Session Management
    func createNewSession(title: String) {
        saveMessages()
        let session = accounts.createSession(title: title, encryptionKey: encryptionKey)
        messages = []
        addLog("New session: \(session.title)", .success)
        haptic.tap()
    }
    
    func switchToSession(_ session: ChatSession) {
        saveMessages()
        accounts.switchSession(session.id)
        messages = accounts.loadSessionMessages(session.id)
        if session.encryptionKey != encryptionKey && !session.encryptionKey.isEmpty {
            encryptionKey = session.encryptionKey
            crypto.deriveKey(from: encryptionKey)
            encryptionEnabled = true
        }
        addLog("Switched to: \(session.title)", .info)
        haptic.tap()
    }
    
    func archiveCurrentSession() {
        guard let sid = accounts.activeSessionId else { return }
        saveMessages()
        accounts.archiveSession(sid)
        if let next = accounts.activeSessions.first { switchToSession(next) }
        else { messages = [] }
        haptic.tap()
    }
    
    // MARK: - BLE Callbacks
    private func setupBLE() {
        ble.onLog = { [weak self] text, level in self?.addLog(text, level) }
        ble.onMessageReceived = { [weak self] peer, raw in self?.handleIncoming(from: peer, raw: raw) }
        ble.onPeerConnected = { [weak self] name in
            self?.sound.play(.connect); self?.haptic.connect()
            self?.notifications.sendConnectionNotification(peerName: name, connected: true)
            self?.addLog("\(name) connected ✓", .success)
        }
        ble.onPeerDisconnected = { [weak self] name in
            self?.sound.play(.disconnect); self?.haptic.disconnect()
            self?.notifications.sendConnectionNotification(peerName: name, connected: false)
            self?.addLog("\(name) disconnected", .warning)
            self?.typingPeers.remove(name)
        }
    }
    
    // MARK: - NFC Callbacks
    private func setupNFC() {
        nfc.onKeyReceived = { [weak self] key in
            guard let self = self else { return }
            self.encryptionKey = key; self.crypto.deriveKey(from: key)
            self.encryptionEnabled = true; self.haptic.connect()
            self.addLog("Encryption key received via NFC", .success)
            self.savePersistedState()
        }
        nfc.onLog = { [weak self] text, level in self?.addLog(text, level) }
    }
    
    func handleScannedKey(_ key: String) {
        encryptionKey = key; crypto.deriveKey(from: key)
        encryptionEnabled = true; haptic.connect()
        addLog("Encryption key received via QR scan", .success)
        savePersistedState()
    }
    
    // MARK: - Message Handling
    private func handleIncoming(from peerName: String, raw: String) {
        guard let data = raw.data(using: .utf8),
              let wire = try? JSONDecoder().decode(WireMessage.self, from: data) else { return }
        guard ble.shouldProcess(messageId: wire.id) else { return }
        
        // Mesh relay
        if let ttl = wire.ttl, ttl > 0, wire.type == "msg" || wire.type == "img" {
            let relay = WireMessage(type: wire.type, sender: wire.sender, text: wire.text,
                                    id: wire.id, ttl: ttl - 1, originId: wire.originId,
                                    imgData: wire.imgData, imgThumb: wire.imgThumb)
            if let d = try? JSONEncoder().encode(relay), let s = String(data: d, encoding: .utf8),
               let rd = s.data(using: .utf8) {
                let senderPeerId = ble.peers.first(where: { $0.name == peerName })?.id
                ble.broadcast(rd, excludePeerId: senderPeerId)
                addLog("Relayed from \(wire.originId ?? wire.sender) (TTL: \(ttl - 1))", .data)
            }
        }
        
        switch wire.type {
        case "msg":
            let text = isEncryptionActive && wire.text != nil ? crypto.decrypt(wire.text!) : (wire.text ?? "")
            let sender = wire.originId ?? wire.sender
            let msg = ChatMessage(sender: sender, text: text, encrypted: isEncryptionActive, method: "BLE", sessionId: accounts.activeSessionId)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.messages.append(msg); self.trimMessages()
                self.sound.play(.message); self.haptic.messageReceived()
                self.typingPeers.remove(sender)
                if self.activeTab != .chat { self.unreadCount += 1 }
                self.notifications.sendMessageNotification(from: sender, text: text)
                self.saveMessages(); self.sendAck(for: wire.id)
            }
            
        case "img":
            let sender = wire.originId ?? wire.sender
            var imageData: Data? = nil
            if let imgStr = wire.imgData {
                let decrypted = isEncryptionActive ? crypto.decrypt(imgStr) : imgStr
                imageData = Data(base64Encoded: decrypted)
            }
            let text = wire.text ?? (imageData != nil ? "📷 Image" : "")
            let msg = ChatMessage(sender: sender, text: text, encrypted: isEncryptionActive, method: "BLE", imageData: imageData, sessionId: accounts.activeSessionId)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.messages.append(msg); self.trimMessages()
                self.sound.play(.message); self.haptic.messageReceived()
                if self.activeTab != .chat { self.unreadCount += 1 }
                self.notifications.sendMessageNotification(from: sender, text: "Sent a photo")
                self.saveMessages(); self.sendAck(for: wire.id)
            }
            
        case "typing":
            let sender = wire.originId ?? wire.sender
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.typingPeers.insert(sender)
                self.typingTimers[sender]?.invalidate()
                self.typingTimers[sender] = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                    self?.typingPeers.remove(sender)
                }
            }
            
        case "ack":
            if let ackId = wire.ackId {
                DispatchQueue.main.async { [weak self] in
                    if let i = self?.messages.firstIndex(where: { $0.id == ackId }) {
                        self?.messages[i].delivered = true
                    }
                }
            }
            
        default: break
        }
    }
    
    // MARK: - Send Message
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let encrypted = isEncryptionActive ? crypto.encrypt(text) : text
        let wire = WireMessage(type: "msg", sender: username, text: encrypted)
        _ = ble.shouldProcess(messageId: wire.id)
        if let data = try? JSONEncoder().encode(wire) { ble.broadcast(data) }
        let msg = ChatMessage(id: wire.id, sender: username, text: text, timestamp: Date(),
                              isOwn: true, encrypted: isEncryptionActive, method: "BLE", delivered: false,
                              sessionId: accounts.activeSessionId)
        messages.append(msg); trimMessages()
        inputText = ""; sound.play(.send); haptic.messageSent(); saveMessages()
    }
    
    // MARK: - Send Image
    func sendImage(_ image: UIImage) {
        guard let jpegData = compressImage(image, maxBytes: 50_000) else {
            addLog("Image too large to send via BLE", .error); haptic.error(); return
        }
        let b64 = jpegData.base64EncodedString()
        let encB64 = isEncryptionActive ? crypto.encrypt(b64) : b64
        let thumbB64 = compressImage(image, maxBytes: 2_000)?.base64EncodedString()
        let wire = WireMessage(type: "img", sender: username, text: "📷 Image", imgData: encB64, imgThumb: thumbB64)
        _ = ble.shouldProcess(messageId: wire.id)
        if let data = try? JSONEncoder().encode(wire) { ble.broadcast(data) }
        let msg = ChatMessage(sender: username, text: "📷 Image", isOwn: true, encrypted: isEncryptionActive,
                              method: "BLE", imageData: jpegData, sessionId: accounts.activeSessionId)
        messages.append(msg); trimMessages()
        sound.play(.send); haptic.messageSent(); saveMessages()
        addLog("Image sent (\(jpegData.count / 1024)KB)", .data)
    }
    
    private func compressImage(_ image: UIImage, maxBytes: Int) -> Data? {
        var quality: CGFloat = 0.8
        let maxDim: CGFloat = 300
        let ratio = min(maxDim / image.size.width, maxDim / image.size.height, 1.0)
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let img = resized else { return nil }
        while quality > 0.1 {
            if let data = img.jpegData(compressionQuality: quality), data.count <= maxBytes { return data }
            quality -= 0.1
        }
        return img.jpegData(compressionQuality: 0.1)
    }
    
    private func sendAck(for messageId: String) {
        let wire = WireMessage(type: "ack", sender: username, ackId: messageId)
        if let data = try? JSONEncoder().encode(wire) { ble.broadcast(data) }
    }
    
    // MARK: - Typing
    func onInputChanged() {
        guard ble.connectedCount > 0 else { return }
        let now = Date()
        if let last = lastTypingSent, now.timeIntervalSince(last) < 2.0 { return }
        lastTypingSent = now
        let wire = WireMessage(type: "typing", sender: username)
        if let data = try? JSONEncoder().encode(wire) { ble.broadcast(data) }
    }
    
    // MARK: - Scanning
    func startScan() { haptic.tap(); ble.startScan() }
    func stopScan() { ble.stopScan() }
    func connectPeer(_ peer: BLEPeer) { haptic.button(); ble.connect(peerId: peer.id) }
    func disconnectPeer(_ peer: BLEPeer) { haptic.button(); ble.disconnect(peerId: peer.id) }
    
    // MARK: - QR Code Generation (FIX #6: cached CIContext)
    func generateQRCode(for key: String) -> UIImage? {
        guard !key.isEmpty else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue("meshlink://key/\(key)".data(using: .utf8), forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scale = 250.0 / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = qrContext.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - NFC
    func readKeyFromNFC() { haptic.tap(); nfc.readKey() }
    func writeKeyToNFC() { haptic.tap(); nfc.writeKey(encryptionKey) }
    
    // MARK: - Peer Nicknames
    func setNickname(_ name: String, for peerId: String) {
        peerNicknames[peerId] = name.isEmpty ? nil : name
        UserDefaults.standard.set(peerNicknames, forKey: "peerNicknames")
    }
    func displayName(for peer: BLEPeer) -> String { peerNicknames[peer.id] ?? peer.name }
    func startNicknameEdit(for peer: BLEPeer) {
        editingNicknamePeerId = peer.id
        nicknameInput = peerNicknames[peer.id] ?? ""
    }
    func saveNickname() {
        guard let peerId = editingNicknamePeerId else { return }
        setNickname(nicknameInput.trimmingCharacters(in: .whitespaces), for: peerId)
        editingNicknamePeerId = nil; nicknameInput = ""; haptic.tap()
    }
    func cancelNicknameEdit() { editingNicknamePeerId = nil; nicknameInput = "" }
    
    // MARK: - Utilities
    func clearChat() { messages.removeAll(); haptic.tap(); saveMessages() }
    
    func loadDemo() {
        messages = [
            ChatMessage(sender: "Alice", text: "Hey! MeshLink is working 🔒", encrypted: true, method: "BLE", delivered: true),
            ChatMessage(sender: "Bob", text: "No internet needed — pure Bluetooth mesh!", encrypted: true, method: "BLE", delivered: true),
            ChatMessage(sender: "Alice", text: "And everything is AES-256-GCM encrypted end-to-end", encrypted: true, method: "BLE", delivered: true),
        ]
        demoLoaded = true
    }
    
    func copyKey() {
        UIPasteboard.general.string = encryptionKey
        keyCopied = true; haptic.tap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.keyCopied = false }
    }
    
    func addLog(_ text: String, _ level: LogEntry.LogLevel) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.logs.append(LogEntry(timestamp: Date(), text: text, level: level))
            if self.logs.count > 200 { self.logs.removeFirst(self.logs.count - 200) }
        }
    }
    
    private func trimMessages() {
        if messages.count > 300 { messages.removeFirst(messages.count - 300) }
    }
    
    // MARK: - Persistence
    func saveMessages() {
        if let sid = accounts.activeSessionId {
            accounts.saveSessionMessages(messages, sessionId: sid)
        }
        let toSave = Array(messages.suffix(200))
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: "savedMessages")
        }
    }
    
    private func savePersistedState() {
        UserDefaults.standard.set(username, forKey: "username")
        UserDefaults.standard.set(encryptionKey, forKey: "encryptionKey")
        // FIX #5: persist encryption toggle
        UserDefaults.standard.set(encryptionEnabled, forKey: "encryptionEnabled")
    }
    
    private func loadPersistedState() {
        if let saved = UserDefaults.standard.data(forKey: "savedMessages"),
           let msgs = try? JSONDecoder().decode([ChatMessage].self, from: saved) { messages = msgs }
        if let name = UserDefaults.standard.string(forKey: "username"), !name.isEmpty { username = name }
        if let key = UserDefaults.standard.string(forKey: "encryptionKey") { encryptionKey = key }
        if let nicks = UserDefaults.standard.dictionary(forKey: "peerNicknames") as? [String: String] { peerNicknames = nicks }
        soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        // FIX #5: restore encryption toggle
        encryptionEnabled = UserDefaults.standard.object(forKey: "encryptionEnabled") as? Bool ?? true
        
        // Load from active session if available
        if let sid = accounts.activeSessionId {
            let sessionMsgs = accounts.loadSessionMessages(sid)
            if !sessionMsgs.isEmpty { messages = sessionMsgs }
        }
    }
}
