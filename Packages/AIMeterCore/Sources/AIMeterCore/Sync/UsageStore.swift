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
    private let claudeClient = ClaudeUsageClient.shared
    private let codexClient = CodexUsageClient.shared
    private let cloudClient = CloudAgentsClient.shared
    private var refreshTask: Task<Void, Never>?
    /// Host app sets this to reload WidgetKit after a snapshot write.
    public var onWidgetSnapshotWritten: (() -> Void)?

    #if os(macOS)
    @Published public private(set) var thisMac = CursorProcessSnapshot()
    /// IDE Composer / Agent threads on this Mac.
    @Published public private(set) var localComposers: [LocalComposerSummary] = []
    /// Cursor CLI (`cursor-agent`) sessions from `~/.cursor/chats`.
    @Published public private(set) var localCLISessions: [LocalComposerSummary] = []
    #endif

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

    public var visibleAccounts: [AccountRuntime] {
        accounts.filter { !$0.connection.isHidden }
    }

    public var visibleConnections: [AccountConnection] {
        connections.filter { !$0.isHidden }
    }

    public var monitoredIDs: [UUID] {
        connections.filter { !$0.isPaused }.map(\.id)
    }

    public func account(_ id: UUID) -> AccountRuntime? { runtimes[id] }

    public var menuBarPresentation: MenuBarPresentation {
        switch preferences.menuBarAccountMode {
        case .combined:
            return MenuBarFormatter.formatCombined(
                entries: visibleAccounts.map {
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
        } else {
            refreshLocalActivity()
        }
    }

    public func tryAutoConnect() async {
        #if os(macOS)
        if !connections.contains(where: { $0.provider == .cursor }) {
            if let credential = CursorLocalAuthReader.preferredCredential() {
                do {
                    let me = try await client.validate(sessionToken: credential.token)
                    let outcome = try upsertAccount(
                        token: credential.token,
                        email: me.email ?? credential.cachedEmail,
                        provider: .cursor
                    )
                    markConnected(id: outcome.id)
                    lastLocalConnectSource = credential.source.rawValue
                    lastConnectFailure = nil
                } catch {
                    setActiveError("Auto-connect via \(credential.source.rawValue) failed. Sign in manually.")
                }
            } else if connections.isEmpty {
                setActiveError("No local Cursor session found.")
            }
        }
        if !connections.contains(where: { $0.provider == .claude }) {
            _ = try? await connectClaude(setErrorOnFailure: false)
        }
        if !connections.contains(where: { $0.provider == .codex }) {
            _ = try? await connectCodex(setErrorOnFailure: false)
        }
        #endif
    }

    public func connectClaude(replacing: UUID? = nil) async throws -> LocalConnectResult {
        let outcome = try await connectClaude(setErrorOnFailure: true, replacing: replacing)
        startAutoRefresh()
        return connectResult(outcome, source: lastLocalConnectSource ?? "Claude Code")
    }

    public func connectCodex(replacing: UUID? = nil) async throws -> LocalConnectResult {
        let outcome = try await connectCodex(setErrorOnFailure: true, replacing: replacing)
        startAutoRefresh()
        return connectResult(outcome, source: lastLocalConnectSource ?? "Codex")
    }

    @discardableResult
    private func connectClaude(setErrorOnFailure: Bool, replacing: UUID? = nil) async throws -> UpsertOutcome {
        #if os(macOS)
        let lookup = ClaudeLocalAuthReader.credentialLookup()
        guard let cred = lookup.credential else {
            if setErrorOnFailure {
                setConnectError(
                    lookup.failureMessage ?? ClaudeLocalAuthReader.missingSessionMessage(),
                    accountID: replacing
                )
            }
            throw ProviderUsageError.missingCredentials
        }
        do {
            let snap = try await claudeClient.fetchSnapshot(credential: cred)
            let token = storedTokenJSON(
                access: cred.accessToken,
                refresh: cred.refreshToken,
                email: nil,
                expiresAt: cred.expiresAt
            )
            let outcome = try upsertAccount(
                token: token,
                email: nil,
                replacing: replacing,
                provider: .claude,
                defaultLabel: snap.planDisplayName
            )
            markConnected(id: outcome.id, snapshot: snap)
            lastLocalConnectSource = cred.source
            lastConnectFailure = nil
            return outcome
        } catch {
            if setErrorOnFailure {
                setConnectError(
                    "Claude connect failed (\(error.localizedDescription)). Sign in with Claude Code (`claude` in Terminal), then Reconnect this account.",
                    accountID: replacing
                )
            }
            throw error
        }
        #else
        throw ProviderUsageError.missingCredentials
        #endif
    }

    @discardableResult
    private func connectCodex(setErrorOnFailure: Bool, replacing: UUID? = nil) async throws -> UpsertOutcome {
        #if os(macOS)
        guard let cred = CodexLocalAuthReader.preferredCredential() else {
            if setErrorOnFailure {
                setConnectError(CodexLocalAuthReader.missingSessionMessage(), accountID: replacing)
            }
            throw ProviderUsageError.missingCredentials
        }
        do {
            let snap = try await codexClient.fetchSnapshot(credential: cred)
            let token = storedTokenJSON(
                access: cred.accessToken,
                refresh: cred.refreshToken,
                accountID: cred.accountID,
                email: cred.email
            )
            let outcome = try upsertAccount(
                token: token,
                email: cred.email,
                replacing: replacing,
                provider: .codex,
                defaultLabel: snap.planDisplayName
            )
            markConnected(id: outcome.id, snapshot: snap)
            lastLocalConnectSource = cred.source
            lastConnectFailure = nil
            return outcome
        } catch {
            if setErrorOnFailure {
                setConnectError(
                    "Codex connect failed (\(error.localizedDescription)). \(CodexLocalAuthReader.loginInstructions)",
                    accountID: replacing
                )
            }
            throw error
        }
        #else
        throw ProviderUsageError.missingCredentials
        #endif
    }

    public func saveSessionToken(_ token: String, replacing id: UUID? = nil) async throws {
        let me = try await client.validate(sessionToken: token)
        let outcome = try upsertAccount(
            token: token,
            email: me.email,
            replacing: id,
            provider: .cursor
        )
        // `/api/auth/me` already proved this session is valid. Update the row
        // before any longer usage refresh so closing the login sheet cannot
        // leave a successful sign-in looking expired.
        markConnected(id: outcome.id)
        await refreshAccount(outcome.id)
        startAutoRefresh()
    }

    public func signOut() {
        if let activeAccountID {
            signOut(id: activeAccountID)
        }
    }

    public func signOut(id: UUID) {
        keychain.delete(account: id.uuidString)
        keychain.delete(account: AccountConnection(id: id).cloudAPIKeychainAccount)
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
            keychain.delete(account: connection.cloudAPIKeychainAccount)
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
        if let index = connections.firstIndex(where: { $0.id == id }), connections[index].isHidden {
            connections[index].isHidden = false
            if var runtime = runtimes[id] {
                runtime.connection.isHidden = false
                runtimes[id] = runtime
            }
        }
        activeAccountID = id
        persistRegistry()
        writeWidgetSnapshot()
        pruneWarningSnoozesUsingActive()
    }

    public func setAccountHidden(id: UUID, hidden: Bool) {
        updateConnection(id: id) { $0.isHidden = hidden }
        persistRegistry()
        writeWidgetSnapshot()
    }

    public func setAccountPaused(id: UUID, paused: Bool) {
        updateConnection(id: id) { $0.isPaused = paused }
        persistRegistry()
        startAutoRefresh()
        if !paused {
            Task { await refreshAccount(id) }
        }
    }

    /// Surface an error on a specific account from a call site that has already
    /// dismissed its sheet (e.g. the popover reauthSheet for Cursor).
    public func setLastError(_ message: String, forAccount id: UUID?) {
        setConnectError(message, accountID: id)
    }

    /// Hide a refresh warning until the next failed fetch for this account.
    public func clearLastError(id: UUID? = nil) {
        let target = id ?? activeAccountID
        if target == nil || target == activeAccountID {
            lastConnectFailure = nil
        }
        guard let target else { return }
        updateRuntime(id: target) { $0.lastError = nil }
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
        refreshLocalActivity()
        let ids = monitoredIDs
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
        guard !connection.isPaused else { return }
        guard let token = keychain.load(account: connection.keychainAccount) else {
            markUnauthenticated(
                id: id,
                error: PersonalAPIError.unauthorized.errorDescription ?? "Session expired — sign in again."
            )
            return
        }
        updateRuntime(id: id) { $0.isRefreshing = true }
        defer { updateRuntime(id: id) { $0.isRefreshing = false } }
        do {
            let snap = try await fetchSnapshot(for: connection, token: token)
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
                accountID: id,
                connection: connection
            )
            if connection.provider == .cursor {
                await refreshCloudAgents(id: id)
            }
        } catch let error where isUnauthorized(error) {
            updateRuntime(id: id) { $0.markSessionExpired() }
            await UsageNotificationService.notifySessionExpiredIfNeeded(
                preferences: preferences,
                accountEmail: connection.email ?? connection.displayLabel,
                accountID: id,
                connection: connection
            )
        } catch {
            updateRuntime(id: id) {
                $0.lastError = error.localizedDescription
            }
        }
    }

    private func fetchSnapshot(for connection: AccountConnection, token: String) async throws -> UsageSnapshot {
        switch connection.provider {
        case .cursor:
            return try await client.fetchSnapshot(sessionToken: token)
        case .claude:
            var cred = claudeCredential(fromStored: token)
            #if os(macOS)
            // Claude Code rotates OAuth tokens in its own keychain. A frozen copy
            // from "Add Claude" goes stale overnight; always prefer the live session.
            if let live = ClaudeLocalAuthReader.preferredCredential() {
                cred = live
                let json = storedTokenJSON(
                    access: live.accessToken,
                    refresh: live.refreshToken,
                    expiresAt: live.expiresAt
                )
                try? keychain.save(token: json, account: connection.keychainAccount)
            }
            #endif
            return try await claudeClient.fetchSnapshot(credential: cred)
        case .codex:
            let cred = codexCredential(fromStored: token)
            return try await codexClient.fetchSnapshot(credential: cred)
        }
    }

    public func saveCloudAPIKey(_ key: String, for id: UUID? = nil) async throws {
        let accountID = id ?? activeAccountID
        guard let accountID, let connection = connections.first(where: { $0.id == accountID }) else {
            throw CloudAgentsError.httpStatus(-1)
        }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let info = try await cloudClient.validate(apiKey: trimmed)
        try keychain.save(token: trimmed, account: connection.cloudAPIKeychainAccount)
        updateRuntime(id: accountID) {
            $0.hasCloudAPIKey = true
            $0.cloudAPIKeyName = info.apiKeyName
            $0.cloudAPIKeyEmail = info.userEmail
            $0.cloudAgentsError = nil
        }
        await refreshCloudAgents(id: accountID)
    }

    public func removeCloudAPIKey(for id: UUID? = nil) {
        let accountID = id ?? activeAccountID
        guard let accountID, let connection = connections.first(where: { $0.id == accountID }) else { return }
        keychain.delete(account: connection.cloudAPIKeychainAccount)
        updateRuntime(id: accountID) {
            $0.hasCloudAPIKey = false
            $0.cloudAPIKeyName = nil
            $0.cloudAPIKeyEmail = nil
            $0.cloudAgents = []
            $0.cloudAgentsError = nil
        }
    }

    public func refreshLocalActivity() {
        #if os(macOS)
        thisMac = CursorProcessMonitor.snapshot()
        localComposers = CursorLocalComposerReader.recent()
        localCLISessions = CursorCLISessionReader.recent()
        #endif
    }

    private func refreshCloudAgents(id: UUID) async {
        guard let connection = connections.first(where: { $0.id == id }) else { return }
        guard let apiKey = keychain.load(account: connection.cloudAPIKeychainAccount) else {
            updateRuntime(id: id) {
                $0.hasCloudAPIKey = false
                $0.cloudAgents = []
                $0.cloudAgentsError = nil
            }
            return
        }
        do {
            let agents = try await cloudClient.listAgents(apiKey: apiKey)
            updateRuntime(id: id) {
                $0.hasCloudAPIKey = true
                $0.cloudAgents = agents
                $0.cloudAgentsError = nil
            }
        } catch CloudAgentsError.unauthorized {
            updateRuntime(id: id) {
                $0.hasCloudAPIKey = true
                $0.cloudAgents = []
                $0.cloudAgentsError = "Cloud Agents API key rejected."
            }
        } catch {
            updateRuntime(id: id) {
                $0.hasCloudAPIKey = true
                $0.cloudAgentsError = "Cloud agents unavailable."
            }
        }
    }

    public func startAutoRefresh() {
        refreshTask?.cancel()
        guard connections.contains(where: { !$0.isPaused }) else {
            refreshTask = nil
            return
        }
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

    public func updatePreferences(_ mutate: (inout DisplayPreferences) -> Void) {
        var prefs = preferences
        mutate(&prefs)
        applyPreferences(prefs)
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
            let previous = runtimes[connection.id]
            let authed = keychain.load(account: connection.keychainAccount) != nil
            let hasCloud = keychain.load(account: connection.cloudAPIKeychainAccount) != nil
            next[connection.id] = AccountRuntime(
                connection: connection,
                snapshot: previous?.snapshot,
                lastError: previous?.lastError,
                isRefreshing: false,
                isAuthenticated: authed,
                hasCloudAPIKey: hasCloud,
                cloudAPIKeyName: previous?.cloudAPIKeyName,
                cloudAPIKeyEmail: previous?.cloudAPIKeyEmail,
                cloudAgents: previous?.cloudAgents ?? [],
                cloudAgentsError: previous?.cloudAgentsError
            )
        }
        runtimes = next
    }

    @discardableResult
    private func upsertAccount(
        token: String,
        email: String?,
        replacing: UUID? = nil,
        provider: ProviderKind = .cursor,
        defaultLabel: String? = nil
    ) throws -> UpsertOutcome {
        lastConnectFailure = nil
        if let replacing, let index = connections.firstIndex(where: { $0.id == replacing }) {
            try keychain.save(token: token, account: replacing.uuidString)
            connections[index].email = email ?? connections[index].email
            connections[index].provider = provider
            if connections[index].label.isEmpty {
                if let email {
                    connections[index].label = AccountConnection(email: email, provider: provider).displayLabel
                } else if let defaultLabel {
                    connections[index].label = defaultLabel
                }
            }
            activeAccountID = replacing
            rebuildRuntimesFromKeychain()
            persistRegistry()
            UsageNotificationService.clearSessionExpiredDedupe(accountID: replacing)
            return UpsertOutcome(id: replacing, refreshedExisting: true)
        }

        if let email, let existing = connections.first(where: {
            $0.provider == provider && $0.email?.lowercased() == email.lowercased()
        }) {
            try keychain.save(token: token, account: existing.keychainAccount)
            if let index = connections.firstIndex(where: { $0.id == existing.id }) {
                connections[index].email = email
            }
            activeAccountID = existing.id
            rebuildRuntimesFromKeychain()
            persistRegistry()
            UsageNotificationService.clearSessionExpiredDedupe(accountID: existing.id)
            return UpsertOutcome(id: existing.id, refreshedExisting: true)
        }

        if email == nil, let existing = connections.first(where: { $0.provider == provider && $0.email == nil }) {
            try keychain.save(token: token, account: existing.keychainAccount)
            activeAccountID = existing.id
            rebuildRuntimesFromKeychain()
            persistRegistry()
            UsageNotificationService.clearSessionExpiredDedupe(accountID: existing.id)
            return UpsertOutcome(id: existing.id, refreshedExisting: true)
        }

        let id = UUID()
        let label: String
        if let defaultLabel, !(defaultLabel.isEmpty) {
            label = defaultLabel
        } else if let email {
            label = AccountConnection(email: email, provider: provider).displayLabel
        } else {
            label = provider.displayName
        }
        let connection = AccountConnection(
            id: id,
            email: email,
            label: label,
            createdAt: Date(),
            provider: provider
        )
        try keychain.save(token: token, account: id.uuidString)
        connections.append(connection)
        activeAccountID = id
        rebuildRuntimesFromKeychain()
        persistRegistry()
        UsageNotificationService.clearSessionExpiredDedupe(accountID: id)
        return UpsertOutcome(id: id, refreshedExisting: false)
    }

    private func isUnauthorized(_ error: Error) -> Bool {
        if let error = error as? PersonalAPIError, error == .unauthorized { return true }
        if let error = error as? ProviderUsageError, error.isUnauthorized { return true }
        return false
    }

    private func storedTokenJSON(
        access: String,
        refresh: String? = nil,
        accountID: String? = nil,
        email: String? = nil,
        expiresAt: Date? = nil
    ) -> String {
        var obj: [String: Any] = ["access_token": access]
        if let refresh { obj["refresh_token"] = refresh }
        if let accountID { obj["account_id"] = accountID }
        if let email { obj["email"] = email }
        if let expiresAt { obj["expires_at"] = expiresAt.timeIntervalSince1970 * 1000 }
        if let data = try? JSONSerialization.data(withJSONObject: obj),
           let text = String(data: data, encoding: .utf8)
        {
            return text
        }
        return access
    }

    private func claudeCredential(fromStored token: String) -> ClaudeOAuthCredential {
        if let parsed = ClaudeLocalAuthReader.parseJSON(token, source: "keychain") {
            return parsed
        }
        return ClaudeOAuthCredential(accessToken: token, source: "keychain")
    }

    private func codexCredential(fromStored token: String) -> CodexOAuthCredential {
        if let data = token.data(using: .utf8),
           let parsed = CodexLocalAuthReader.parse(data, source: "keychain")
        {
            return parsed
        }
        return CodexOAuthCredential(accessToken: token, source: "keychain")
    }

    private func persistRegistry() {
        var registry = AccountRegistry(connections: connections, activeAccountID: activeAccountID)
        registry.normalizeActive()
        connections = registry.connections
        activeAccountID = registry.activeAccountID
        AccountRegistryStore.save(registry)
    }

    private func updateConnection(id: UUID, mutate: (inout AccountConnection) -> Void) {
        guard let index = connections.firstIndex(where: { $0.id == id }) else { return }
        mutate(&connections[index])
        if var runtime = runtimes[id] {
            runtime.connection = connections[index]
            runtimes[id] = runtime
        }
    }

    private func updateRuntime(id: UUID, mutate: (inout AccountRuntime) -> Void) {
        guard var runtime = runtimes[id] else { return }
        mutate(&runtime)
        runtimes[id] = runtime
    }

    private func markConnected(id: UUID, snapshot: UsageSnapshot? = nil) {
        updateRuntime(id: id) {
            if let snapshot {
                $0.snapshot = snapshot
            }
            $0.lastError = nil
            $0.isAuthenticated = true
        }
        UsageNotificationService.clearSessionExpiredDedupe(accountID: id)
    }

    private func markUnauthenticated(id: UUID, error: String) {
        updateRuntime(id: id) {
            $0.isAuthenticated = false
            $0.lastError = error
        }
    }

    private func setConnectError(_ message: String, accountID: UUID?) {
        lastConnectFailure = message
        if let accountID {
            updateRuntime(id: accountID) { $0.lastError = message }
        } else if let id = activeAccountID {
            updateRuntime(id: id) { $0.lastError = message }
        }
    }

    private func setActiveError(_ message: String) {
        setConnectError(message, accountID: activeAccountID)
    }

    private func connectResult(_ outcome: UpsertOutcome, source: String) -> LocalConnectResult {
        let label = connections.first(where: { $0.id == outcome.id })?.displayLabel
            ?? ProviderKind.cursor.displayName
        let provider = connections.first(where: { $0.id == outcome.id })?.provider ?? .cursor
        return LocalConnectResult(
            id: outcome.id,
            displayLabel: label,
            source: source,
            refreshedExisting: outcome.refreshedExisting,
            provider: provider
        )
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
