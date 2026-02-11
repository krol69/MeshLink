import SwiftUI
import PhotosUI

struct ChatView: View {
    @EnvironmentObject var vm: MeshViewModel
    @FocusState private var inputFocused: Bool
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showScrollButton = false
    @State private var isNearBottom = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            HStack {
                Text("\(vm.messages.count) message\(vm.messages.count == 1 ? "" : "s")")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
                if let session = vm.accounts.activeSession {
                    Text("• \(session.title)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.accent.opacity(0.5))
                }
                Spacer()
                if !vm.messages.isEmpty {
                    Button(action: vm.clearChat) {
                        HStack(spacing: 3) {
                            Image(systemName: "trash").font(.system(size: 9))
                            Text("Clear").font(.system(size: 9, weight: .medium, design: .monospaced))
                        }
                        .foregroundColor(Theme.text2)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.border))
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 4)
            .background(Theme.bg0.opacity(0.4))
            
            // FIX #1: ScrollViewReader wraps the ZStack so the button has access to proxy
            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        LazyVStack(spacing: 5) {
                            if vm.messages.isEmpty {
                                emptyState
                            } else {
                                ForEach(Array(vm.messages.enumerated()), id: \.element.id) { index, msg in
                                    if shouldShowDateSeparator(at: index) {
                                        dateSeparator(label: msg.dateSectionLabel)
                                    }
                                    MessageBubbleView(message: msg).id(msg.id)
                                }
                            }
                            
                            ForEach(Array(vm.typingPeers), id: \.self) { name in
                                TypingView(name: name)
                            }
                            
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: ScrollOffsetKey.self, value: geo.frame(in: .named("scroll")).maxY)
                        })
                    }
                    .coordinateSpace(name: "scroll")
                    .scrollDismissesKeyboard(.interactively)
                    .onPreferenceChange(ScrollOffsetKey.self) { maxY in
                        let threshold: CGFloat = 600
                        let shouldShow = maxY > threshold && vm.messages.count > 5
                        if shouldShow != showScrollButton {
                            withAnimation(.easeInOut(duration: 0.2)) { showScrollButton = shouldShow }
                        }
                        isNearBottom = maxY <= threshold
                    }
                    .onChange(of: vm.messages.count) { _ in
                        if isNearBottom { withAnimation { proxy.scrollTo("bottom") } }
                    }
                    .onChange(of: vm.typingPeers) { _ in
                        if isNearBottom { withAnimation { proxy.scrollTo("bottom") } }
                    }
                    .onTapGesture { inputFocused = false }
                    
                    // FIX #1: Button is now INSIDE the ZStack with proxy in scope
                    if showScrollButton {
                        Button {
                            vm.haptic.tap()
                            withAnimation { proxy.scrollTo("bottom") }
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Theme.accent)
                                .frame(width: 36, height: 36)
                                .background(Theme.bg1.opacity(0.95))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Theme.borderAccent))
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        }
                        .padding(.trailing, 12)
                        .padding(.bottom, 8)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            
            inputBar
        }
    }
    
    // MARK: - Date Separator
    private func shouldShowDateSeparator(at index: Int) -> Bool {
        guard index > 0 else { return true }
        return !Calendar.current.isDate(vm.messages[index].timestamp, inSameDayAs: vm.messages[index - 1].timestamp)
    }
    
    private func dateSeparator(label: String) -> some View {
        HStack {
            Rectangle().fill(Theme.border).frame(height: 1)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.textMuted)
                .padding(.horizontal, 8)
            Rectangle().fill(Theme.border).frame(height: 1)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 30)
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 36))
                .foregroundStyle(Theme.gradient)
            Text("No messages yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.text2)
            Text("Connect to a peer in the Peers tab,\nthen start chatting.")
                .font(.system(size: 11))
                .foregroundColor(Theme.textMuted)
                .multilineTextAlignment(.center)
            
            if !vm.demoLoaded {
                Button(action: vm.loadDemo) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill").font(.system(size: 9))
                        Text("Load Demo").font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    .background(Theme.surface).cornerRadius(7)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.borderAccent))
                }
            }
        }
    }
    
    // MARK: - Input Bar
    private var inputBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.text2)
                        .frame(width: 34, height: 34)
                        .background(Theme.surface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                }
                .onChange(of: selectedPhoto) { newItem in
                    guard let item = newItem else { return }
                    item.loadTransferable(type: Data.self) { result in
                        if case .success(let data) = result, let data = data, let img = UIImage(data: data) {
                            DispatchQueue.main.async { vm.sendImage(img) }
                        }
                    }
                    selectedPhoto = nil
                }
                
                TextField(
                    vm.ble.connectedCount > 0 ? "Message..." : "Connect peers first...",
                    text: $vm.inputText
                )
                .font(.system(size: 13))
                .foregroundColor(Theme.text1)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10).padding(.vertical, 9)
                .background(Theme.surface).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(inputFocused ? Theme.borderAccent : Theme.border))
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit { vm.sendMessage() }
                .onChange(of: vm.inputText) { _ in vm.onInputChanged() }
                
                Button(action: vm.sendMessage) { sendButtonContent }
                    .disabled(vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: vm.isEncryptionActive ? "lock.fill" : "lock.open")
                        .font(.system(size: 8))
                        .foregroundColor(vm.isEncryptionActive ? Theme.accent : Theme.danger)
                    Text(vm.isEncryptionActive ? "AES-256-GCM" : (vm.encryptionKey.isEmpty ? "No encryption" : "Encryption off"))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(vm.isEncryptionActive ? Theme.accent.opacity(0.4) : Theme.danger.opacity(0.4))
                }
                Spacer()
                Text("\(vm.ble.connectedCount) peer\(vm.ble.connectedCount == 1 ? "" : "s") • Mesh relay on")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
            }
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 8)
        .background(Theme.bg1.opacity(0.95))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.border), alignment: .top)
    }
    
    @ViewBuilder
    private var sendButtonContent: some View {
        let isEmpty = vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty
        Image(systemName: "arrow.up")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(isEmpty ? Theme.textMuted : Theme.bg0)
            .frame(width: 38, height: 38)
            .background(Group { if isEmpty { Theme.surface } else { Theme.gradient } })
            .cornerRadius(10)
            .overlay(Group { if isEmpty { RoundedRectangle(cornerRadius: 10).stroke(Theme.border) } })
    }
}

// MARK: - Scroll offset preference key
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Message Bubble
struct MessageBubbleView: View {
    let message: ChatMessage
    @State private var showFullImage = false
    
    private var ownCorners: UIRectCorner { [.topLeft, .topRight, .bottomLeft] }
    private var otherCorners: UIRectCorner { [.topLeft, .topRight, .bottomRight] }
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if !message.isOwn {
                Text(String(message.sender.prefix(1)).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.bg0)
                    .frame(width: 26, height: 26)
                    .background(LinearGradient(
                        colors: [message.sender.meshColor, (message.sender + "x").meshColor],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .cornerRadius(7)
            }
            
            if message.isOwn { Spacer(minLength: 44) }
            
            VStack(alignment: message.isOwn ? .trailing : .leading, spacing: 2) {
                if !message.isOwn {
                    Text(message.sender)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(message.sender.meshColor)
                }
                
                if message.hasImage, let img = message.uiImage {
                    Button { showFullImage = true } label: {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .frame(maxWidth: 180, maxHeight: 180)
                            .cornerRadius(8)
                    }
                    .sheet(isPresented: $showFullImage) {
                        ZStack {
                            Color.black.ignoresSafeArea()
                            Image(uiImage: img).resizable().scaledToFit().padding()
                        }
                        .onTapGesture { showFullImage = false }
                    }
                }
                
                if !message.text.isEmpty && message.text != "📷 Image" {
                    Text(message.text)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.text1)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                HStack(spacing: 4) {
                    Text(message.timeString)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                    if message.encrypted {
                        Image(systemName: "lock.fill").font(.system(size: 7)).foregroundColor(Theme.accent)
                    }
                    Text(message.method)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(Theme.accent.opacity(0.3))
                    if message.isOwn {
                        Image(systemName: message.delivered ? "checkmark.circle.fill" : "checkmark")
                            .font(.system(size: 8))
                            .foregroundColor(message.delivered ? Theme.accent : Theme.textMuted)
                    }
                }
            }
            .padding(10)
            .background(bubbleBg)
            .cornerRadius(11, corners: message.isOwn ? ownCorners : otherCorners)
            .overlay(
                RoundedCorner(radius: 11, corners: message.isOwn ? ownCorners : otherCorners)
                    .stroke(message.isOwn ? Theme.borderAccent : Theme.border)
            )
            
            if !message.isOwn { Spacer(minLength: 44) }
        }
        .transition(.asymmetric(insertion: .scale(scale: 0.95).combined(with: .opacity), removal: .opacity))
    }
    
    @ViewBuilder
    private var bubbleBg: some View {
        if message.isOwn {
            LinearGradient(colors: [Theme.accent.opacity(0.12), Theme.accentBlue.opacity(0.08)],
                          startPoint: .topLeading, endPoint: .bottomTrailing)
        } else { Theme.surface }
    }
}

// MARK: - Typing Indicator
struct TypingView: View {
    let name: String
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 6) {
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.bg0)
                .frame(width: 26, height: 26)
                .background(name.meshColor).cornerRadius(7)
            
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Theme.text2).frame(width: 5, height: 5)
                        .offset(y: animating ? -3 : 0)
                        .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: animating)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.surface).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))
            Spacer()
        }
        .onAppear { animating = true }
    }
}

// MARK: - Corner Helper
struct RoundedCorner: Shape {
    var radius: CGFloat; var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
