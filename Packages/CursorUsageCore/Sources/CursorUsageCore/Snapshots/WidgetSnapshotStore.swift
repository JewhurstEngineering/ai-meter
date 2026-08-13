import Foundation

/// Sanitized snapshot for App Group → widgets / watch. Never includes credentials.
public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public var generatedAt: Date
    public var planDisplayName: String
    public var cursorModelsPercentUsed: Double?
    public var otherModelsPercentUsed: Double?
    public var totalPercentUsed: Double?
    public var planUsedCents: Int?
    public var planLimitCents: Int?
    public var onDemandEnabled: Bool
    public var daysRemaining: Int?
    public var showWarning: Bool

    public init(
        from snapshot: UsageSnapshot,
        warnings: DisplayPreferences.MenuBarWarningThresholds,
        snoozedChannels: [String] = []
    ) {
        generatedAt = snapshot.fetchedAt
        planDisplayName = snapshot.planDisplayName
        cursorModelsPercentUsed = snapshot.cursorModelsPercentUsed
        otherModelsPercentUsed = snapshot.otherModelsPercentUsed
        totalPercentUsed = snapshot.totalPercentUsed
        planUsedCents = snapshot.planUsedCents
        planLimitCents = snapshot.planLimitCents
        onDemandEnabled = snapshot.onDemandEnabled
        daysRemaining = snapshot.daysRemainingInCycle
        let snoozed = Set(snoozedChannels)
        showWarning = snapshot.menuBarWarningHits(warnings).contains {
            !snoozed.contains($0.channel.rawValue)
        }
    }

    @available(*, deprecated, message: "Use init(from:warnings:)")
    public init(from snapshot: UsageSnapshot, warningThreshold: Double) {
        self.init(from: snapshot, warnings: .migrated(fromLegacy: warningThreshold))
    }
}

public enum WidgetSnapshotStore {
    public static let appGroupID = "group.com.cursorusagetracker.shared"
    public static let filename = "widget-snapshot.json"
    private static let defaultsKey = "widgetSnapshotJSON"

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// Sandboxed widgets can read Library/ inside the group; a file at the container root often fails.
    private static var groupSupportFileURL: URL? {
        containerURL?
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("CursorUsageTracker", isDirectory: true)
            .appendingPathComponent(filename)
    }

    private static var groupRootFileURL: URL? {
        containerURL?.appendingPathComponent(filename)
    }

    private static var fallbackFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CursorUsageTracker", isDirectory: true)
            .appendingPathComponent(filename)
    }

    public static func write(_ snapshot: WidgetSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)

        if let suite = UserDefaults(suiteName: appGroupID) {
            suite.set(data, forKey: defaultsKey)
            suite.synchronize()
        }

        var lastError: Error?
        var wrote = false
        for url in [groupSupportFileURL, groupRootFileURL, fallbackFileURL].compactMap({ $0 }) {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: url, options: .atomic)
                wrote = true
            } catch {
                lastError = error
            }
        }
        if !wrote, let lastError {
            throw lastError
        }
    }

    public static func read() -> WidgetSnapshot? {
        if let suite = UserDefaults(suiteName: appGroupID),
           let data = suite.data(forKey: defaultsKey),
           let snap = decode(data)
        {
            return snap
        }

        for url in [groupSupportFileURL, groupRootFileURL, fallbackFileURL].compactMap({ $0 }) {
            guard let data = try? Data(contentsOf: url), let snap = decode(data) else { continue }
            return snap
        }
        return nil
    }

    private static func decode(_ data: Data) -> WidgetSnapshot? {
        try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
