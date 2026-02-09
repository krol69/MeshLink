import SwiftUI

struct ChatView: View {
    @EnvironmentObject var vm: MeshViewModel
    @FocusState private var inputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat header bar
            HStack {
                Text("\(vm.messages.count) message\(vm.messages.count == 1 ? "" : "s")")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
                
                Spacer()
                
                if !vm.messages.isEmpty {
                    Button(action: vm.clearChat) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash").font(.system(size: 10))
                            Text("Clear").font(.system(size: 10, weight: .medium, design: .monospaced))
                        }
                        .foregroundColor(Theme.text2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .background(Theme.bg0.opacity(0.4))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.02)), alignment: .bottom)
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        if vm.messages.isEmpty {
                            emptyState
                        } else {
                            ForEach(vm.messages) { msg in
                                MessageBubbleView(message: msg)
                                    .id(msg.id)
                            }
                        }
                        
                        // Typing indicators
                        ForEach(Array(vm.typingPeers), id: \.self) { name in
                            TypingView(name: name)
                        }
                        
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
                .onChange(of: vm.messages.count) { _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
                .onChange(of: vm.typingPeers) { _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
            }
            
            // Input bar
            inputBar
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundStyle(Theme.gradient)
            
            Text("No messages yet")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.text2)
            
            Text("Connect to a peer in the Peers tab, or load a demo to see MeshLink in action.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            
            if !vm.demoLoaded {
                Button(action: vm.loadDemo) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill").font(.system(size: 10))
                        Text("Load Demo")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Theme.surface)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.borderAccent))
                }
            }
        }
    }
    
    // MARK: - Input Bar
    private var inputBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                TextField(
                    vm.ble.connectedCount > 0 ? "Type a message..." : "Type a message (connect peers first)...",
                    text: $vm.inputText
                )
                .font(.system(size: 14))
                .foregroundColor(Theme.text1)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Theme.surface)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(inputFocused ? Theme.borderAccent : Theme.border))
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit { vm.sendMessage() }
                .onChange(of: vm.inputText) { _ in vm.onInputChanged() }
                
                sendButton
            }
            
            // Status bar
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: vm.encryptionEnabled ? "lock.fill" : "lock.open")
                        .font(.system(size: 9))
                        .foregroundColor(vm.encryptionEnabled ? Theme.accent : Theme.danger)
                    Text(vm.encryptionEnabled ? "AES-256-GCM" : "Unencrypted")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(vm.encryptionEnabled ? Theme.accent.opacity(0.5) : Theme.danger.opacity(0.5))
                }
                
                Spacer()
                
                Text("\(vm.ble.connectedCount) peer\(vm.ble.connectedCount == 1 ? "" : "s") online")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.3))
        .background(Theme.bg0.opacity(0.88))
    }
    
    private var sendButtonReady: Bool {
        !vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    @ViewBuilder
    private var sendButton: some View {
        if sendButtonReady {
            Button(action: vm.sendMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.bg0)
                    .frame(width: 44, height: 44)
                    .background(Theme.gradient)
                    .cornerRadius(12)
            }
        } else {
            Button(action: {}) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.textMuted)
                    .frame(width: 44, height: 44)
                    .background(Theme.surface)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
            }
            .disabled(true)
        }
    }
}

// MARK: - Message Bubble
struct MessageBubbleView: View {
    let message: ChatMessage
    
    private var bubbleCorners: UIRectCorner {
        message.isOwn
            ? [.topLeft, .topRight, .bottomLeft]
            : [.topLeft, .topRight, .bottomRight]
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !message.isOwn {
                // Avatar
                Text(String(message.sender.prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.bg0)
                    .frame(width: 30, height: 30)
                    .background(
                        LinearGradient(
                            colors: [message.sender.meshColor, (message.sender + "x").meshColor],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(8)
            }
            
            if message.isOwn { Spacer(minLength: 50) }
            
            VStack(alignment: message.isOwn ? .trailing : .leading, spacing: 3) {
                if !message.isOwn {
                    Text(message.sender)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(message.sender.meshColor)
                }
                
                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.text1)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 5) {
                    Text(message.timeString)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                    
                    if message.encrypted {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Theme.accent)
                    }
                    
                    Text(message.method)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Theme.accent.opacity(0.35))
                    
                    if message.isOwn {
                        Image(systemName: message.delivered ? "checkmark.circle.fill" : "checkmark")
                            .font(.system(size: 9))
                            .foregroundColor(message.delivered ? Theme.accent : Theme.textMuted)
                    }
                }
            }
            .padding(12)
            .background(bubbleBackground)
            .clipShape(RoundedCorner(radius: 12, corners: bubbleCorners))
            .overlay(
                RoundedCorner(radius: 12, corners: bubbleCorners)
                    .stroke(message.isOwn ? Theme.borderAccent : Theme.border)
            )
            
            if !message.isOwn { Spacer(minLength: 50) }
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .opacity
        ))
    }
    
    @ViewBuilder
    private var bubbleBackground: some View {
        if message.isOwn {
            LinearGradient(
                colors: [Theme.accent.opacity(0.12), Theme.accentBlue.opacity(0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            Color.white.opacity(0.03)
        }
    }
}

// MARK: - Typing Indicator
struct TypingView: View {
    let name: String
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 8) {
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.bg0)
                .frame(width: 30, height: 30)
                .background(name.meshColor)
                .cornerRadius(8)
            
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Theme.text2)
                        .frame(width: 6, height: 6)
                        .offset(y: animating ? -4 : 0)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.surface)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
            
            Spacer()
        }
        .onAppear { animating = true }
    }
}

// MARK: - Rounded Corner Helper
struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
