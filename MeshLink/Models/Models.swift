import Foundation
import UIKit
import CryptoKit

// MARK: - Account Model
struct Account: Codable, Identifiable {
    let id: String
    var displayName: String
    var pinHash: String
    var createdAt: Date
    var lastLoginAt: Date
    var avatarEmoji: String
    
    init(displayName: String, pin: String, emoji: String = "🔒") {
        self.id = UUID().uuidString
        self.displayName = displayName
        self.pinHash = Account.hashPin(pin)
        self.createdAt = Date()
        self.lastLoginAt = Date()
        self.avatarEmoji = emoji
    }
    
    static func hashPin(_ pin: String) -> String {
        let hash = SHA256.hash(data: Data(pin.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    func verifyPin(_ pin: String) -> Bool {
        Account.hashPin(pin) == pinHash
    }
}

// MARK: - Chat Session Model
struct ChatSession: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var createdBy: String
    var createdAt: Date
    var lastMessageAt: Date
    var peerNames: [String]
    var encryptionKey: String
    var messageCount: Int
    var isArchived: Bool
    var isPinned: Bool
    var lastMessagePreview: String
    
    init(title: String, createdBy: String, encryptionKey: String) {
        self.id = UUID().uuidString
        self.title = title
        self.createdBy = createdBy
        self.createdAt = Date()
        self.lastMessageAt = Date()
        self.peerNames = []
        self.encryptionKey = encryptionKey
        self.messageCount = 0
        self.isArchived = false
        self.isPinned = false
        self.lastMessagePreview = ""
    }
    
    var isActive: Bool { !isArchived }
    
    var timeAgo: String {
        let interval = Date().timeIntervalSince(lastMessageAt)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        return Self.sessionDateFmt.string(from: lastMessageAt)
    }
    
    private static let sessionDateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
    
    static func == (lhs: ChatSession, rhs: ChatSession) -> Bool {
        lhs.id == rhs.id && lhs.lastMessageAt == rhs.lastMessageAt &&
        lhs.isArchived == rhs.isArchived && lhs.messageCount == rhs.messageCount
    }
}

// MARK: - Message Model
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    let sender: String
    let text: String
    let timestamp: Date
    let isOwn: Bool
    let encrypted: Bool
    let method: String
    var delivered: Bool
    var imageData: Data?
    var sessionId: String?
    
    init(sender: String, text: String, isOwn: Bool = false, encrypted: Bool = true,
         method: String = "BLE", delivered: Bool = false, imageData: Data? = nil, sessionId: String? = nil) {
        self.id = UUID().uuidString
        self.sender = sender
        self.text = text
        self.timestamp = Date()
        self.isOwn = isOwn
        self.encrypted = encrypted
        self.method = method
        self.delivered = delivered
        self.imageData = imageData
        self.sessionId = sessionId
    }
    
    // FIX #4: Static cached DateFormatters — NO allocations per cell
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()
    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; return f
    }()
    
    var timeString: String { Self.timeFmt.string(from: timestamp) }
    
    var hasImage: Bool { imageData != nil && !(imageData?.isEmpty ?? true) }
    
    var uiImage: UIImage? {
        guard let data = imageData else { return nil }
        return UIImage(data: data)
    }
    
    var dateSectionLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(timestamp) { return "Today" }
        if cal.isDateInYesterday(timestamp) { return "Yesterday" }
        return Self.dateFmt.string(from: timestamp)
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id && lhs.delivered == rhs.delivered
    }
}

extension ChatMessage {
    init(id: String, sender: String, text: String, timestamp: Date, isOwn: Bool,
         encrypted: Bool, method: String, delivered: Bool, imageData: Data? = nil, sessionId: String? = nil) {
        self.id = id; self.sender = sender; self.text = text; self.timestamp = timestamp
        self.isOwn = isOwn; self.encrypted = encrypted; self.method = method
        self.delivered = delivered; self.imageData = imageData; self.sessionId = sessionId
    }
}

// MARK: - Wire Protocol v3
struct WireMessage: Codable {
    let v: Int; let type: String; let id: String; let sender: String
    let text: String?; let ackId: String?; let ttl: Int?; let originId: String?
    let imgData: String?; let imgThumb: String?
    
    init(type: String, sender: String, text: String? = nil, id: String? = nil,
         ackId: String? = nil, ttl: Int = 3, originId: String? = nil,
         imgData: String? = nil, imgThumb: String? = nil) {
        self.v = 3; self.type = type; self.id = id ?? UUID().uuidString; self.sender = sender
        self.text = text; self.ackId = ackId; self.ttl = ttl
        self.originId = originId ?? sender; self.imgData = imgData; self.imgThumb = imgThumb
    }
}

// MARK: - Chunk Protocol
struct ChunkEnvelope: Codable {
    let msgId: String; let seq: Int; let total: Int; let data: String
}

// MARK: - Peer Model
struct BLEPeer: Identifiable, Equatable {
    let id: String
    var name: String
    var connected: Bool
    var connecting: Bool
    var rssi: Int
    var lastSeen: Date
    var isMeshLink: Bool
    
    init(id: String, name: String, connected: Bool = false, connecting: Bool = false,
         rssi: Int = -100, lastSeen: Date = Date(), isMeshLink: Bool = false) {
        self.id = id; self.name = name; self.connected = connected; self.connecting = connecting
        self.rssi = rssi; self.lastSeen = lastSeen; self.isMeshLink = isMeshLink
    }
    
    var signalStrength: String {
        if rssi > -50 { return "Strong" }
        if rssi > -70 { return "Good" }
        if rssi > -85 { return "Weak" }
        return "Very Weak"
    }
    
    static func == (lhs: BLEPeer, rhs: BLEPeer) -> Bool {
        lhs.id == rhs.id && lhs.connected == rhs.connected && lhs.connecting == rhs.connecting &&
        lhs.name == rhs.name && lhs.isMeshLink == rhs.isMeshLink
    }
}

// MARK: - Log Entry
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let text: String
    let level: LogLevel
    
    // FIX #4: Static cached formatter
    private static let logFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()
    
    var timeString: String { Self.logFmt.string(from: timestamp) }
    
    enum LogLevel { case info, success, warning, error, data }
}
