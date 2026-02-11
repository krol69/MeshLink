import SwiftUI

// MARK: - Sessions Management Sheet
struct SessionsView: View {
    @EnvironmentObject var vm: MeshViewModel
    @ObservedObject var accounts = AccountService.shared
    @State private var showNewSession = false
    @State private var newSessionTitle = ""
    @State private var showArchived = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.bg0.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Account header
                        if let account = accounts.currentAccount {
                            HStack(spacing: 12) {
                                Text(account.avatarEmoji)
                                    .font(.system(size: 28))
                                    .frame(width: 50, height: 50)
                                    .background(Theme.accent.opacity(0.08))
                                    .cornerRadius(12)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(account.displayName)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(Theme.text1)
                                    HStack(spacing: 8) {
                                        Label("\(accounts.activeSessions.count) chats", systemImage: "bubble.left.fill")
                                        Label("\(accounts.archivedSessions.count) archived", systemImage: "archivebox.fill")
                                    }
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(Theme.textMuted)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(Theme.bg1).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                        }
                        
                        // New session button
                        Button { showNewSession = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.bubble.fill").font(.system(size: 14))
                                Text("NEW CHAT SESSION")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(0.5)
                            }
                            .foregroundColor(Theme.accent)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Theme.accent.opacity(0.08)).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.borderAccent))
                        }
                        
                        // Active sessions
                        if !accounts.activeSessions.isEmpty {
                            sectionHeader("ACTIVE CHATS", count: accounts.activeSessions.count)
                            ForEach(accounts.activeSessions) { session in
                                sessionCard(session, isActive: session.id == accounts.activeSessionId)
                            }
                        }
                        
                        // Archived sessions
                        if !accounts.archivedSessions.isEmpty {
                            Button { showArchived.toggle() } label: {
                                HStack {
                                    sectionHeader("ARCHIVED", count: accounts.archivedSessions.count)
                                    Spacer()
                                    Image(systemName: showArchived ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 10)).foregroundColor(Theme.textMuted)
                                }
                            }
                            if showArchived {
                                ForEach(accounts.archivedSessions) { session in
                                    sessionCard(session, isActive: false, archived: true)
                                }
                            }
                        }
                        
                        // Logout
                        Button {
                            vm.haptic.tap(); accounts.logout(); dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 11))
                                Text("Log Out").font(.system(size: 11, weight: .semibold, design: .monospaced))
                            }
                            .foregroundColor(Theme.danger)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Theme.danger.opacity(0.06)).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.danger.opacity(0.15)))
                        }
                        .padding(.top, 8)
                        
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 16).padding(.top, 12)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SESSIONS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.accent).tracking(1.5)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18)).foregroundColor(Theme.text2)
                    }
                }
            }
            .alert("New Chat Session", isPresented: $showNewSession) {
                TextField("Session name", text: $newSessionTitle)
                Button("Create") {
                    let title = newSessionTitle.trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty { vm.createNewSession(title: title); newSessionTitle = "" }
                }
                Button("Cancel", role: .cancel) { newSessionTitle = "" }
            } message: {
                Text("Give this chat session a name to keep your conversations organized.")
            }
        }
    }
    
    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textMuted).tracking(1.5)
            Text("(\(count))")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
    }
    
    private func sessionCard(_ session: ChatSession, isActive: Bool, archived: Bool = false) -> some View {
        Button {
            if !archived { vm.switchToSession(session); dismiss() }
        } label: {
            HStack(spacing: 10) {
                VStack(spacing: 4) {
                    if session.isPinned {
                        Image(systemName: "pin.fill").font(.system(size: 8)).foregroundColor(Theme.warning)
                    }
                    Circle()
                        .fill(isActive ? Theme.accent : (archived ? Theme.textMuted : Theme.text2))
                        .frame(width: 8, height: 8)
                        .shadow(color: isActive ? Theme.accent.opacity(0.5) : .clear, radius: 3)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(session.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isActive ? Theme.accent : Theme.text1)
                            .lineLimit(1)
                        if isActive {
                            Text("ACTIVE")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.accent)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Theme.accent.opacity(0.12)).cornerRadius(3)
                        }
                    }
                    
                    if !session.lastMessagePreview.isEmpty {
                        Text(session.lastMessagePreview)
                            .font(.system(size: 10)).foregroundColor(Theme.textMuted).lineLimit(1)
                    }
                    
                    HStack(spacing: 8) {
                        Text("by \(session.createdBy)")
                        Text("•")
                        Text("\(session.messageCount) msgs")
                        Text("•")
                        Text(session.timeAgo)
                        if !session.peerNames.isEmpty {
                            Text("•")
                            Text(session.peerNames.prefix(2).joined(separator: ", "))
                        }
                    }
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
                }
                
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(Theme.textMuted)
            }
            .padding(12)
            .background(isActive ? Theme.accent.opacity(0.04) : Theme.surface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isActive ? Theme.borderAccent : Theme.border))
        }
        .contextMenu {
            if !archived {
                Button { accounts.pinSession(session.id) } label: {
                    Label(session.isPinned ? "Unpin" : "Pin", systemImage: session.isPinned ? "pin.slash" : "pin")
                }
                Button { accounts.archiveSession(session.id) } label: {
                    Label("Archive", systemImage: "archivebox")
                }
            } else {
                Button { accounts.unarchiveSession(session.id) } label: {
                    Label("Unarchive", systemImage: "tray.and.arrow.up")
                }
            }
            Button(role: .destructive) { accounts.deleteSession(session.id) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
