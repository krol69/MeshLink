import SwiftUI

struct MainView: View {
    @EnvironmentObject var vm: MeshViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar
            
            // Settings / About panels
            if vm.showAbout { aboutPanel }
            if vm.showSettings { settingsPanel }
            
            // Tab bar
            tabBar
            
            // Content
            ZStack {
                Theme.bg0.ignoresSafeArea()
                switch vm.activeTab {
                case .chat: ChatView()
                case .peers: PeersView()
                case .logs: LogsView()
                }
            }
        }
        .background(Theme.bg0.ignoresSafeArea())
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.gradient)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("MESHLINK")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Theme.gradient)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(vm.ble.connectedCount > 0 ? Theme.accent : Theme.danger)
                            .frame(width: 6, height: 6)
                            .shadow(color: vm.ble.connectedCount > 0 ? Theme.accent : Theme.danger, radius: 3)
                        
                        Text(vm.ble.connectedCount > 0
                             ? "\(vm.ble.connectedCount) peer\(vm.ble.connectedCount > 1 ? "s" : "") connected"
                             : "No active peers")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                        
                        Text("|").foregroundColor(Theme.textMuted.opacity(0.4)).font(.system(size: 10))
                        
                        Text(vm.username)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Theme.text2)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                headerButton(icon: "info.circle", active: vm.showAbout) {
                    vm.showAbout.toggle(); vm.showSettings = false
                }
                headerButton(icon: vm.showSettings ? "xmark" : "gearshape", active: vm.showSettings) {
                    vm.showSettings.toggle(); vm.showAbout = false
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.5))
        .background(Theme.bg0.opacity(0.88))
    }
    
    private func headerButton(icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(active ? Theme.accent : Theme.text2)
                .frame(width: 34, height: 34)
                .background(active ? Theme.accent.opacity(0.15) : Color.clear)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(active ? Theme.borderAccent : Theme.border))
        }
    }
    
    // MARK: - About Panel
    private var aboutPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.gradient)
                Text("MeshLink v2.0.0")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.text1)
            }
            Text("Encrypted peer-to-peer Bluetooth messaging. Uses AES-256-GCM encryption with PBKDF2 key derivation (100k iterations). Messages are encrypted end-to-end. No servers, no internet, no third parties.")
                .font(.system(size: 12))
                .foregroundColor(Theme.text2)
                .lineSpacing(4)
            Text("Supports multi-peer broadcast, BLE chunk reassembly, delivery confirmations, and typing indicators.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Theme.textMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bg0.opacity(0.94))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.border), alignment: .bottom)
    }
    
    // MARK: - Settings Panel
    private var settingsPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Encryption Key
                VStack(alignment: .leading, spacing: 4) {
                    Text("ENCRYPTION KEY")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.accent)
                        .tracking(1.5)
                    
                    HStack(spacing: 4) {
                        Group {
                            if vm.showKey {
                                TextField("Key", text: $vm.encryptionKey)
                            } else {
                                SecureField("Key", text: $vm.encryptionKey)
                            }
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.text1)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        
                        Button { vm.showKey.toggle() } label: {
                            Image(systemName: vm.showKey ? "eye.slash" : "eye")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.text2)
                        }
                        
                        Button(action: vm.copyKey) {
                            Image(systemName: vm.keyCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundColor(vm.keyCopied ? Theme.accent : Theme.text2)
                        }
                    }
                    .padding(10)
                    .background(Theme.bg0)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border))
                }
                .frame(maxWidth: .infinity)
            }
            
            HStack(spacing: 8) {
                // Encryption toggle
                settingsButton(
                    icon: vm.encryptionEnabled ? "lock.fill" : "lock.open",
                    label: vm.encryptionEnabled ? "AES-GCM" : "Off",
                    isActive: vm.encryptionEnabled,
                    activeColor: Theme.accent,
                    inactiveColor: Theme.danger
                ) {
                    vm.encryptionEnabled.toggle()
                    vm.addLog("Encryption \(vm.encryptionEnabled ? "enabled" : "disabled")", .info)
                }
                
                // Sound toggle
                settingsButton(
                    icon: vm.soundEnabled ? "speaker.wave.2" : "speaker.slash",
                    label: vm.soundEnabled ? "Sound" : "Muted",
                    isActive: vm.soundEnabled,
                    activeColor: Theme.accent,
                    inactiveColor: Theme.textMuted
                ) {
                    vm.soundEnabled.toggle()
                    vm.sound.enabled = vm.soundEnabled
                }
            }
        }
        .padding(14)
        .background(Theme.bg0.opacity(0.92))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.border), alignment: .bottom)
    }
    
    private func settingsButton(icon: String, label: String, isActive: Bool, activeColor: Color, inactiveColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(isActive ? activeColor : inactiveColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isActive ? activeColor.opacity(0.08) : inactiveColor.opacity(0.08))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isActive ? activeColor.opacity(0.2) : Theme.border))
        }
    }
    
    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack(spacing: 4) {
            tabButton(icon: "bubble.left.fill", label: "Chat", tab: .chat, badge: vm.activeTab != .chat ? vm.unreadCount : 0)
            tabButton(icon: "person.2.fill", label: "Peers", tab: .peers, badge: vm.ble.connectedCount)
            tabButton(icon: "terminal.fill", label: "Logs", tab: .logs, badge: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Theme.bg0.opacity(0.5))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.03)), alignment: .bottom)
    }
    
    private func tabButton(icon: String, label: String, tab: MeshViewModel.AppTab, badge: Int) -> some View {
        Button {
            vm.activeTab = tab
            if tab == .chat { vm.unreadCount = 0 }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(0.5)
            }
            .foregroundColor(vm.activeTab == tab ? Theme.accent : Theme.textMuted)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(vm.activeTab == tab ? Theme.accent.opacity(0.15) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(vm.activeTab == tab ? Theme.borderAccent : Color.clear)
            )
            .overlay(alignment: .topTrailing) {
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.bg0)
                        .frame(width: 16, height: 16)
                        .background(Theme.accent)
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
        }
    }
}
