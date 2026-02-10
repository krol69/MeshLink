import SwiftUI

struct LogsView: View {
    @EnvironmentObject var vm: MeshViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(vm.logs.count) events")
                    .font(.system(size: 9, design: .monospaced)).foregroundColor(Theme.textMuted)
                Spacer()
                Button {
                    vm.logs.removeAll()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "trash").font(.system(size: 9))
                        Text("Clear").font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(Theme.text2)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.border))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 4)
            .background(Theme.bg0.opacity(0.4))
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(vm.logs) { log in
                            HStack(alignment: .top, spacing: 6) {
                                Text(log.timeString)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(Theme.textMuted)
                                    .frame(width: 55, alignment: .leading)
                                
                                Circle()
                                    .fill(logColor(log.level))
                                    .frame(width: 4, height: 4)
                                    .padding(.top, 4)
                                
                                Text(log.text)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(logColor(log.level).opacity(0.8))
                                    .lineSpacing(2)
                            }
                            .id(log.id)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .padding(.bottom, 30)
                }
                .onChange(of: vm.logs.count) { _ in
                    if let last = vm.logs.last {
                        withAnimation { proxy.scrollTo(last.id) }
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
