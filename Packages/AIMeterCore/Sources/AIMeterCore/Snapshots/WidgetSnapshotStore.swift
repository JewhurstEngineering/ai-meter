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
    public var onDemandUsedCents: Int?
    public var onDemandLimitCents: Int?
    public var bonusCents: Int?
    public var daysRemaining: Int?
    public var billingCycleEnd: Date?
    public var showWarning: Bool
    public var modelBreakdown: [WidgetModelCost]?
    public var totalModelCostCents: Double?

    public struct WidgetModelCost: Codable, Sendable, Equatable, Identifiable {
        public var id: String { model }
        public var model: String
        public var totalCents: Double

        public init(model: String, totalCents: Double) {
            self.model = model
            self.totalCents = totalCents
        }
    }

    public var isOnDemandUnlimited: Bool {
        onDemandEnabled && (onDemandLimitCents == nil || (onDemandLimitCents ?? 0) <= 0)
    }

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
        onDemandUsedCents = snapshot.onDemandUsedCents
        onDemandLimitCents = snapshot.onDemandLimitCents
        bonusCents = snapshot.bonusCents
        daysRemaining = snapshot.daysRemainingInCycle
        billingCycleEnd = snapshot.billingCycleEnd
        let snoozed = Set(snoozedChannels)
        showWarning = snapshot.menuBarWarningHits(warnings).contains {
            !snoozed.contains($0.channel.rawValue)
        }
        let models = snapshot.modelBreakdown
        modelBreakdown = models.prefix(6).map {
            WidgetModelCost(model: $0.model, totalCents: $0.totalCents)
        }
        totalModelCostCents = snapshot.totalModelCostCents
            ?? (models.isEmpty ? nil : models.reduce(0) { $0 + $1.totalCents })
    }

    @available(*, deprecated, message: "Use init(from:warnings:)")
    public init(from snapshot: UsageSnapshot, warningThreshold: Double) {
        self.init(from: snapshot, warnings: .migrated(fromLegacy: warningThreshold))
    }
}

public enum WidgetSnapshotStore {
    /// macOS App Group form is `TEAMID.name` (see Stats.app). iOS-style `group.` is not in the widget profile.
    public static let appGroupID = "6998422DKP.com.jamesware.aimeter.shared"
    public static let legacyAppGroupID = "group.com.jamesware.aimeter.shared"
    /// Watch app ↔ Watch complications only. Never holds tokens.
    public static let watchAppGroupID = "group.com.jamesware.aimeter.watch"
    public static let filename = "widget-snapshot.json"
    public static let watchTransferKey = "widgetSnapshotJSON"
    private static let defaultsKey = "widgetSnapshotJSON"

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static var groupIDs: [String] {
        #if os(iOS)
        [legacyAppGroupID]
        #elseif os(watchOS)
        [watchAppGroupID]
        #else
        [appGroupID, legacyAppGroupID]
        #endif
    }

    private static var groupRoots: [URL] {
        var roots: [URL] = []
        var seen = Set<String>()
        for id in groupIDs {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                appendRoot(url, seen: &seen, into: &roots)
            }
            #if os(macOS)
            let home = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Group Containers", isDirectory: true)
                .appendingPathComponent(id, isDirectory: true)
            appendRoot(home, seen: &seen, into: &roots)
            #endif
        }
        return roots
    }

    private static func appendRoot(_ url: URL, seen: inout Set<String>, into roots: inout [URL]) {
        let path = url.standardizedFileURL.path
        if seen.insert(path).inserted {
            roots.append(url)
        }
    }

    private static let supportFolderName = "AIMeter"
    private static let legacySupportFolderName = "CursorUsageTracker"

    private static func supportFile(in root: URL, folder: String) -> URL {
        root
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(folder, isDirectory: true)
            .appendingPathComponent(filename)
    }

    private static var writeFiles: [URL] {
        var urls: [URL] = []
        for root in groupRoots {
            urls.append(supportFile(in: root, folder: supportFolderName))
            urls.append(root.appendingPathComponent(filename))
        }
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            urls.append(
                support
                    .appendingPathComponent(supportFolderName, isDirectory: true)
                    .appendingPathComponent(filename)
            )
        }
        return urls
    }

    private static var candidateFiles: [URL] {
        var urls = writeFiles
        for root in groupRoots {
            urls.append(supportFile(in: root, folder: legacySupportFolderName))
        }
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            urls.append(
                support
                    .appendingPathComponent(legacySupportFolderName, isDirectory: true)
                    .appendingPathComponent(filename)
            )
        }
        return urls
    }

    public static func data(from snapshot: WidgetSnapshot) throws -> Data {
        try JSONEncoder().encode(snapshot)
    }

    public static func snapshot(from data: Data) -> WidgetSnapshot? {
        decode(data)
    }

    public static func write(_ snapshot: WidgetSnapshot) throws {
        let data = try data(from: snapshot)
        #if os(watchOS)
        writeWatchData(data)
        return
        #endif

        for id in groupIDs {
            if let suite = UserDefaults(suiteName: id) {
                suite.set(data, forKey: defaultsKey)
                suite.synchronize()
            }
        }

        var lastError: Error?
        var wrote = false
        for url in writeFiles {
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

    public static func writeWatchLocal(_ snapshot: WidgetSnapshot) {
        guard let data = try? data(from: snapshot) else { return }
        writeWatchData(data)
    }

    public static func readWatchLocal() -> WidgetSnapshot? {
        if let data = UserDefaults(suiteName: watchAppGroupID)?.data(forKey: defaultsKey),
           let snap = decode(data)
        {
            return snap
        }
        if let data = UserDefaults.standard.data(forKey: defaultsKey), let snap = decode(data) {
            return snap
        }
        return nil
    }

    public static func read() -> WidgetSnapshot? {
        #if os(watchOS)
        return readWatchLocal()
        #endif
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

    private static func writeWatchData(_ data: Data) {
        if let suite = UserDefaults(suiteName: watchAppGroupID) {
            suite.set(data, forKey: defaultsKey)
            suite.synchronize()
        }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
