import SwiftUI

struct LogsView: View {
    @EnvironmentObject var vm: MeshViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SYSTEM LOGS (\(vm.logs.count))")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
                    .tracking(1.5)
                
                Spacer()
                
                if !vm.logs.isEmpty {
                    Button(action: vm.clearLogs) {
                        Text("Clear")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.text2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            
            if vm.logs.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "terminal")
                        .font(.system(size: 28))
                        .foregroundColor(Color.white.opacity(0.1))
                    Text("System events will appear here.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(vm.logs) { log in
                                HStack(alignment: .top, spacing: 12) {
                                    Text(log.timeString)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(Theme.textMuted)
                                        .frame(width: 60, alignment: .leading)
                                    
                                    Circle()
                                        .fill(logColor(log.level))
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 5)
                                    
                                    Text(log.text)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(logColor(log.level))
                                        .lineSpacing(2)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 5)
                                .id(log.id)
                                
                                Divider()
                                    .background(Color.white.opacity(0.02))
                            }
                        }
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                        .padding(.horizontal, 18)
                        .padding(.bottom, 20)
                    }
                    .onChange(of: vm.logs.count) { _ in
                        if let last = vm.logs.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
        }
    }
    
    private func logColor(_ level: LogEntry.LogLevel) -> Color {
        switch level {
        case .info: return Theme.text2
        case .success: return Theme.accent
        case .warning: return Theme.warning
        case .error: return Theme.danger
        case .data: return Theme.accentBlue
        }
    }
}
