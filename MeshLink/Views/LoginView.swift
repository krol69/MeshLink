import SwiftUI

// MARK: - Login / Account Selection
struct LoginView: View {
    @EnvironmentObject var vm: MeshViewModel
    @ObservedObject var accounts = AccountService.shared
    @State private var mode: LoginMode = .select
    @State private var displayName = ""
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var selectedEmoji = "🔒"
    @State private var error = ""
    @State private var selectedAccountId: String?
    @FocusState private var focusField: LoginField?
    
    enum LoginMode { case select, create, login }
    enum LoginField { case name, pin, confirm, loginPin }
    
    private let emojis = ["🔒", "⚡", "🛡️", "🌐", "📡", "🔗", "💬", "🚀", "🦊", "🐺", "🎯", "🔥"]
    
    var body: some View {
        ZStack {
            Theme.bg0.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 40)
                    
                    // Logo
                    VStack(spacing: 10) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.gradient)
                        Text("MESHLINK")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(Theme.gradientFull)
                        Text("SECURE MESH MESSAGING")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                            .tracking(2)
                    }
                    .padding(.bottom, 30)
                    
                    switch mode {
                    case .select: accountSelectionView
                    case .create: createAccountView
                    case .login: loginPinView
                    }
                    
                    // Skip login
                    Button {
                        vm.haptic.tap()
                        accounts.currentAccount = Account(displayName: "Guest", pin: "0000", emoji: "👤")
                    } label: {
                        Text("Continue as Guest")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                            .padding(.top, 16)
                    }
                    
                    Spacer().frame(height: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    // MARK: - Account Selection
    private var accountSelectionView: some View {
        VStack(spacing: 14) {
            if accounts.accounts.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.accent.opacity(0.4))
                    Text("No accounts yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.text2)
                    Text("Create an account to manage your chats,\ntrack sessions, and keep your history.")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 8)
            } else {
                Text("SELECT ACCOUNT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.accent)
                    .tracking(1.5)
                
                ForEach(accounts.accounts, id: \.id) { account in
                    accountRow(account)
                }
            }
            
            Button {
                vm.haptic.tap(); mode = .create
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 14))
                    Text("CREATE ACCOUNT")
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(0.5)
                }
                .foregroundColor(Theme.bg0)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.gradient)
                .cornerRadius(10)
            }
        }
        .padding(20)
        .background(Theme.bg1)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
        .padding(.horizontal, 18)
    }
    
    private func accountRow(_ account: Account) -> some View {
        Button {
            vm.haptic.tap(); selectedAccountId = account.id; pin = ""; mode = .login
        } label: {
            HStack(spacing: 12) {
                Text(account.avatarEmoji)
                    .font(.system(size: 24))
                    .frame(width: 44, height: 44)
                    .background(Theme.accent.opacity(0.08))
                    .cornerRadius(10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.text1)
                    Text("Last login: \(account.lastLoginAt, formatter: Self.dateFmt)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12)).foregroundColor(Theme.textMuted)
            }
            .padding(12)
            .background(Theme.surface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))
        }
        .contextMenu {
            Button(role: .destructive) { accounts.deleteAccount(account.id) } label: {
                Label("Delete Account", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Create Account
    private var createAccountView: some View {
        VStack(spacing: 16) {
            HStack {
                Button { mode = .select } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 10))
                        Text("Back").font(.system(size: 11, design: .monospaced))
                    }.foregroundColor(Theme.accent)
                }
                Spacer()
                Text("NEW ACCOUNT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.accent).tracking(1.5)
                Spacer()
                Color.clear.frame(width: 44)
            }
            
            // Avatar picker
            VStack(spacing: 6) {
                Text(selectedEmoji)
                    .font(.system(size: 44))
                    .frame(width: 70, height: 70)
                    .background(Theme.accent.opacity(0.08))
                    .cornerRadius(16)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(emojis, id: \.self) { emoji in
                            Button { selectedEmoji = emoji; vm.haptic.selection() } label: {
                                Text(emoji).font(.system(size: 22))
                                    .frame(width: 36, height: 36)
                                    .background(selectedEmoji == emoji ? Theme.accent.opacity(0.15) : Theme.surface)
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedEmoji == emoji ? Theme.borderAccent : Theme.border))
                            }
                        }
                    }
                }
            }
            
            // Display Name
            VStack(alignment: .leading, spacing: 4) {
                Text("DISPLAY NAME")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.accent).tracking(1.5)
                TextField("Your name", text: $displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.text1)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Theme.bg0).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                    .focused($focusField, equals: .name)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { focusField = .pin }
            }
            
            // PIN fields
            VStack(alignment: .leading, spacing: 4) {
                Text("PIN (4+ digits)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.accent).tracking(1.5)
                SecureField("Enter PIN", text: $pin)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Theme.text1)
                    .textFieldStyle(.plain)
                    .keyboardType(.numberPad)
                    .padding(12)
                    .background(Theme.bg0).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                    .focused($focusField, equals: .pin)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("CONFIRM PIN")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.accent).tracking(1.5)
                SecureField("Confirm PIN", text: $confirmPin)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Theme.text1)
                    .textFieldStyle(.plain)
                    .keyboardType(.numberPad)
                    .padding(12)
                    .background(Theme.bg0).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                    .focused($focusField, equals: .confirm)
            }
            
            if !error.isEmpty {
                Text(error)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.danger)
            }
            
            Button(action: createAccount) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 12))
                    Text("CREATE ACCOUNT")
                        .font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(0.5)
                }
                .foregroundColor(canCreate ? Theme.bg0 : Theme.textMuted)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(canCreate ? AnyView(Theme.gradient) : AnyView(Color.white.opacity(0.04)))
                .cornerRadius(10)
            }
            .disabled(!canCreate)
        }
        .padding(20)
        .background(Theme.bg1).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
        .padding(.horizontal, 18)
        .onAppear { focusField = .name }
    }
    
    private var canCreate: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty && pin.count >= 4 && pin == confirmPin
    }
    
    private func createAccount() {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { error = "Name required"; return }
        guard pin.count >= 4 else { error = "PIN must be 4+ digits"; return }
        guard pin == confirmPin else { error = "PINs don't match"; return }
        let _ = accounts.createAccount(name: name, pin: pin, emoji: selectedEmoji)
        vm.username = name; vm.haptic.connect(); error = ""
    }
    
    // MARK: - Login PIN Entry
    private var loginPinView: some View {
        VStack(spacing: 16) {
            HStack {
                Button { mode = .select; pin = "" } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 10))
                        Text("Back").font(.system(size: 11, design: .monospaced))
                    }.foregroundColor(Theme.accent)
                }
                Spacer()
                Text("ENTER PIN")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.accent).tracking(1.5)
                Spacer()
                Color.clear.frame(width: 44)
            }
            
            if let account = accounts.accounts.first(where: { $0.id == selectedAccountId }) {
                Text(account.avatarEmoji)
                    .font(.system(size: 44))
                    .frame(width: 70, height: 70)
                    .background(Theme.accent.opacity(0.08))
                    .cornerRadius(16)
                Text(account.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.text1)
            }
            
            SecureField("Enter PIN", text: $pin)
                .font(.system(size: 18, design: .monospaced))
                .foregroundColor(Theme.text1)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .keyboardType(.numberPad)
                .padding(14)
                .background(Theme.bg0).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))
                .focused($focusField, equals: .loginPin)
            
            if !error.isEmpty {
                Text(error)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.danger)
            }
            
            Button {
                guard let id = selectedAccountId else { return }
                if accounts.login(accountId: id, pin: pin) {
                    if let acct = accounts.currentAccount { vm.username = acct.displayName }
                    vm.haptic.connect(); error = ""
                } else {
                    error = "Wrong PIN"; vm.haptic.error(); pin = ""
                }
            } label: {
                Text("UNLOCK")
                    .font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(1)
                    .foregroundColor(pin.count >= 4 ? Theme.bg0 : Theme.textMuted)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(pin.count >= 4 ? AnyView(Theme.gradient) : AnyView(Color.white.opacity(0.04)))
                    .cornerRadius(10)
            }
            .disabled(pin.count < 4)
        }
        .padding(20)
        .background(Theme.bg1).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
        .padding(.horizontal, 18)
        .onAppear { focusField = .loginPin }
    }
    
    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, h:mm a"; return f
    }()
}
