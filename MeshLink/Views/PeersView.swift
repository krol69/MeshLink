import SwiftUI

struct PeersView: View {
    @EnvironmentObject var vm: MeshViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Scan Button
            Button(action: {
                if vm.isScanning { vm.stopScan() } else { vm.startScan() }
            }) {
                HStack(spacing: 8) {
                    if vm.isScanning {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "bluetooth")
                            .font(.system(size: 14))
                    }
                    Text(vm.isScanning ? "SCANNING..." : "SCAN FOR DEVICES")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(0.5)
                }
                .foregroundColor(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(scanBtnBg)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.borderAccent))
            }
            .padding(.horizontal, 16).padding(.top, 8)
            
            // Filter toggle
            HStack {
                let meshCount = vm.ble.peers.filter(\.isMeshLink).count
                Text("DEVICES (\(vm.ble.filteredPeers.count))")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
                    .tracking(1.5)
                
                if meshCount > 0 {
                    Text("• \(meshCount) MeshLink")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Theme.accent)
                }
                
                Spacer()
                
                Button {
                    vm.haptic.tap()
                    vm.ble.showMeshLinkOnly.toggle()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: vm.ble.showMeshLinkOnly ? "antenna.radiowaves.left.and.right" : "wifi")
                            .font(.system(size: 9))
                        Text(vm.ble.showMeshLinkOnly ? "Mesh" : "All")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(vm.ble.showMeshLinkOnly ? Theme.accent : Theme.textMuted)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(vm.ble.showMeshLinkOnly ? Theme.accent.opacity(0.1) : Theme.surface)
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(vm.ble.showMeshLinkOnly ? Theme.borderAccent : Theme.border))
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
            
            // Fix #8: Pull to refresh on peer list
            List {
                if vm.ble.filteredPeers.isEmpty {
                    emptyState
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(vm.ble.filteredPeers) { peer in
                        PeerCardView(
                            peer: peer,
                            nickname: vm.displayName(for: peer),
                            isEditing: vm.editingNicknamePeerId == peer.id,
                            nicknameInput: $vm.nicknameInput,
                            onConnect: { vm.connectPeer(peer) },
                            onDisconnect: { vm.disconnectPeer(peer) },
                            onLongPress: { vm.startNicknameEdit(for: peer) },
                            onSaveNickname: { vm.saveNickname() },
                            onCancelNickname: { vm.cancelNicknameEdit() }
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }
                
                howItWorksCard
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 40, trailing: 16))
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable {
                // Fix #8: Pull to refresh triggers scan
                vm.startScan()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }
    
    @ViewBuilder
    private var scanBtnBg: some View {
        if vm.isScanning {
            Theme.accent.opacity(0.04)
        } else {
            LinearGradient(colors: [Theme.accent.opacity(0.1), Theme.accentBlue.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 30)).foregroundColor(Color.white.opacity(0.1)).padding(.top, 16)
            Text("No devices found").font(.system(size: 12)).foregroundColor(Theme.textMuted)
            Text("Tap Scan or pull down to find nearby Bluetooth devices.").font(.system(size: 11)).foregroundColor(Theme.textMuted).multilineTextAlignment(.center).frame(maxWidth: 240)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }
    
    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle").font(.system(size: 11)).foregroundColor(Theme.purple.opacity(0.7))
                Text("HOW MESHLINK WORKS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.purple.opacity(0.8)).tracking(1)
            }
            VStack(alignment: .leading, spacing: 6) {
                infoRow(n: "1", t: "Share key via NFC, QR code, or type on both devices")
                infoRow(n: "2", t: "Scan and connect to nearby MeshLink peers")
                infoRow(n: "3", t: "Messages are AES-256 encrypted end-to-end")
                infoRow(n: "4", t: "Mesh relay forwards through intermediate nodes")
                infoRow(n: "5", t: "Long-press a peer to set a nickname")
            }
        }
        .padding(14).background(Theme.purple.opacity(0.04)).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.purple.opacity(0.1)))
    }
    
    private func infoRow(n: String, t: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(n).font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.purple.opacity(0.5))
                .frame(width: 14, height: 14)
                .background(Theme.purple.opacity(0.1)).cornerRadius(3)
            Text(t).font(.system(size: 11)).foregroundColor(Color.white.opacity(0.4)).lineSpacing(2)
        }
    }
}

// MARK: - Peer Card (Fix #9: nickname editing, Fix #11: connecting spinner)
struct PeerCardView: View {
    let peer: BLEPeer
    let nickname: String
    let isEditing: Bool
    @Binding var nicknameInput: String
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onLongPress: () -> Void
    let onSaveNickname: () -> Void
    let onCancelNickname: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Avatar
                Text(String(nickname.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.bg0)
                    .frame(width: 36, height: 36)
                    .background(LinearGradient(
                        colors: [peer.name.meshColor, peer.id.meshColor],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(nickname)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.text1)
                            .lineLimit(1)
                        
                        if peer.isMeshLink {
                            Text("MESH")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.accent)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Theme.accent.opacity(0.12))
                                .cornerRadius(3)
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Text(String(peer.id.prefix(12)) + "...")
                            .font(.system(size: 8, design: .monospaced)).foregroundColor(Theme.textMuted)
                        
                        HStack(spacing: 2) {
                            signalBars(rssi: peer.rssi)
                            Text("\(peer.rssi)dBm")
                                .font(.system(size: 8, design: .monospaced)).foregroundColor(Theme.textMuted)
                        }
                    }
                }
                
                Spacer()
                
                // Fix #11: Connection state button with spinner
                connectionButton
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.5) {
                // Fix #9: Long press to rename
                HapticService.shared.button()
                onLongPress()
            }
            
            // Fix #9: Inline nickname editor
            if isEditing {
                HStack(spacing: 6) {
                    TextField("Enter nickname...", text: $nicknameInput)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.text1)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Theme.bg0)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent.opacity(0.3)))
                        .submitLabel(.done)
                        .onSubmit { onSaveNickname() }
                    
                    Button(action: onSaveNickname) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.accent)
                            .frame(width: 30, height: 30)
                            .background(Theme.accent.opacity(0.12))
                            .cornerRadius(6)
                    }
                    
                    Button(action: onCancelNickname) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.danger)
                            .frame(width: 30, height: 30)
                            .background(Theme.danger.opacity(0.08))
                            .cornerRadius(6)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10).background(Theme.surface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(peer.isMeshLink ? Theme.borderAccent : Theme.border))
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }
    
    // Fix #11: Connection button with connecting spinner
    @ViewBuilder
    private var connectionButton: some View {
        if peer.connecting {
            // Connecting spinner
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                .scaleEffect(0.7)
                .frame(width: 50, height: 34)
                .background(Theme.accent.opacity(0.06))
                .cornerRadius(7)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.borderAccent))
        } else if peer.connected && peer.isMeshLink {
            // Connected MeshLink - disconnect button
            Button(action: onDisconnect) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 7, height: 7)
                        .shadow(color: Theme.accent, radius: 3)
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 12))
                }
                .foregroundColor(Theme.danger)
                .frame(width: 50, height: 34)
                .background(Theme.danger.opacity(0.08))
                .cornerRadius(7)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.danger.opacity(0.2)))
            }
        } else {
            // Disconnected - connect button
            Button(action: onConnect) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Theme.danger)
                        .frame(width: 7, height: 7)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                }
                .foregroundColor(Theme.accent)
                .frame(width: 50, height: 34)
                .background(Theme.accent.opacity(0.12))
                .cornerRadius(7)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.borderAccent))
            }
        }
    }
    
    @ViewBuilder
    private func signalBars(rssi: Int) -> some View {
        HStack(spacing: 1.5) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(rssi > [-85, -70, -55, -40][i] ? Theme.accent : Theme.textMuted.opacity(0.3))
                    .frame(width: 3, height: CGFloat(3 + i * 3))
            }
        }
        .frame(height: 12, alignment: .bottom)
    }
}
