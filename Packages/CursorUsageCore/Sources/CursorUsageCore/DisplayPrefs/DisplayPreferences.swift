import Foundation

public struct DisplayPreferences: Codable, Sendable, Equatable {
    public var refreshIntervalMinutes: Int
    public var launchAtLogin: Bool
    public var showInMenuBar: Bool
    public var menuBarFormat: MenuBarFormat
    public var warningThresholdPercent: Double

    public var menuBar: SurfaceToggles
    public var popover: SurfaceToggles

    public enum MenuBarFormat: String, Codable, Sendable, CaseIterable {
        case compact
        case detailed
    }

    public struct SurfaceToggles: Codable, Sendable, Equatable {
        public var cursorModelsPercent: Bool
        public var otherModelsPercent: Bool
        public var totalPercent: Bool
        public var planSpend: Bool
        public var bonus: Bool
        public var onDemand: Bool
        public var daysRemaining: Bool
        public var burnRateEstimate: Bool

        public static let menuBarDefault = SurfaceToggles(
            cursorModelsPercent: true,
            otherModelsPercent: true,
            totalPercent: false,
            planSpend: false,
            bonus: false,
            onDemand: false,
            daysRemaining: false,
            burnRateEstimate: false
        )

        public static let popoverDefault = SurfaceToggles(
            cursorModelsPercent: true,
            otherModelsPercent: true,
            totalPercent: true,
            planSpend: true,
            bonus: true,
            onDemand: true,
            daysRemaining: true,
            burnRateEstimate: true
        )

        public init(
            cursorModelsPercent: Bool,
            otherModelsPercent: Bool,
            totalPercent: Bool,
            planSpend: Bool,
            bonus: Bool,
            onDemand: Bool,
            daysRemaining: Bool,
            burnRateEstimate: Bool
        ) {
            self.cursorModelsPercent = cursorModelsPercent
            self.otherModelsPercent = otherModelsPercent
            self.totalPercent = totalPercent
            self.planSpend = planSpend
            self.bonus = bonus
            self.onDemand = onDemand
            self.daysRemaining = daysRemaining
            self.burnRateEstimate = burnRateEstimate
        }
    }

    public static let `default` = DisplayPreferences(
        refreshIntervalMinutes: 5,
        launchAtLogin: false,
        showInMenuBar: true,
        menuBarFormat: .detailed,
        warningThresholdPercent: 95,
        menuBar: .menuBarDefault,
        popover: .popoverDefault
    )

    public init(
        refreshIntervalMinutes: Int,
        launchAtLogin: Bool,
        showInMenuBar: Bool,
        menuBarFormat: MenuBarFormat,
        warningThresholdPercent: Double,
        menuBar: SurfaceToggles,
        popover: SurfaceToggles
    ) {
        self.refreshIntervalMinutes = refreshIntervalMinutes
        self.launchAtLogin = launchAtLogin
        self.showInMenuBar = showInMenuBar
        self.menuBarFormat = menuBarFormat
        self.warningThresholdPercent = warningThresholdPercent
        self.menuBar = menuBar
        self.popover = popover
    }
}

public enum DisplayPreferenceStore {
    private static let key = "displayPreferences"

    public static func load(defaults: UserDefaults = .standard) -> DisplayPreferences {
        guard let data = defaults.data(forKey: key),
              let prefs = try? JSONDecoder().decode(DisplayPreferences.self, from: data)
        else {
            return .default
        }
        return prefs
    }

    public static func save(_ prefs: DisplayPreferences, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(prefs) {
            defaults.set(data, forKey: key)
        }
    }
}
