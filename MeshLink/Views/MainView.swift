import SwiftUI

struct MainView: View {
    @EnvironmentObject var vm: MeshViewModel
    
    var body: some View {
        ZStack {
            Theme.bg0.ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                headerBar
                
                if vm.showAbout { aboutPanel }
                if vm.showSettings { settingsPanel }
                if vm.showKeyShare { keySharePanel }
                
                tabBar
                
                Group {
                    switch vm.activeTab {
                    case .chat: ChatView()
                    case .peers: PeersView()
                    case .logs: LogsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .edgesIgnoringSafeArea(.bottom)
        }
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.gradient)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("MESHLINK")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Theme.gradient)
                    
                    HStack(spacing: 5) {
                        Circle()
                            .fill(vm.ble.connectedCount > 0 ? Theme.accent : Theme.danger)
                            .frame(width: 5, height: 5)
                            .shadow(color: vm.ble.connectedCount > 0 ? Theme.accent : Theme.danger, radius: 2)
                        
                        Text(vm.ble.connectedCount > 0
                             ? "\(vm.ble.connectedCount) peer\(vm.ble.connectedCount > 1 ? "s" : "")"
                             : "No peers")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                        
                        Text("|").foregroundColor(Theme.textMuted.opacity(0.4)).font(.system(size: 9))
                        
                        Text(vm.username)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Theme.text2)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                headerBtn(icon: "qrcode", active: vm.showKeyShare) {
                    vm.showKeyShare.toggle()
                    vm.showAbout = false; vm.showSettings = false
                }
                headerBtn(icon: "info.circle", active: vm.showAbout) {
                    vm.showAbout.toggle()
                    vm.showSettings = false; vm.showKeyShare = false
                }
                headerBtn(icon: vm.showSettings ? "xmark" : "gearshape", active: vm.showSettings) {
                    vm.showSettings.toggle()
                    vm.showAbout = false; vm.showKeyShare = false
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.bg1.opacity(0.95))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.border), alignment: .bottom)
    }
    
    private func headerBtn(icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(active ? Theme.accent : Theme.text2)
                .frame(width: 30, height: 30)
                .background(active ? Theme.accent.opacity(0.15) : Color.clear)
                .cornerRadius(7)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(active ? Theme.borderAccent : Theme.border))
        }
    }
    
    // MARK: - Key Share Panel (QR + NFC)
    private var keySharePanel: some View {
        VStack(spacing: 12) {
            Text("SHARE ENCRYPTION KEY")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.accent)
                .tracking(1.5)
            
            if let qrImage = vm.generateQRCode(for: vm.encryptionKey) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .background(Color.white)
                    .cornerRadius(10)
                
                Text("Scan this QR code on another device")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
            } else {
                Text("Set an encryption key first")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textMuted)
            }
            
            if vm.nfc.isAvailable {
                HStack(spacing: 10) {
                    Button(action: vm.readKeyFromNFC) {
                        HStack(spacing: 5) {
                            Image(systemName: "wave.3.right").font(.system(size: 11))
                            Text("Read NFC").font(.system(size: 10, weight: .semibold, design: .monospaced))
                        }
                        .foregroundColor(Theme.accentBlue)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Theme.accentBlue.opacity(0.08))
                        .cornerRadius(7)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.accentBlue.opacity(0.2)))
                    }
                    
                    Button(action: vm.writeKeyToNFC) {
                        HStack(spacing: 5) {
                            Image(systemName: "wave.3.left").font(.system(size: 11))
                            Text("Write NFC").font(.system(size: 10, weight: .semibold, design: .monospaced))
                        }
                        .foregroundColor(Theme.purple)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Theme.purple.opacity(0.08))
                        .cornerRadius(7)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.purple.opacity(0.2)))
                    }
                }
                
                Text("Write key to NFC tag, then tap other phone to read")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            
            if let status = vm.nfc.statusMessage {
                Text(status)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.accent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.bg1.opacity(0.98))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.border), alignment: .bottom)
    }
    
    // MARK: - About Panel
    private var aboutPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.gradient)
                Text("MeshLink v3.0.0")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.text1)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                featureRow(icon: "lock.fill", text: "AES-256-GCM end-to-end encryption")
                featureRow(icon: "point.3.connected.trianglepath.dotted", text: "Mesh relay — messages hop between peers")
                featureRow(icon: "wave.3.right", text: "NFC key sharing — tap to pair")
                featureRow(icon: "qrcode", text: "QR code key exchange")
                featureRow(icon: "photo", text: "Image sharing over Bluetooth")
                featureRow(icon: "bell.fill", text: "Background notifications")
                featureRow(icon: "arrow.triangle.2.circlepath", text: "Auto-reconnect to known peers")
            }
            
            Text("No servers • No internet • No third parties")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Theme.textMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bg1.opacity(0.98))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.border), alignment: .bottom)
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 9)).foregroundColor(Theme.accent)
                .frame(width: 14)
            Text(text).font(.system(size: 10)).foregroundColor(Theme.text2)
        }
    }
    
    // MARK: - Settings Panel
    private var settingsPanel: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
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
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.text1)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    
                    Button { vm.showKey.toggle() } label: {
                        Image(systemName: vm.showKey ? "eye.slash" : "eye")
                            .font(.system(size: 10)).foregroundColor(Theme.text2)
                    }
                    Button(action: vm.copyKey) {
                        Image(systemName: vm.keyCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(vm.keyCopied ? Theme.accent : Theme.text2)
                    }
                }
                .padding(8)
                .background(Theme.bg0)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border))
            }
            
            HStack(spacing: 6) {
                settingsBtn(icon: vm.encryptionEnabled ? "lock.fill" : "lock.open",
                           label: vm.encryptionEnabled ? "AES-GCM" : "Off",
                           active: vm.encryptionEnabled,
                           color: vm.encryptionEnabled ? Theme.accent : Theme.danger) {
                    vm.encryptionEnabled.toggle()
                    vm.addLog("Encryption \(vm.encryptionEnabled ? "on" : "off")", .info)
                }
                
                settingsBtn(icon: vm.soundEnabled ? "speaker.wave.2" : "speaker.slash",
                           label: vm.soundEnabled ? "Sound" : "Muted",
                           active: vm.soundEnabled,
                           color: vm.soundEnabled ? Theme.accent : Theme.textMuted) {
                    vm.soundEnabled.toggle()
                    vm.sound.enabled = vm.soundEnabled
                }
                
                settingsBtn(icon: vm.ble.showMeshLinkOnly ? "antenna.radiowaves.left.and.right" : "wifi",
                           label: vm.ble.showMeshLinkOnly ? "Mesh" : "All",
                           active: vm.ble.showMeshLinkOnly,
                           color: Theme.accentBlue) {
                    vm.ble.showMeshLinkOnly.toggle()
                }
            }
            
            Button(action: vm.leaveMesh) {
                HStack(spacing: 5) {
                    Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 10))
                    Text("Leave Mesh").font(.system(size: 10, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(Theme.danger)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Theme.danger.opacity(0.08))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.danger.opacity(0.2)))
            }
        }
        .padding(12)
        .background(Theme.bg1.opacity(0.98))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.border), alignment: .bottom)
    }
    
    private func settingsBtn(icon: String, label: String, active: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label).font(.system(size: 10, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(color)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(color.opacity(0.08))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(active ? color.opacity(0.2) : Theme.border))
        }
    }
    
    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack(spacing: 2) {
            tabBtn(icon: "bubble.left.fill", label: "Chat", tab: .chat, badge: vm.activeTab != .chat ? vm.unreadCount : 0)
            tabBtn(icon: "person.2.fill", label: "Peers", tab: .peers, badge: vm.ble.connectedCount)
            tabBtn(icon: "terminal.fill", label: "Logs", tab: .logs, badge: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(Theme.bg1.opacity(0.6))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.03)), alignment: .bottom)
    }
    
    private func tabBtn(icon: String, label: String, tab: MeshViewModel.AppTab, badge: Int) -> some View {
        Button {
            vm.activeTab = tab
            if tab == .chat { vm.unreadCount = 0; vm.notifications.clearBadge() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.5)
            }
            .foregroundColor(vm.activeTab == tab ? Theme.accent : Theme.textMuted)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(vm.activeTab == tab ? Theme.accent.opacity(0.15) : Color.clear)
            .cornerRadius(7)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(vm.activeTab == tab ? Theme.borderAccent : Color.clear))
            .overlay(alignment: .topTrailing) {
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.bg0)
                        .frame(width: 14, height: 14)
                        .background(Theme.accent)
                        .clipShape(Circle())
                        .offset(x: 3, y: -3)
                }
            }
        }
    }
}
