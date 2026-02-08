import Foundation

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
    
    init(sender: String, text: String, isOwn: Bool = false, encrypted: Bool = true, method: String = "BLE", delivered: Bool = false) {
        self.id = UUID().uuidString
        self.sender = sender
        self.text = text
        self.timestamp = Date()
        self.isOwn = isOwn
        self.encrypted = encrypted
        self.method = method
        self.delivered = delivered
    }
    
    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: timestamp)
    }
}

// MARK: - Wire Protocol
struct WireMessage: Codable {
    let v: Int
    let type: String // "msg", "typing", "ack"
    let id: String?
    let sender: String
    let text: String?
    let ackId: String?
    
    init(type: String, sender: String, text: String? = nil, id: String? = nil, ackId: String? = nil) {
        self.v = 2
        self.type = type
        self.id = id ?? UUID().uuidString
        self.sender = sender
        self.text = text
        self.ackId = ackId
    }
}

// MARK: - Peer Model
struct BLEPeer: Identifiable, Equatable {
    let id: String // peripheral UUID
    var name: String
    var connected: Bool
    var rssi: Int
    var lastSeen: Date
    
    var signalStrength: String {
        if rssi > -50 { return "Strong" }
        if rssi > -70 { return "Good" }
        if rssi > -85 { return "Weak" }
        return "Very Weak"
    }
    
    static func == (lhs: BLEPeer, rhs: BLEPeer) -> Bool {
        lhs.id == rhs.id && lhs.connected == rhs.connected && lhs.name == rhs.name
    }
}

// MARK: - Log Entry
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let text: String
    let level: LogLevel
    
    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: timestamp)
    }
    
    enum LogLevel {
        case info, success, warning, error, data
        
        var color: String {
            switch self {
            case .info: return "secondary"
            case .success: return "green"
            case .warning: return "yellow"
            case .error: return "red"
            case .data: return "cyan"
            }
        }
    }
}
