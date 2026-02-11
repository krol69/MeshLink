import Foundation

// MARK: - Account & Session Manager
final class AccountService: ObservableObject {
    static let shared = AccountService()
    
    @Published var accounts: [Account] = []
    @Published var currentAccount: Account?
    @Published var sessions: [ChatSession] = []
    @Published var activeSessionId: String?
    
    private let accountsKey = "meshlink_accounts"
    private let sessionsKey = "meshlink_sessions"
    private let currentAccountKey = "meshlink_current_account"
    private let sessionMsgsPrefix = "meshlink_session_msgs_"
    
    var isLoggedIn: Bool { currentAccount != nil }
    
    var activeSession: ChatSession? {
        sessions.first(where: { $0.id == activeSessionId })
    }
    
    var activeSessions: [ChatSession] {
        sessions.filter { !$0.isArchived }.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.lastMessageAt > $1.lastMessageAt
        }
    }
    
    var archivedSessions: [ChatSession] {
        sessions.filter { $0.isArchived }.sorted { $0.lastMessageAt > $1.lastMessageAt }
    }
    
    init() { load() }
    
    // MARK: - Account CRUD
    func createAccount(name: String, pin: String, emoji: String) -> Account {
        var account = Account(displayName: name, pin: pin, emoji: emoji)
        account.lastLoginAt = Date()
        accounts.append(account)
        currentAccount = account
        save()
        return account
    }
    
    func login(accountId: String, pin: String) -> Bool {
        guard var account = accounts.first(where: { $0.id == accountId }) else { return false }
        guard account.verifyPin(pin) else { return false }
        account.lastLoginAt = Date()
        if let i = accounts.firstIndex(where: { $0.id == accountId }) { accounts[i] = account }
        currentAccount = account
        save()
        return true
    }
    
    func logout() {
        currentAccount = nil
        activeSessionId = nil
        UserDefaults.standard.removeObject(forKey: currentAccountKey)
    }
    
    func deleteAccount(_ id: String) {
        // Remove sessions for this account
        let toRemove = sessions.filter { $0.createdBy == accounts.first(where: { $0.id == id })?.displayName }
        for s in toRemove {
            UserDefaults.standard.removeObject(forKey: sessionMsgsPrefix + s.id)
        }
        sessions.removeAll(where: { toRemove.map(\.id).contains($0.id) })
        accounts.removeAll(where: { $0.id == id })
        if currentAccount?.id == id { logout() }
        save()
    }
    
    // MARK: - Session CRUD
    func createSession(title: String, encryptionKey: String) -> ChatSession {
        let session = ChatSession(
            title: title,
            createdBy: currentAccount?.displayName ?? "Unknown",
            encryptionKey: encryptionKey
        )
        sessions.append(session)
        activeSessionId = session.id
        save()
        return session
    }
    
    func switchSession(_ id: String) {
        activeSessionId = id
        save()
    }
    
    func archiveSession(_ id: String) {
        if let i = sessions.firstIndex(where: { $0.id == id }) {
            sessions[i].isArchived = true
            if activeSessionId == id { activeSessionId = activeSessions.first?.id }
            save()
        }
    }
    
    func unarchiveSession(_ id: String) {
        if let i = sessions.firstIndex(where: { $0.id == id }) {
            sessions[i].isArchived = false
            save()
        }
    }
    
    func deleteSession(_ id: String) {
        sessions.removeAll(where: { $0.id == id })
        UserDefaults.standard.removeObject(forKey: sessionMsgsPrefix + id)
        if activeSessionId == id { activeSessionId = activeSessions.first?.id }
        save()
    }
    
    func pinSession(_ id: String) {
        if let i = sessions.firstIndex(where: { $0.id == id }) {
            sessions[i].isPinned.toggle()
            save()
        }
    }
    
    // MARK: - Session Messages
    func saveSessionMessages(_ messages: [ChatMessage], sessionId: String) {
        let toSave = Array(messages.suffix(500))
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: sessionMsgsPrefix + sessionId)
        }
        if let i = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[i].messageCount = messages.count
            sessions[i].lastMessageAt = messages.last?.timestamp ?? Date()
            sessions[i].lastMessagePreview = messages.last?.text ?? ""
            sessions[i].peerNames = Array(Set(messages.filter { !$0.isOwn }.map(\.sender)))
            save()
        }
    }
    
    func loadSessionMessages(_ sessionId: String) -> [ChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: sessionMsgsPrefix + sessionId),
              let msgs = try? JSONDecoder().decode([ChatMessage].self, from: data) else { return [] }
        return msgs
    }
    
    // MARK: - Persistence
    private func save() {
        if let d = try? JSONEncoder().encode(accounts) { UserDefaults.standard.set(d, forKey: accountsKey) }
        if let d = try? JSONEncoder().encode(sessions) { UserDefaults.standard.set(d, forKey: sessionsKey) }
        if let id = currentAccount?.id { UserDefaults.standard.set(id, forKey: currentAccountKey) }
        UserDefaults.standard.set(activeSessionId, forKey: "meshlink_active_session")
    }
    
    private func load() {
        if let d = UserDefaults.standard.data(forKey: accountsKey),
           let a = try? JSONDecoder().decode([Account].self, from: d) { accounts = a }
        if let d = UserDefaults.standard.data(forKey: sessionsKey),
           let s = try? JSONDecoder().decode([ChatSession].self, from: d) { sessions = s }
        if let id = UserDefaults.standard.string(forKey: currentAccountKey) {
            currentAccount = accounts.first(where: { $0.id == id })
        }
        activeSessionId = UserDefaults.standard.string(forKey: "meshlink_active_session")
    }
}
