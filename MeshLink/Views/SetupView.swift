import SwiftUI

struct SetupView: View {
    @EnvironmentObject var vm: MeshViewModel
    @FocusState private var focusField: Field?
    
    enum Field { case name, key }
    
    var body: some View {
        ZStack {
            Theme.bg0.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo
                VStack(spacing: 12) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.gradient)
                        .symbolEffect(.pulse)
                    
                    Text("MESHLINK")
                        .font(.system(size: 38, weight: .black, design: .default))
                        .foregroundStyle(Theme.gradientFull)
                    
                    Text("AES-256 ENCRYPTED P2P MESSAGING")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                        .tracking(2)
                }
                .padding(.bottom, 36)
                
                // Form Card
                VStack(spacing: 20) {
                    // Node Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NODE NAME")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.accent)
                            .tracking(1.5)
                        
                        TextField("Enter your display name", text: $vm.username)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Theme.text1)
                            .padding(14)
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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.accent)
                            Text("ENCRYPTION KEY")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(Theme.accent)
                                .tracking(1.5)
                        }
                        
                        HStack(spacing: 8) {
                            Group {
                                if vm.showKey {
                                    TextField("Shared secret", text: $vm.encryptionKey)
                                        .font(.system(size: 14, design: .monospaced))
                                } else {
                                    SecureField("Shared secret", text: $vm.encryptionKey)
                                        .font(.system(size: 14, design: .monospaced))
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
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.text2)
                            }
                        }
                        .padding(14)
                        .background(Theme.bg0)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                    }
                    
                    // Join Button
                    Button(action: vm.joinMesh) {
                        HStack(spacing: 10) {
                            Text("JOIN MESH")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .tracking(1)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            vm.username.trimmingCharacters(in: .whitespaces).isEmpty
                                ? AnyShapeStyle(Color.white.opacity(0.04))
                                : AnyShapeStyle(Theme.gradient)
                        )
                        .foregroundColor(
                            vm.username.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Theme.textMuted
                                : Theme.bg0
                        )
                        .cornerRadius(8)
                    }
                    .disabled(vm.username.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(24)
                .background(Theme.bg1)
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border))
                .padding(.horizontal, 20)
                
                // Bluetooth warning
                if !vm.bluetoothReady {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.warning)
                        Text("Bluetooth not available. Enable it in Settings to connect to peers.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Theme.warning.opacity(0.8))
                    }
                    .padding(14)
                    .background(Theme.warning.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.warning.opacity(0.15)))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                
                Text("No servers. No internet. Just Bluetooth. v2.0.0")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
                    .padding(.top, 20)
                
                Spacer()
            }
        }
        .onAppear { focusField = .name }
    }
}
