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

    public init(from snapshot: UsageSnapshot, warnings: DisplayPreferences.MenuBarWarningThresholds) {
        generatedAt = snapshot.fetchedAt
        planDisplayName = snapshot.planDisplayName
        cursorModelsPercentUsed = snapshot.cursorModelsPercentUsed
        otherModelsPercentUsed = snapshot.otherModelsPercentUsed
        totalPercentUsed = snapshot.totalPercentUsed
        planUsedCents = snapshot.planUsedCents
        planLimitCents = snapshot.planLimitCents
        onDemandEnabled = snapshot.onDemandEnabled
        daysRemaining = snapshot.daysRemainingInCycle
        showWarning = snapshot.exceedsMenuBarWarnings(warnings)
    }

    @available(*, deprecated, message: "Use init(from:warnings:)")
    public init(from snapshot: UsageSnapshot, warningThreshold: Double) {
        self.init(from: snapshot, warnings: .migrated(fromLegacy: warningThreshold))
    }
}

public enum WidgetSnapshotStore {
    public static let appGroupID = "group.com.cursorusagetracker.shared"
    public static let filename = "widget-snapshot.json"

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    public static func write(_ snapshot: WidgetSnapshot) throws {
        guard let dir = containerURL else {
            // Fall back to Application Support so macOS-only builds still work before App Group is provisioned.
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("CursorUsageTracker", isDirectory: true)
            try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            let url = support.appendingPathComponent(filename)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
            return
        }
        let url = dir.appendingPathComponent(filename)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    public static func read() -> WidgetSnapshot? {
        let urls: [URL] = [
            containerURL?.appendingPathComponent(filename),
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("CursorUsageTracker/\(filename)"),
        ].compactMap { $0 }

        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
            else { continue }
            return snap
        }
        return nil
    }
}
