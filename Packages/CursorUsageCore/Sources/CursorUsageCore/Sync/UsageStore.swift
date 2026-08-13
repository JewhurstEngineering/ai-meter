import Foundation
import Combine

@MainActor
public final class UsageStore: ObservableObject {
    @Published public private(set) var connections: [AccountConnection] = []
    @Published public private(set) var activeAccountID: UUID?
    @Published public private(set) var runtimes: [UUID: AccountRuntime] = [:]

    @Published public private(set) var isRefreshing: Bool = false
    /// Human-readable source of the last successful local connect (IDE vs Agent).
    @Published public private(set) var lastLocalConnectSource: String?
    @Published public var preferences: DisplayPreferences {
        didSet { DisplayPreferenceStore.save(preferences) }
    }

    private let keychain = KeychainStore()
    private let client = PersonalUsageClient.shared
    private var refreshTask: Task<Void, Never>?
    /// Host app sets this to reload WidgetKit after a snapshot write.
    public var onWidgetSnapshotWritten: (() -> Void)?

    public init() {
        preferences = DisplayPreferenceStore.load()
        let registry = AccountRegistryStore.migrateLegacyPrimaryIfNeeded(keychain: keychain)
        connections = registry.connections
        activeAccountID = registry.activeAccountID
        rebuildRuntimesFromKeychain()
    }

    // MARK: - Active-account convenience (single-account call sites)

    public var activeAccount: AccountRuntime? {
        guard let activeAccountID else { return nil }
        return runtimes[activeAccountID]
    }

    public var snapshot: UsageSnapshot? { activeAccount?.snapshot }

    public var isAuthenticated: Bool {
        if let active = activeAccount { return active.isAuthenticated }
        return connections.contains { keychain.load(account: $0.keychainAccount) != nil }
    }

    public var lastError: String? { activeAccount?.lastError ?? lastConnectFailure }

    public var accountEmail: String? { activeAccount?.connection.email }

    /// Used when there is no account yet (failed auto-connect).
    @Published public private(set) var lastConnectFailure: String?

    public var accounts: [AccountRuntime] {
        connections.compactMap { runtimes[$0.id] }
    }

    public func account(_ id: UUID) -> AccountRuntime? { runtimes[id] }

    public var menuBarPresentation: MenuBarPresentation {
        switch preferences.menuBarAccountMode {
        case .combined:
            return MenuBarFormatter.formatCombined(
                entries: accounts.map {
                    (
                        label: $0.connection.menuBarLabel,
                        snapshot: $0.snapshot,
                        authenticated: $0.isAuthenticated
                    )
                },
                preferences: preferences
            )
        case .activeOnly, .separateItems:
            return MenuBarFormatter.format(
                snapshot: snapshot,
                preferences: preferences,
                authenticated: isAuthenticated
            )
        }
    }

    public func menuBarPresentation(for id: UUID) -> MenuBarPresentation {
        let runtime = runtimes[id]
        return MenuBarFormatter.format(
            snapshot: runtime?.snapshot,
            preferences: preferences,
            authenticated: runtime?.isAuthenticated ?? false
        )
    }

    // MARK: - Lifecycle

    public func bootstrap() async {
        if connections.isEmpty {
            await tryAutoConnect()
        }
        if !connections.isEmpty {
            await refresh()
            startAutoRefresh()
        }
    }

    public func tryAutoConnect() async {
        #if os(macOS)
        guard let credential = CursorLocalAuthReader.preferredCredential() else {
            setActiveError("No local Cursor session found.")
            return
        }
        do {
            let me = try await client.validate(sessionToken: credential.token)
            _ = try upsertAccount(token: credential.token, email: me.email ?? credential.cachedEmail)
            lastLocalConnectSource = credential.source.rawValue
            lastConnectFailure = nil
        } catch {
            setActiveError("Auto-connect via \(credential.source.rawValue) failed. Sign in manually.")
        }
        #endif
    }

    public func saveSessionToken(_ token: String, replacing id: UUID? = nil) async throws {
        let me = try await client.validate(sessionToken: token)
        _ = try upsertAccount(token: token, email: me.email, replacing: id)
        await refresh()
        startAutoRefresh()
    }

    public func signOut() {
        if let activeAccountID {
            signOut(id: activeAccountID)
        }
    }

    public func signOut(id: UUID) {
        keychain.delete(account: id.uuidString)
        connections.removeAll { $0.id == id }
        runtimes[id] = nil
        if activeAccountID == id {
            activeAccountID = connections.first?.id
        }
        persistRegistry()
        if connections.isEmpty {
            refreshTask?.cancel()
            refreshTask = nil
            lastLocalConnectSource = nil
        }
        writeWidgetSnapshot()
    }

    public func signOutAll() {
        for connection in connections {
            keychain.delete(account: connection.keychainAccount)
        }
        connections = []
        runtimes = [:]
        activeAccountID = nil
        lastLocalConnectSource = nil
        refreshTask?.cancel()
        refreshTask = nil
        persistRegistry()
        writeWidgetSnapshot()
    }

    public func setActive(id: UUID) {
        guard connections.contains(where: { $0.id == id }) else { return }
        activeAccountID = id
        persistRegistry()
        writeWidgetSnapshot()
        pruneWarningSnoozesUsingActive()
    }

    public func renameAccount(id: UUID, label: String) {
        guard let index = connections.firstIndex(where: { $0.id == id }) else { return }
        connections[index].label = label
        if var runtime = runtimes[id] {
            runtime.connection.label = label
            runtimes[id] = runtime
        }
        persistRegistry()
    }

    public func refresh() async {
        let ids = connections.map(\.id)
        guard !ids.isEmpty else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        for id in ids {
            await refreshAccount(id)
        }
        writeWidgetSnapshot()
        pruneWarningSnoozesUsingActive()
    }

    public func refreshAccount(_ id: UUID) async {
        guard let connection = connections.first(where: { $0.id == id }) else { return }
        guard let token = keychain.load(account: connection.keychainAccount) else {
            markUnauthenticated(id: id, error: "Not signed in.")
            return
        }
        updateRuntime(id: id) { $0.isRefreshing = true }
        defer { updateRuntime(id: id) { $0.isRefreshing = false } }
        do {
            let snap = try await client.fetchSnapshot(sessionToken: token)
            updateRuntime(id: id) {
                $0.snapshot = snap
                $0.lastError = nil
                $0.isAuthenticated = true
            }
            UsageNotificationService.clearSessionExpiredDedupe(accountID: id)
            await UsageNotificationService.evaluate(
                snapshot: snap,
                preferences: preferences,
                accountEmail: connection.email ?? connection.displayLabel,
                accountID: id
            )
        } catch PersonalAPIError.unauthorized {
            let email = connection.email
            keychain.delete(account: connection.keychainAccount)
            connections.removeAll { $0.id == id }
            runtimes[id] = nil
            if activeAccountID == id {
                activeAccountID = connections.first?.id
            }
            persistRegistry()
            await UsageNotificationService.notifySessionExpiredIfNeeded(
                preferences: preferences,
                accountEmail: email,
                accountID: id
            )
            if connections.isEmpty {
                refreshTask?.cancel()
                refreshTask = nil
            }
        } catch {
            updateRuntime(id: id) {
                $0.lastError = "Refresh failed: \(error.localizedDescription)"
            }
        }
    }

    public func startAutoRefresh() {
        refreshTask?.cancel()
        guard !connections.isEmpty else { return }
        let minutes = max(1, preferences.refreshIntervalMinutes)
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.refresh()
            }
        }
    }

    public func applyPreferences(_ prefs: DisplayPreferences) {
        preferences = prefs
        startAutoRefresh()
        writeWidgetSnapshot()
    }

    public func snoozeMenuBarWarning(_ channel: UsageSnapshot.WarningChannel) {
        preferences.snoozeWarning(channel)
    }

    public func snoozeAllMenuBarWarnings() {
        preferences.snoozeWarnings(menuBarPresentation.warningHits.map(\.channel))
    }

    // MARK: - Private

    private func rebuildRuntimesFromKeychain() {
        var next: [UUID: AccountRuntime] = [:]
        for connection in connections {
            let authed = keychain.load(account: connection.keychainAccount) != nil
            next[connection.id] = AccountRuntime(
                connection: connection,
                snapshot: runtimes[connection.id]?.snapshot,
                lastError: runtimes[connection.id]?.lastError,
                isRefreshing: false,
                isAuthenticated: authed
            )
        }
        runtimes = next
    }

    @discardableResult
    private func upsertAccount(token: String, email: String?, replacing: UUID? = nil) throws -> UUID {
        lastConnectFailure = nil
        if let replacing, let index = connections.firstIndex(where: { $0.id == replacing }) {
            try keychain.save(token: token, account: replacing.uuidString)
            connections[index].email = email ?? connections[index].email
            if connections[index].label.isEmpty, let email {
                connections[index].label = AccountConnection(email: email).displayLabel
            }
            activeAccountID = replacing
            rebuildRuntimesFromKeychain()
            persistRegistry()
            UsageNotificationService.clearSessionExpiredDedupe(accountID: replacing)
            return replacing
        }

        if let email, let existing = connections.first(where: { $0.email?.lowercased() == email.lowercased() }) {
            try keychain.save(token: token, account: existing.keychainAccount)
            if let index = connections.firstIndex(where: { $0.id == existing.id }) {
                connections[index].email = email
            }
            activeAccountID = existing.id
            rebuildRuntimesFromKeychain()
            persistRegistry()
            UsageNotificationService.clearSessionExpiredDedupe(accountID: existing.id)
            return existing.id
        }

        let id = UUID()
        let defaultLabel: String
        if let email {
            defaultLabel = AccountConnection(email: email).displayLabel
        } else {
            defaultLabel = ""
        }
        let connection = AccountConnection(id: id, email: email, label: defaultLabel, createdAt: Date())
        try keychain.save(token: token, account: id.uuidString)
        connections.append(connection)
        activeAccountID = id
        rebuildRuntimesFromKeychain()
        persistRegistry()
        UsageNotificationService.clearSessionExpiredDedupe(accountID: id)
        return id
    }

    private func persistRegistry() {
        var registry = AccountRegistry(connections: connections, activeAccountID: activeAccountID)
        registry.normalizeActive()
        activeAccountID = registry.activeAccountID
        AccountRegistryStore.save(registry)
    }

    private func updateRuntime(id: UUID, mutate: (inout AccountRuntime) -> Void) {
        guard var runtime = runtimes[id] else { return }
        mutate(&runtime)
        runtimes[id] = runtime
    }

    private func markUnauthenticated(id: UUID, error: String) {
        updateRuntime(id: id) {
            $0.isAuthenticated = false
            $0.snapshot = nil
            $0.lastError = error
        }
    }

    private func setActiveError(_ message: String) {
        if let id = activeAccountID {
            updateRuntime(id: id) { $0.lastError = message }
        }
        lastConnectFailure = message
    }

    private func writeWidgetSnapshot() {
        guard let snap = snapshot else { return }
        let widget = WidgetSnapshot(
            from: snap,
            warnings: preferences.menuBarWarnings,
            snoozedChannels: preferences.snoozedWarningChannels
        )
        do {
            try WidgetSnapshotStore.write(widget)
        } catch {
            // Widget still probes every known path on the next timeline tick.
        }
        onWidgetSnapshotWritten?()
    }

    private func pruneWarningSnoozesUsingActive() {
        guard let snap = snapshot else { return }
        let hot = Set(snap.menuBarWarningHits(preferences.menuBarWarnings).map(\.channel.rawValue))
        var prefs = preferences
        prefs.pruneSnoozedWarnings(stillTriggered: hot)
        if prefs.snoozedWarningChannels != preferences.snoozedWarningChannels {
            preferences = prefs
        }
    }
}
