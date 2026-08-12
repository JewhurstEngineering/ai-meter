import Foundation
import Combine

@MainActor
public final class UsageStore: ObservableObject {
    @Published public private(set) var snapshot: UsageSnapshot?
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var isRefreshing: Bool = false
    @Published public private(set) var lastError: String?
    @Published public private(set) var accountEmail: String?
    @Published public var preferences: DisplayPreferences {
        didSet { DisplayPreferenceStore.save(preferences) }
    }

    private let keychain = KeychainStore()
    private let client = PersonalUsageClient.shared
    private var refreshTask: Task<Void, Never>?

    public init() {
        preferences = DisplayPreferenceStore.load()
        isAuthenticated = keychain.load(account: SessionAccount.defaultAccount) != nil
    }

    public var menuBarPresentation: MenuBarPresentation {
        MenuBarFormatter.format(
            snapshot: snapshot,
            preferences: preferences,
            authenticated: isAuthenticated
        )
    }

    public func bootstrap() async {
        if keychain.load(account: SessionAccount.defaultAccount) == nil {
            await tryAutoConnect()
        }
        if isAuthenticated {
            await refresh()
            startAutoRefresh()
        }
    }

    public func tryAutoConnect() async {
        #if os(macOS)
        if let token = CursorLocalAuthReader.readCursorAgentKeychainToken()
            ?? CursorLocalAuthReader.readAccessToken()
        {
            do {
                let me = try await client.validate(sessionToken: token)
                try keychain.save(token: token, account: SessionAccount.defaultAccount)
                isAuthenticated = true
                accountEmail = me.email
                lastError = nil
            } catch {
                lastError = "Auto-connect failed. Sign in manually."
            }
        }
        #endif
    }

    public func saveSessionToken(_ token: String) async throws {
        let me = try await client.validate(sessionToken: token)
        try keychain.save(token: token, account: SessionAccount.defaultAccount)
        isAuthenticated = true
        accountEmail = me.email
        lastError = nil
        await refresh()
        startAutoRefresh()
    }

    public func signOut() {
        keychain.delete(account: SessionAccount.defaultAccount)
        isAuthenticated = false
        snapshot = nil
        accountEmail = nil
        refreshTask?.cancel()
        refreshTask = nil
    }

    public func refresh() async {
        guard let token = keychain.load(account: SessionAccount.defaultAccount) else {
            isAuthenticated = false
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let snap = try await client.fetchSnapshot(sessionToken: token)
            snapshot = snap
            lastError = nil
            let widget = WidgetSnapshot(from: snap, warningThreshold: preferences.warningThresholdPercent)
            try? WidgetSnapshotStore.write(widget)
        } catch PersonalAPIError.unauthorized {
            lastError = "Session expired. Re-authenticate."
            isAuthenticated = false
        } catch {
            lastError = "Refresh failed: \(error.localizedDescription)"
        }
    }

    public func startAutoRefresh() {
        refreshTask?.cancel()
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
        if let snapshot {
            let widget = WidgetSnapshot(from: snapshot, warningThreshold: prefs.warningThresholdPercent)
            try? WidgetSnapshotStore.write(widget)
        }
    }
}
