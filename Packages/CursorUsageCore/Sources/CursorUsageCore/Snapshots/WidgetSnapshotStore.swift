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
    public var todaySpendCents: Int?
    public var yesterdaySpendCents: Int?
    public var cycleAverageCents: Int?
    public var remainingPaceCents: Int?
    public var last7DaySpendCents: [Int]?

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
        todaySpendCents = snapshot.todaySpendCents
        yesterdaySpendCents = snapshot.yesterdaySpendCents
        cycleAverageCents = snapshot.inferredCycleAverageCents
        remainingPaceCents = snapshot.inferredRemainingPaceCents
        last7DaySpendCents = snapshot.last7DaySpendCents
    }

    @available(*, deprecated, message: "Use init(from:warnings:)")
    public init(from snapshot: UsageSnapshot, warningThreshold: Double) {
        self.init(from: snapshot, warnings: .migrated(fromLegacy: warningThreshold))
    }
}

public enum WidgetSnapshotStore {
    /// macOS App Group form is `TEAMID.name` (see Stats.app). iOS-style `group.` is not in the widget profile.
    public static let appGroupID = "6998422DKP.com.cursorusagetracker.shared"
    public static let legacyAppGroupID = "group.com.cursorusagetracker.shared"
    public static let filename = "widget-snapshot.json"
    private static let defaultsKey = "widgetSnapshotJSON"

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static var groupIDs: [String] { [appGroupID, legacyAppGroupID] }

    private static var groupRoots: [URL] {
        var roots: [URL] = []
        var seen = Set<String>()
        for id in groupIDs {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                appendRoot(url, seen: &seen, into: &roots)
            }
            let home = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Group Containers", isDirectory: true)
                .appendingPathComponent(id, isDirectory: true)
            appendRoot(home, seen: &seen, into: &roots)
        }
        return roots
    }

    private static func appendRoot(_ url: URL, seen: inout Set<String>, into roots: inout [URL]) {
        let path = url.standardizedFileURL.path
        if seen.insert(path).inserted {
            roots.append(url)
        }
    }

    private static var candidateFiles: [URL] {
        var urls: [URL] = []
        for root in groupRoots {
            urls.append(
                root
                    .appendingPathComponent("Library", isDirectory: true)
                    .appendingPathComponent("Application Support", isDirectory: true)
                    .appendingPathComponent("CursorUsageTracker", isDirectory: true)
                    .appendingPathComponent(filename)
            )
            urls.append(root.appendingPathComponent(filename))
        }
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            urls.append(
                support
                    .appendingPathComponent("CursorUsageTracker", isDirectory: true)
                    .appendingPathComponent(filename)
            )
        }
        return urls
    }

    public static func write(_ snapshot: WidgetSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)

        for id in groupIDs {
            if let suite = UserDefaults(suiteName: id) {
                suite.set(data, forKey: defaultsKey)
                suite.synchronize()
            }
        }

        var lastError: Error?
        var wrote = false
        for url in candidateFiles {
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
        for id in groupIDs {
            if let suite = UserDefaults(suiteName: id),
               let data = suite.data(forKey: defaultsKey),
               let snap = decode(data)
            {
                return snap
            }
        }

        for url in candidateFiles {
            guard let data = try? Data(contentsOf: url), let snap = decode(data) else { continue }
            return snap
        }
        return nil
    }

    private static func decode(_ data: Data) -> WidgetSnapshot? {
        try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
