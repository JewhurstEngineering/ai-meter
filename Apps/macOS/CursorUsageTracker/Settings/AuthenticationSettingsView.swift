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
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanel(
                    title: "Session",
                    systemImage: "person.badge.shield.checkmark",
                    subtitle: store.isAuthenticated
                        ? "Connected. Re-auth if usage stops updating."
                        : "Sign in once — tokens stay in Keychain on this Mac."
                ) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(store.isAuthenticated ? Color.green : Color.orange.opacity(0.8))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.isAuthenticated ? "Authenticated" : "Not authenticated")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(store.isAuthenticated ? Color.green : Color.secondary)
                            if let email = store.accountEmail {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            if let statusMessage {
                                Text(statusMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        authButton("Sign in with Cursor", systemImage: "globe") {
                            showLogin = true
                        }
                        authButton("Connect from local Cursor", systemImage: "laptopcomputer") {
                            Task {
                                await store.tryAutoConnect()
                                if store.isAuthenticated {
                                    await store.refresh()
                                    statusMessage = "Connected from local Cursor session."
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
                }

                SettingsPanel(
                    title: "Paste token",
                    systemImage: "key",
                    subtitle: "Escape hatch if WebView or local Cursor connect fails."
                ) {
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
                        Label("Save token", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pasteToken.isEmpty)
                }

                SettingsPanel(
                    title: "Team / Enterprise",
                    systemImage: "building.2",
                    subtitle: "Foundation only for now."
                ) {
                    Text(TeamAdminAPIConnectorStub.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
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
