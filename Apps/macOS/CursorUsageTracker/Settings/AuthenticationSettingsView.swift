import SwiftUI
import WebKit
import CursorUsageCore

struct AuthenticationSettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @State private var showLogin = false
    @State private var pasteToken = ""
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section("Authentication Status") {
                HStack {
                    Text(store.isAuthenticated ? "Authenticated" : "Not authenticated")
                        .foregroundStyle(store.isAuthenticated ? .green : .secondary)
                        .fontWeight(.semibold)
                    Spacer()
                }
                if let email = store.accountEmail {
                    Text(email).foregroundStyle(.secondary)
                }
                if let statusMessage {
                    Text(statusMessage).font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Button("Sign in with Cursor…") { showLogin = true }
                    Button("Connect from local Cursor") {
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
                    Button("Re-authenticate") { showLogin = true }
                        .disabled(!store.isAuthenticated)
                    Button("Sign Out", role: .destructive) {
                        store.signOut()
                        statusMessage = "Signed out."
                    }
                    .disabled(!store.isAuthenticated)
                }
            }

            Section("Paste token (escape hatch)") {
                SecureField("WorkosCursorSessionToken or JWT", text: $pasteToken)
                Button("Save token") {
                    Task {
                        do {
                            try await store.saveSessionToken(pasteToken)
                            pasteToken = ""
                            statusMessage = "Token saved."
                        } catch {
                            statusMessage = "Token rejected: \(error.localizedDescription)"
                        }
                    }
                }
                .disabled(pasteToken.isEmpty)
            }

            Section("Team / Enterprise") {
                Text(TeamAdminAPIConnectorStub.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showLogin) {
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
            .frame(width: 720, height: 640)
        }
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
