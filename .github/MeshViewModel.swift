import Foundation
import Combine
import SwiftUI

// MARK: - Main ViewModel
@MainActor
final class MeshViewModel: ObservableObject {
    // Setup
    @Published var username = ""
    @Published var encryptionKey = "meshkey"
    @Published var isSetup = false
    @Published var showKey = false
    
    // Chat
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var typingPeers: Set<String> = []
    
    // Peers
    @Published var peers: [BLEPeer] = []
    @Published var isScanning = false
    
    // UI State
    @Published var activeTab: AppTab = .chat
    @Published var logs: [LogEntry] = []
    @Published var showSettings = false
    @Published var showAbout = false
    @Published var encryptionEnabled = true
    @Published var soundEnabled = true
    @Published var unreadCount = 0
    @Published var keyCopied = false
    @Published var demoLoaded = false
    @Published var bluetoothReady = false
    
    // Services
    let ble = BLEService.shared
    let crypto = CryptoService.shared
    let sound = SoundService.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var typingTimers: [String: Timer] = [:]
    private var lastTypingSent: Date = .distantPast
    
    enum AppTab: String, CaseIterable {
        case chat, peers, logs
    }
    
    init() {
        loadPersistedData()
        setupBLECallbacks()
        setupBindings()
    }
    
    // MARK: - Setup
    func joinMesh() {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        crypto.deriveKey(from: encryptionKey)
        isSetup = true
        
        addLog("Node \"\(username)\" joined the mesh", .success)
        addLog("Encryption: AES-256-GCM (\(encryptionEnabled ? "enabled" : "disabled"))", .info)
        addLog("Bluetooth: \(bluetoothReady ? "ready" : "not available")", bluetoothReady ? .success : .warning)
        
        // Start advertising so other devices can find us
        ble.startAdvertising(name: username)
    }
    
    // MARK: - Scanning
    func startScan() {
        ble.startScan()
    }
    
    func stopScan() {
        ble.stopScan()
    }
    
    // MARK: - Connect / Disconnect
    func connectPeer(_ peer: BLEPeer) {
        ble.connect(peerId: peer.id)
    }
    
    func disconnectPeer(_ peer: BLEPeer) {
        ble.disconnect(peerId: peer.id)
    }
    
    // MARK: - Send Message
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let wire = WireMessage(type: "msg", sender: username, text: text)
        guard let jsonData = try? JSONEncoder().encode(wire),
              let jsonStr = String(data: jsonData, encoding: .utf8) else { return }
        
        let hasConn = ble.connectedCount > 0
        
        // Encrypt
        let encoded: String
        if encryptionEnabled {
            encoded = crypto.encrypt(jsonStr)
        } else {
            encoded = jsonStr
        }
        
        // Add to local chat
        let msg = ChatMessage(sender: username, text: text, isOwn: true, encrypted: encryptionEnabled, method: hasConn ? "BLE" : "LOCAL")
        messages.append(msg)
        persistMessages()
        
        // Broadcast
        if hasConn, let data = encoded.data(using: .utf8) {
            ble.broadcast(data)
        }
        
        inputText = ""
    }
    
    // MARK: - Typing Indicator
    func onInputChanged() {
        guard ble.connectedCount > 0 else { return }
        let now = Date()
        guard now.timeIntervalSince(lastTypingSent) > 2 else { return }
        lastTypingSent = now
        
        let wire = WireMessage(type: "typing", sender: username)
        if let data = try? JSONEncoder().encode(wire) {
            let str = encryptionEnabled ? crypto.encrypt(String(data: data, encoding: .utf8) ?? "") : String(data: data, encoding: .utf8) ?? ""
            if let sendData = str.data(using: .utf8) {
                ble.broadcast(sendData)
            }
        }
    }
    
    // MARK: - Process Incoming
    private func processIncoming(peerName: String, rawData: String) {
        var text = rawData
        if encryptionEnabled {
            text = crypto.decrypt(rawData)
        }
        
        // Try parsing as wire message
        if let data = text.data(using: .utf8),
           let wire = try? JSONDecoder().decode(WireMessage.self, from: data) {
            
            switch wire.type {
            case "typing":
                handleTypingIndicator(from: wire.sender)
                return
            case "ack":
                handleDeliveryAck(wire.ackId)
                return
            default:
                break
            }
            
            // Remove typing indicator
            typingPeers.remove(wire.sender)
            
            let msg = ChatMessage(
                sender: wire.sender,
                text: wire.text ?? text,
                encrypted: encryptionEnabled,
                method: "BLE",
                delivered: true
            )
            messages.append(msg)
            persistMessages()
            
            // Send delivery ack
            sendAck(for: wire.id)
            
            // Sound
            if soundEnabled { sound.play(.message) }
            
            // Unread counter
            if activeTab != .chat { unreadCount += 1 }
            
        } else {
            // Plain text fallback
            let msg = ChatMessage(sender: peerName, text: text, encrypted: encryptionEnabled, method: "BLE")
            messages.append(msg)
            persistMessages()
            if soundEnabled { sound.play(.message) }
            if activeTab != .chat { unreadCount += 1 }
        }
    }
    
    private func sendAck(for messageId: String?) {
        guard let id = messageId else { return }
        let wire = WireMessage(type: "ack", sender: username, ackId: id)
        if let data = try? JSONEncoder().encode(wire),
           let str = String(data: data, encoding: .utf8) {
            let encoded = encryptionEnabled ? crypto.encrypt(str) : str
            if let sendData = encoded.data(using: .utf8) {
                ble.broadcast(sendData)
            }
        }
    }
    
    private func handleDeliveryAck(_ ackId: String?) {
        guard let ackId = ackId else { return }
        if let i = messages.firstIndex(where: { $0.id == ackId }) {
            messages[i].delivered = true
            persistMessages()
        }
    }
    
    private func handleTypingIndicator(from sender: String) {
        typingPeers.insert(sender)
        typingTimers[sender]?.invalidate()
        typingTimers[sender] = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.typingPeers.remove(sender)
            }
        }
    }
    
    // MARK: - Demo
    func loadDemo() {
        guard !demoLoaded else { return }
        demoLoaded = true
        let demos = [
            ("Node-7A3F", "Signal check — can you read me? Running mesh relay test."),
            ("Node-B2D1", "Loud and clear. Packet routed through 3 intermediate nodes."),
            ("Node-7A3F", "Confirmed. No cell towers, no internet. Fully decentralized."),
            ("Node-E9C2", "Just joined the mesh from 200m away. AES-256 handshake complete."),
        ]
        for (i, (sender, text)) in demos.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.6) { [weak self] in
                let msg = ChatMessage(sender: sender, text: text, encrypted: true, method: "BLE", delivered: true)
                self?.messages.append(msg)
                self?.persistMessages()
            }
        }
        addLog("Loaded demonstration messages", .info)
    }
    
    // MARK: - Clear Chat
    func clearChat() {
        messages.removeAll()
        UserDefaults.standard.removeObject(forKey: "meshlink_messages")
        addLog("Chat history cleared", .info)
    }
    
    // MARK: - Copy Key
    func copyKey() {
        UIPasteboard.general.string = encryptionKey
        keyCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.keyCopied = false
        }
    }
    
    // MARK: - Logs
    func addLog(_ text: String, _ level: LogEntry.LogLevel = .info) {
        logs.append(LogEntry(timestamp: Date(), text: text, level: level))
        if logs.count > 100 { logs.removeFirst(logs.count - 100) }
    }
    
    func clearLogs() {
        logs.removeAll()
    }
    
    // MARK: - Persistence
    private func persistMessages() {
        let toSave = Array(messages.suffix(200))
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: "meshlink_messages")
        }
    }
    
    private func loadPersistedData() {
        if let data = UserDefaults.standard.data(forKey: "meshlink_messages"),
           let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = saved
        }
        soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
    }
    
    // MARK: - BLE Callbacks
    private func setupBLECallbacks() {
        ble.onMessageReceived = { [weak self] peerName, rawData in
            Task { @MainActor in
                self?.processIncoming(peerName: peerName, rawData: rawData)
            }
        }
        ble.onLog = { [weak self] text, level in
            Task { @MainActor in
                self?.addLog(text, level)
            }
        }
        ble.onPeerConnected = { [weak self] name in
            Task { @MainActor in
                if self?.soundEnabled == true { self?.sound.play(.connect) }
                self?.addLog("\(name) connected", .success)
            }
        }
        ble.onPeerDisconnected = { [weak self] name in
            Task { @MainActor in
                if self?.soundEnabled == true { self?.sound.play(.disconnect) }
                self?.addLog("\(name) disconnected", .warning)
            }
        }
    }
    
    private func setupBindings() {
        ble.$peers.receive(on: DispatchQueue.main).assign(to: &$peers)
        ble.$isScanning.receive(on: DispatchQueue.main).assign(to: &$isScanning)
        ble.$bluetoothState.receive(on: DispatchQueue.main).map { $0 == .poweredOn }.assign(to: &$bluetoothReady)
    }
}
