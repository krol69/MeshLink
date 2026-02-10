import SwiftUI

struct SetupView: View {
    @EnvironmentObject var vm: MeshViewModel
    @FocusState private var focusField: Field?
    
    enum Field { case name, key }
    
    var body: some View {
        ZStack {
            Theme.bg0.ignoresSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 24)
                    
                    // Logo
                    VStack(spacing: 10) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.gradient)
                        
                        Text("MESHLINK")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(Theme.gradientFull)
                        
                        Text("AES-256 ENCRYPTED P2P MESH")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                            .tracking(2)
                    }
                    .padding(.bottom, 28)
                    
                    // Form Card
                    VStack(spacing: 16) {
                        // Node Name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NODE NAME")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(Theme.accent)
                                .tracking(1.5)
                            
                            TextField("Enter your display name", text: $vm.username)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.text1)
                                .padding(12)
                                .background(Theme.bg0)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                                .focused($focusField, equals: .name)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .submitLabel(.next)
                                .onSubmit { focusField = .key }
                        }
                        
                        // Encryption Key
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 5) {
                                Image(systemName: "shield.checkered")
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.accent)
                                Text("ENCRYPTION KEY")
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Theme.accent)
                                    .tracking(1.5)
                            }
                            
                            HStack(spacing: 6) {
                                Group {
                                    if vm.showKey {
                                        TextField("Shared secret", text: $vm.encryptionKey)
                                            .font(.system(size: 13, design: .monospaced))
                                    } else {
                                        SecureField("Shared secret", text: $vm.encryptionKey)
                                            .font(.system(size: 13, design: .monospaced))
                                    }
                                }
                                .textFieldStyle(.plain)
                                .foregroundColor(Theme.text1)
                                .focused($focusField, equals: .key)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .submitLabel(.go)
                                .onSubmit { vm.joinMesh() }
                                
                                Button { vm.showKey.toggle() } label: {
                                    Image(systemName: vm.showKey ? "eye.slash" : "eye")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.text2)
                                }
                            }
                            .padding(12)
                            .background(Theme.bg0)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                            
                            // NFC + hint
                            HStack(spacing: 6) {
                                if vm.nfc.isAvailable {
                                    Button(action: vm.readKeyFromNFC) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "wave.3.right")
                                                .font(.system(size: 9))
                                            Text("NFC")
                                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                        }
                                        .foregroundColor(Theme.accentBlue)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Theme.accentBlue.opacity(0.08))
                                        .cornerRadius(5)
                                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.accentBlue.opacity(0.2)))
                                    }
                                }
                                
                                Text("or type same key on both devices")
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.textMuted)
                            }
                        }
                        
                        // Join Button
                        Button(action: vm.joinMesh) {
                            HStack(spacing: 8) {
                                Text("JOIN MESH")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .tracking(1)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(joinButtonBg)
                            .foregroundColor(canJoin ? Theme.bg0 : Theme.textMuted)
                            .cornerRadius(8)
                        }
                        .disabled(!canJoin)
                    }
                    .padding(20)
                    .background(Theme.bg1)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
                    .padding(.horizontal, 18)
                    
                    // Bluetooth warning
                    if !vm.bluetoothReady {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.warning)
                            Text("Bluetooth not available. Enable it in Settings.")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Theme.warning.opacity(0.8))
                        }
                        .padding(12)
                        .background(Theme.warning.opacity(0.06))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.warning.opacity(0.15)))
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                    }
                    
                    // NFC status
                    if let status = vm.nfc.statusMessage {
                        Text(status)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Theme.accent)
                            .padding(.top, 10)
                    }
                    
                    Text("No servers. No internet. Just Bluetooth. v3.0.0")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                        .padding(.top, 16)
                    
                    Spacer().frame(height: 30)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear { focusField = .name }
    }
    
    private var canJoin: Bool {
        !vm.username.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    @ViewBuilder
    private var joinButtonBg: some View {
        if canJoin { Theme.gradient } else { Color.white.opacity(0.04) }
    }
}
