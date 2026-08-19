import SwiftUI
import WebKit
import AIMeterCore

struct AuthenticationSettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @State private var showLogin = false
    @State private var reauthAccountID: UUID?
    @State private var pasteToken = ""
    @State private var pasteCloudKey = ""
    @State private var statusMessage: String?
    @State private var authAlert: AuthNotice?
    @State private var editingLabelID: UUID?
    @State private var draftLabel = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SettingsPanel(
                    title: "Active session",
                    systemImage: "person.badge.shield.checkmark",
                    subtitle: store.isAuthenticated
                        ? "Tokens stay in Keychain. Add another account without signing this one out."
                        : "Sign in once; tokens stay in Keychain on this Mac.",
                    compact: true
                ) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(store.isAuthenticated ? Color.green : Color.orange.opacity(0.85))
                            .frame(width: 8, height: 8)
                        Text(store.isAuthenticated ? "Authenticated" : "Not authenticated")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(store.isAuthenticated ? Color.green : Color.secondary)
                        if let email = store.accountEmail {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if let statusMessage {
                            Text(statusMessage)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                        spacing: 8
                    ) {
                        authButton(
                            store.connections.isEmpty ? "Sign in with Cursor" : "Add another account with Cursor",
                            systemImage: "globe"
                        ) {
                            reauthAccountID = nil
                            showLogin = true
                        }
                        authButton("Connect from Cursor IDE", systemImage: "laptopcomputer") {
                            Task { await connectFromCursorIDE() }
                        }
                        authButton("Add Claude Code", systemImage: "brain") {
                            Task { await connectLocal(.claude) }
                        }
                        authButton("Add Codex", systemImage: "chevron.left.forwardslash.chevron.right") {
                            Task { await connectLocal(.codex) }
                        }
                        authButton("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            store.signOut()
                            statusMessage = "Signed out."
                        }
                        .disabled(store.connections.isEmpty)
                    }

                    Text("Cursor can sign in in-app. Claude and Codex sign in from Terminal (`claude` / `codex login`), then Add or Reconnect. A Keychain prompt only appears if this Mac already has that app’s item and AI Meter is not yet allowed to read it. Reconnect is on each account below.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SettingsPanel(
                    title: "Paste token",
                    systemImage: "key",
                    subtitle: "Escape hatch if WebView or IDE connect fails. Saves as a new account unless the email already exists.",
                    compact: true
                ) {
                    HStack(spacing: 8) {
                        SecureField("WorkosCursorSessionToken or JWT", text: $pasteToken)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            Task {
                                do {
                                    try await store.saveSessionToken(pasteToken)
                                    pasteToken = ""
                                    statusMessage = "Token saved."
                                } catch {
                                    statusMessage = "Token rejected: \(error.localizedDescription)"
                                }
                            }
                        } label: {
                            Label("Save", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(pasteToken.isEmpty)
                    }
                }

                SettingsPanel(
                    title: "Accounts",
                    systemImage: "person.2",
                    subtitle: store.connections.isEmpty
                        ? "No saved sessions yet."
                        : "\(store.connections.count) saved. Active drives the widget and the default menu bar.",
                    compact: true
                ) {
                    if store.connections.isEmpty {
                        Text("Add Cursor, Claude Code, or Codex from the buttons above.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(store.accounts) { account in
                                accountRow(account)
                            }
                        }
                        HStack {
                            Spacer()
                            Button("Sign out all", role: .destructive) {
                                store.signOutAll()
                                statusMessage = "Signed out all accounts."
                            }
                            .controlSize(.small)
                        }
                    }
                }

                if store.activeAccount?.connection.provider == .cursor {
                SettingsPanel(
                    title: "Cloud Agents API key",
                    systemImage: "cloud",
                    subtitle: "Optional. Lists background cloud agents (bc-*). Create a user key at cursor.com/dashboard/api — this is not the session cookie.",
                    compact: true
                ) {
                    if store.activeAccount?.hasCloudAPIKey == true {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text(store.activeAccount?.cloudAPIKeyName ?? "Key saved")
                                .font(.caption.weight(.semibold))
                            if let email = store.activeAccount?.cloudAPIKeyEmail {
                                Text("· \(email)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Button("Remove", role: .destructive) {
                                store.removeCloudAPIKey()
                                statusMessage = "Cloud Agents key removed."
                            }
                            .controlSize(.small)
                        }
                        if let error = store.activeAccount?.cloudAgentsError {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        } else if let count = store.activeAccount?.cloudAgents.count {
                            Text(count == 0 ? "No active cloud agents." : "\(count) cloud agent\(count == 1 ? "" : "s").")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(spacing: 8) {
                            SecureField("cursor_… or crsr_… API key", text: $pasteCloudKey)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                Task {
                                    do {
                                        try await store.saveCloudAPIKey(pasteCloudKey)
                                        pasteCloudKey = ""
                                        let name = store.activeAccount?.cloudAPIKeyName ?? "key"
                                        statusMessage = "Cloud Agents key saved (\(name))."
                                    } catch CloudAgentsError.unauthorized {
                                        statusMessage = "Cloud Agents key rejected."
                                    } catch {
                                        statusMessage = "Key failed: \(error.localizedDescription)"
                                    }
                                }
                            } label: {
                                Label("Save", systemImage: "checkmark.circle")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(pasteCloudKey.isEmpty || !store.isAuthenticated)
                        }
                        if !store.isAuthenticated {
                            Text("Sign in with a Cursor session first, then paste the API key for that account.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                }

                SettingsPanel(
                    title: "Team / Enterprise",
                    systemImage: "building.2",
                    subtitle: "Not available yet.",
                    compact: true
                ) {
                    Text(TeamAdminAPIConnectorStub.statusMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert(item: $authAlert) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showLogin) {
            VStack(spacing: 0) {
                HStack {
                    Text(
                        reauthAccountID != nil
                            ? "Re-authenticate"
                            : (store.connections.isEmpty ? "Sign in to Cursor" : "Add another account")
                    )
                        .font(.headline)
                    Spacer()
                    Button("Cancel") { showLogin = false }
                        .keyboardShortcut(.cancelAction)
                }
                .padding()
                Divider()
                LoginWebView { token in
                    showLogin = false
                    let replacing = reauthAccountID
                    reauthAccountID = nil
                    Task {
                        do {
                            try await store.saveSessionToken(token, replacing: replacing)
                            presentNotice(
                                title: replacing == nil ? "Signed in" : "Session updated",
                                message: replacing == nil ? "Signed in." : "Session updated."
                            )
                        } catch {
                            presentNotice(
                                title: "Login failed",
                                message: error.localizedDescription
                            )
                        }
                    }
                } onCancel: {
                    showLogin = false
                }
            }
            .frame(width: 720, height: 640)
        }
    }

    private func accountRow(_ account: AccountRuntime) -> some View {
        let isActive = account.id == store.activeAccountID
        return HStack(spacing: 10) {
            Circle()
                .fill(account.isAuthenticated ? Color.green : Color.orange.opacity(0.85))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                if editingLabelID == account.id {
                    TextField("Label", text: $draftLabel)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 180)
                        .onSubmit {
                            store.renameAccount(id: account.id, label: draftLabel)
                            editingLabelID = nil
                        }
                } else {
                    Text(account.connection.displayLabel)
                        .font(.caption.weight(.semibold))
                }
                Text(account.connection.provider.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let email = account.connection.email {
                    Text(email)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                if let error = account.lastError, !account.isAuthenticated {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if isActive {
                Text("Active")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    .foregroundStyle(Color.accentColor)
            }
            Spacer(minLength: 0)
            Button("Reconnect") {
                Task { await reconnect(account) }
            }
            .controlSize(.small)
            if !isActive {
                Button("Set active") {
                    store.setActive(id: account.id)
                }
                .controlSize(.small)
            }
            Button("Rename") {
                editingLabelID = account.id
                draftLabel = account.connection.label.isEmpty
                    ? account.connection.displayLabel
                    : account.connection.label
            }
            .controlSize(.small)
            Button("Sign out", role: .destructive) {
                store.signOut(id: account.id)
                statusMessage = "Signed out \(account.connection.displayLabel)."
            }
            .controlSize(.small)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(isActive ? 0.06 : 0.03))
        )
    }

    private func connectFromCursorIDE() async {
        await store.tryAutoConnect()
        if store.isAuthenticated {
            await store.refresh()
            let email = store.accountEmail ?? "account"
            let source = store.lastLocalConnectSource ?? "local Cursor"
            presentNotice(title: "Connected", message: "Connected \(email) via \(source).")
        } else {
            presentNotice(
                title: "Couldn’t connect",
                message: store.lastError ?? "No local Cursor session found."
            )
        }
    }

    private func connectLocal(_ provider: ProviderKind, replacing: UUID? = nil) async {
        do {
            let result: LocalConnectResult
            switch provider {
            case .claude:
                result = try await store.connectClaude(replacing: replacing)
            case .codex:
                result = try await store.connectCodex(replacing: replacing)
            case .cursor:
                return
            }
            presentNotice(title: result.refreshedExisting ? "Refreshed" : "Connected", message: result.successMessage)
        } catch {
            presentNotice(
                title: "Couldn’t connect \(provider.displayName)",
                message: store.lastError ?? error.localizedDescription
            )
        }
    }

    private func reconnect(_ account: AccountRuntime) async {
        switch account.connection.provider {
        case .cursor:
            reauthAccountID = account.id
            showLogin = true
        case .claude:
            await connectLocal(.claude, replacing: account.id)
        case .codex:
            await connectLocal(.codex, replacing: account.id)
        }
    }

    private func presentNotice(title: String, message: String) {
        statusMessage = message
        authAlert = AuthNotice(title: title, message: message)
    }

    private func authButton(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
}

struct AuthNotice: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

struct LoginWebView: NSViewRepresentable {
    var onToken: (String) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: URL(string: "https://cursor.com/dashboard")!))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onToken: onToken)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onToken: (String) -> Void
        init(onToken: @escaping (String) -> Void) { self.onToken = onToken }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let store = webView.configuration.websiteDataStore.httpCookieStore
            store.getAllCookies { cookies in
                guard let cookie = cookies.first(where: { $0.name == "WorkosCursorSessionToken" }) else { return }
                DispatchQueue.main.async {
                    self.onToken(cookie.value)
                }
            }
        }
    }
}
