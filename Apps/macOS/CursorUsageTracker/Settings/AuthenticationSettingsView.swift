import SwiftUI
import WebKit
import CursorUsageCore

struct AuthenticationSettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @State private var showLogin = false
    @State private var reauthAccountID: UUID?
    @State private var pasteToken = ""
    @State private var statusMessage: String?
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
                            Task {
                                await store.tryAutoConnect()
                                if store.isAuthenticated {
                                    await store.refresh()
                                    let email = store.accountEmail ?? "account"
                                    let source = store.lastLocalConnectSource ?? "local Cursor"
                                    statusMessage = "Connected \(email) via \(source)."
                                } else {
                                    statusMessage = store.lastError ?? "No local Cursor session found."
                                }
                            }
                        }
                        authButton("Re-authenticate", systemImage: "arrow.triangle.2.circlepath") {
                            reauthAccountID = store.activeAccountID
                            showLogin = true
                        }
                        .disabled(!store.isAuthenticated)
                        authButton("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            store.signOut()
                            statusMessage = "Signed out."
                        }
                        .disabled(!store.isAuthenticated)
                    }

                    Text("Prefers Cursor IDE (state.vscdb). Agent keychain can be a different account. Sign in again to add a second session.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
                        Text("Add an account with Sign in, Connect from Cursor IDE, or paste a token.")
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
                            statusMessage = replacing == nil ? "Signed in." : "Session updated."
                        } catch {
                            statusMessage = "Login failed: \(error.localizedDescription)"
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
                if let email = account.connection.email {
                    Text(email)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
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
