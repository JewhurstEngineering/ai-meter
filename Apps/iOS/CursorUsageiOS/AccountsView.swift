import SwiftUI
import CursorUsageCore

struct AccountsView: View {
    @EnvironmentObject private var store: UsageStore
    @State private var showLogin = false
    @State private var reauthAccountID: UUID?
    @State private var pasteToken = ""
    @State private var statusMessage: String?
    @State private var editingLabelID: UUID?
    @State private var draftLabel = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(store.isAuthenticated ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(store.isAuthenticated ? "Authenticated" : "Not authenticated")
                            .font(.subheadline.weight(.semibold))
                        if let email = store.accountEmail {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Button {
                        reauthAccountID = nil
                        showLogin = true
                    } label: {
                        Label("Sign in with Cursor", systemImage: "globe")
                    }
                    Button {
                        reauthAccountID = store.activeAccountID
                        showLogin = true
                    } label: {
                        Label("Re-authenticate", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(!store.isAuthenticated)
                    if store.isAuthenticated {
                        Button(role: .destructive) {
                            store.signOut()
                            statusMessage = "Signed out."
                        } label: {
                            Label("Sign out active", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                } footer: {
                    Text("Tokens stay in this iPhone’s Keychain. There is no Cursor IDE session to read here.")
                }

                Section("Paste token") {
                    SecureField("WorkosCursorSessionToken or JWT", text: $pasteToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
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

                Section("Accounts") {
                    if store.connections.isEmpty {
                        Text("No saved sessions yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.accounts) { account in
                            accountRow(account)
                        }
                        Button("Sign out all", role: .destructive) {
                            store.signOutAll()
                            statusMessage = "Signed out all accounts."
                        }
                    }
                }

                Section("Team / Enterprise") {
                    Text(TeamAdminAPIConnectorStub.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Accounts")
            .sheet(isPresented: $showLogin) {
                NavigationStack {
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
                    }
                    .ignoresSafeArea()
                    .navigationTitle(reauthAccountID == nil ? "Sign in to Cursor" : "Re-authenticate")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showLogin = false }
                        }
                    }
                }
            }
        }
    }

    private func accountRow(_ account: AccountRuntime) -> some View {
        let isActive = account.id == store.activeAccountID
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(account.isAuthenticated ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                if editingLabelID == account.id {
                    TextField("Label", text: $draftLabel)
                        .onSubmit {
                            store.renameAccount(id: account.id, label: draftLabel)
                            editingLabelID = nil
                        }
                } else {
                    Text(account.connection.displayLabel)
                        .font(.subheadline.weight(.semibold))
                }
                if isActive {
                    Text("Active")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        .foregroundStyle(Color.accentColor)
                }
            }
            if let email = account.connection.email {
                Text(email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                if !isActive {
                    Button("Set active") { store.setActive(id: account.id) }
                }
                Button("Rename") {
                    editingLabelID = account.id
                    draftLabel = account.connection.label.isEmpty
                        ? account.connection.displayLabel
                        : account.connection.label
                }
                Button("Sign out", role: .destructive) {
                    store.signOut(id: account.id)
                    statusMessage = "Signed out \(account.connection.displayLabel)."
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
