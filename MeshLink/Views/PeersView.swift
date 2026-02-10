import SwiftUI

struct PeersView: View {
    @EnvironmentObject var vm: MeshViewModel
    
    var body: some View {
        ScrollView {
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
                .padding(.horizontal, 16).padding(.top, 12)
                
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
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
                
                // Bluetooth warning
                if !vm.bluetoothReady {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle").font(.system(size: 11)).foregroundColor(Theme.warning)
                        Text("Bluetooth is off. Enable in Settings.")
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(Theme.warning.opacity(0.7))
                    }
                    .padding(12)
                    .background(Theme.warning.opacity(0.05)).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.warning.opacity(0.12)))
                    .padding(.horizontal, 16).padding(.bottom, 12)
                }
                
                // Peer list
                if vm.ble.filteredPeers.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 6) {
                        ForEach(vm.ble.filteredPeers) { peer in
                            PeerCardView(peer: peer, nickname: vm.displayName(for: peer),
                                        onConnect: { vm.connectPeer(peer) },
                                        onDisconnect: { vm.disconnectPeer(peer) })
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                howItWorksCard
                    .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 40)
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
            Text("Tap Scan to find nearby Bluetooth devices.").font(.system(size: 11)).foregroundColor(Theme.textMuted).multilineTextAlignment(.center).frame(maxWidth: 240)
        }
        .padding(.vertical, 16)
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
                infoRow(n: "5", t: "Send text and images — all over Bluetooth")
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

// MARK: - Peer Card
struct PeerCardView: View {
    let peer: BLEPeer
    let nickname: String
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    
    var body: some View {
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
            
            // Connection status + button
            if peer.connected {
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
        .padding(10).background(Theme.surface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(peer.isMeshLink ? Theme.borderAccent : Theme.border))
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
