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
                    HStack(spacing: 10) {
                        if vm.isScanning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "bluetooth")
                                .font(.system(size: 15))
                        }
                        Text(vm.isScanning ? "SCANNING..." : "SCAN FOR DEVICES")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .tracking(0.5)
                    }
                    .foregroundColor(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(scanButtonBackground)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.borderAccent))
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 18)
                
                // Bluetooth warning
                if !vm.bluetoothReady {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.warning)
                        Text("Bluetooth is off or unavailable. Enable it in Settings > Bluetooth.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Theme.warning.opacity(0.7))
                    }
                    .padding(14)
                    .background(Theme.warning.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.warning.opacity(0.12)))
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
                }
                
                // Devices header
                HStack {
                    Text("DEVICES (\(vm.peers.count))")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                        .tracking(1.5)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
                
                // Peer list
                if vm.peers.isEmpty {
                    emptyPeersState
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.peers) { peer in
                            PeerCardView(
                                peer: peer,
                                onConnect: { vm.connectPeer(peer) },
                                onDisconnect: { vm.disconnectPeer(peer) }
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                }
                
                // How it works card
                howItWorksCard
                    .padding(.horizontal, 18)
                    .padding(.top, 24)
                    .padding(.bottom, 30)
            }
        }
    }
    
    @ViewBuilder
    private var scanButtonBackground: some View {
        if vm.isScanning {
            Theme.accent.opacity(0.04)
        } else {
            LinearGradient(
                colors: [Theme.accent.opacity(0.1), Theme.accentBlue.opacity(0.1)],
                startPoint: .leading, endPoint: .trailing
            )
        }
    }
    
    private var emptyPeersState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(Color.white.opacity(0.1))
                .padding(.top, 20)
            
            Text("No devices found")
                .font(.system(size: 13))
                .foregroundColor(Theme.textMuted)
            
            Text("Tap Scan to search for nearby Bluetooth devices running MeshLink.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .padding(.vertical, 20)
    }
    
    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "818CF8").opacity(0.7))
                Text("HOW MESHLINK WORKS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "818CF8").opacity(0.8))
                    .tracking(1)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                infoRow(num: "1", text: "Both devices open MeshLink and enter the same encryption key")
                infoRow(num: "2", text: "Scan and connect to nearby Bluetooth devices")
                infoRow(num: "3", text: "Messages are AES-256 encrypted before Bluetooth transmission")
                infoRow(num: "4", text: "All data stays local — no internet or servers involved")
            }
        }
        .padding(16)
        .background(Color(hex: "818CF8").opacity(0.04))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "818CF8").opacity(0.1)))
    }
    
    private func infoRow(num: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(num)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "818CF8").opacity(0.5))
                .frame(width: 16, height: 16)
                .background(Color(hex: "818CF8").opacity(0.1))
                .cornerRadius(4)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.4))
                .lineSpacing(2)
        }
    }
}

// MARK: - Peer Card
struct PeerCardView: View {
    let peer: BLEPeer
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Text(String(peer.name.prefix(1)).uppercased())
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.bg0)
                .frame(width: 38, height: 38)
                .background(
                    LinearGradient(
                        colors: [peer.name.meshColor, (peer.id).meshColor],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(8)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(peer.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.text1)
                
                HStack(spacing: 8) {
                    Text(peer.id.prefix(16) + "...")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                    
                    // Signal strength
                    HStack(spacing: 2) {
                        signalBars(rssi: peer.rssi)
                        Text("\(peer.rssi)dBm")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                    }
                }
            }
            
            Spacer()
            
            // Status + Action
            HStack(spacing: 8) {
                Circle()
                    .fill(peer.connected ? Theme.accent : Theme.danger)
                    .frame(width: 8, height: 8)
                    .shadow(color: peer.connected ? Theme.accent : Theme.danger, radius: 3)
                
                if peer.connected {
                    Button(action: onDisconnect) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.danger)
                            .frame(width: 28, height: 28)
                            .background(Theme.danger.opacity(0.08))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.danger.opacity(0.2)))
                    }
                } else {
                    Button(action: onConnect) {
                        Image(systemName: "bluetooth")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.accent)
                            .frame(width: 28, height: 28)
                            .background(Theme.accent.opacity(0.15))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.borderAccent))
                    }
                }
            }
        }
        .padding(12)
        .background(Theme.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
    }
    
    @ViewBuilder
    private func signalBars(rssi: Int) -> some View {
        HStack(spacing: 1.5) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barActive(index: i, rssi: rssi) ? Theme.accent : Theme.textMuted.opacity(0.3))
                    .frame(width: 3, height: CGFloat(4 + i * 3))
            }
        }
        .frame(height: 14, alignment: .bottom)
    }
    
    private func barActive(index: Int, rssi: Int) -> Bool {
        let thresholds = [-85, -70, -55, -40]
        return rssi > thresholds[index]
    }
}
