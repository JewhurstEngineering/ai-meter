import SwiftUI
import WebKit
import CursorUsageCore

struct AuthenticationSettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @State private var showLogin = false
    @State private var pasteToken = ""
    @State private var statusMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SettingsPanel(
                    title: "Session",
                    systemImage: "person.badge.shield.checkmark",
                    subtitle: store.isAuthenticated
                        ? "Connected — re-auth if usage stops updating."
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
                        authButton("Sign in with Cursor", systemImage: "globe") {
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
                            showLogin = true
                        }
                        .disabled(!store.isAuthenticated)
                        authButton("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            store.signOut()
                            statusMessage = "Signed out."
                        }
                        .disabled(!store.isAuthenticated)
                    }

                    Text("Prefers Cursor IDE (state.vscdb). Agent keychain can be a different account.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                SettingsPanel(
                    title: "Paste token",
                    systemImage: "key",
                    subtitle: "Escape hatch if WebView or IDE connect fails.",
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

                HStack(alignment: .top, spacing: 10) {
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    SettingsPanel(
                        title: "Multiple accounts",
                        systemImage: "person.2",
                        subtitle: "One session at a time.",
                        compact: true
                    ) {
                        Text("Sign out and re-auth to switch accounts. Side-by-side multi-account is planned.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .padding(12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showLogin) {
            VStack(spacing: 0) {
                HStack {
                    Text("Sign in to Cursor")
                        .font(.headline)
                    Spacer()
                    Button("Cancel") { showLogin = false }
                        .keyboardShortcut(.cancelAction)
                }
                .padding()
                Divider()
                LoginWebView { token in
                    showLogin = false
                    Task {
                        do {
                            try await store.saveSessionToken(token)
                            statusMessage = "Signed in."
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
