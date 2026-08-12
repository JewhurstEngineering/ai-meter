import Foundation

public struct DisplayPreferences: Codable, Sendable, Equatable {
    public var refreshIntervalMinutes: Int
    public var launchAtLogin: Bool
    public var showInMenuBar: Bool
    public var menuBarFormat: MenuBarFormat
    public var menuBarLabelStyle: MenuBarLabelStyle
    /// Menu bar red-dot threshold.
    public var warningThresholdPercent: Double
    /// Per-channel menu bar warning thresholds (independent levels).
    public var menuBarWarnings: MenuBarWarningThresholds
    public var notificationsEnabled: Bool
    /// Sorted unique percents (legacy multi-threshold chips; still honored if non-empty alongside channels).
    public var notificationThresholds: [Double]
    /// Per-channel notification enables — fire at each channel’s menu-bar warning level.
    public var notificationChannels: NotificationChannels
    /// Banner when a refresh fails with unauthorized / session expired (not intentional sign-out).
    public var notifyOnSessionExpired: Bool
    public var notificationContent: NotificationContent

    public var menuBar: SurfaceToggles
    public var popover: SurfaceToggles

    public enum MenuBarFormat: String, Codable, Sendable, CaseIterable {
        case compact
        case detailed
    }

    public enum MenuBarLabelStyle: String, Codable, Sendable, CaseIterable {
        case icons
        case shortWords
    }

    public struct MenuBarWarningThresholds: Codable, Sendable, Equatable {
        public var cursorModelsPercent: Double
        public var otherModelsPercent: Double
        /// Plan spend / included limit and on-demand spend vs limit (when a cap exists).
        public var onDemandAndLimitsPercent: Double
        /// Total included pool (menu bar + notifications).
        public var totalIncludedPercent: Double
        /// When on-demand is unlimited (no cap), warn at this spend amount (USD cents).
        public var onDemandUnlimitedAlertCents: Int

        public static let `default` = MenuBarWarningThresholds(
            cursorModelsPercent: 95,
            otherModelsPercent: 95,
            onDemandAndLimitsPercent: 95,
            totalIncludedPercent: 95,
            onDemandUnlimitedAlertCents: 5_000
        )

        public static let unlimitedSpendPresetsCents: [Int] = [
            1_000, 2_500, 5_000, 10_000, 25_000, 50_000, 100_000,
        ]

        public init(
            cursorModelsPercent: Double,
            otherModelsPercent: Double,
            onDemandAndLimitsPercent: Double,
            totalIncludedPercent: Double = 95,
            onDemandUnlimitedAlertCents: Int = 5_000
        ) {
            self.cursorModelsPercent = Self.clampPercent(cursorModelsPercent)
            self.otherModelsPercent = Self.clampPercent(otherModelsPercent)
            self.onDemandAndLimitsPercent = Self.clampPercent(onDemandAndLimitsPercent)
            self.totalIncludedPercent = Self.clampPercent(totalIncludedPercent)
            self.onDemandUnlimitedAlertCents = Self.clampCents(onDemandUnlimitedAlertCents)
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            cursorModelsPercent = Self.clampPercent(
                try c.decodeIfPresent(Double.self, forKey: .cursorModelsPercent) ?? 95
            )
            otherModelsPercent = Self.clampPercent(
                try c.decodeIfPresent(Double.self, forKey: .otherModelsPercent) ?? 95
            )
            onDemandAndLimitsPercent = Self.clampPercent(
                try c.decodeIfPresent(Double.self, forKey: .onDemandAndLimitsPercent) ?? 95
            )
            totalIncludedPercent = Self.clampPercent(
                try c.decodeIfPresent(Double.self, forKey: .totalIncludedPercent) ?? 95
            )
            onDemandUnlimitedAlertCents = Self.clampCents(
                try c.decodeIfPresent(Int.self, forKey: .onDemandUnlimitedAlertCents) ?? 5_000
            )
        }

        public static func clampPercent(_ value: Double) -> Double {
            min(100, max(50, value.rounded()))
        }

        /// Alias used by settings bindings.
        public static func clamp(_ value: Double) -> Double { clampPercent(value) }

        public static func clampCents(_ value: Int) -> Int {
            min(1_000_000, max(100, value))
        }

        public static func migrated(fromLegacy threshold: Double) -> MenuBarWarningThresholds {
            let v = clampPercent(threshold)
            return .init(
                cursorModelsPercent: v,
                otherModelsPercent: v,
                onDemandAndLimitsPercent: v,
                totalIncludedPercent: v
            )
        }
    }

    /// Which channels can fire a system notification when they hit their menu-bar warning level.
    public struct NotificationChannels: Codable, Sendable, Equatable {
        public var cursorModels: Bool
        public var otherModels: Bool
        public var onDemandAndLimits: Bool
        public var totalIncluded: Bool

        public static let `default` = NotificationChannels(
            cursorModels: true,
            otherModels: true,
            onDemandAndLimits: true,
            totalIncluded: false
        )

        public init(
            cursorModels: Bool,
            otherModels: Bool,
            onDemandAndLimits: Bool,
            totalIncluded: Bool
        ) {
            self.cursorModels = cursorModels
            self.otherModels = otherModels
            self.onDemandAndLimits = onDemandAndLimits
            self.totalIncluded = totalIncluded
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            cursorModels = try c.decodeIfPresent(Bool.self, forKey: .cursorModels) ?? true
            otherModels = try c.decodeIfPresent(Bool.self, forKey: .otherModels) ?? true
            onDemandAndLimits = try c.decodeIfPresent(Bool.self, forKey: .onDemandAndLimits) ?? true
            totalIncluded = try c.decodeIfPresent(Bool.self, forKey: .totalIncluded) ?? false
        }
    }

    public struct NotificationContent: Codable, Sendable, Equatable {
        public var includePoolPercent: Bool
        public var includePlanName: Bool
        public var includeSpend: Bool
        public var includeDaysRemaining: Bool
        public var playSound: Bool

        public static let `default` = NotificationContent(
            includePoolPercent: true,
            includePlanName: true,
            includeSpend: true,
            includeDaysRemaining: false,
            playSound: true
        )

        public init(
            includePoolPercent: Bool,
            includePlanName: Bool,
            includeSpend: Bool,
            includeDaysRemaining: Bool,
            playSound: Bool
        ) {
            self.includePoolPercent = includePoolPercent
            self.includePlanName = includePlanName
            self.includeSpend = includeSpend
            self.includeDaysRemaining = includeDaysRemaining
            self.playSound = playSound
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            includePoolPercent = try c.decodeIfPresent(Bool.self, forKey: .includePoolPercent) ?? true
            includePlanName = try c.decodeIfPresent(Bool.self, forKey: .includePlanName) ?? true
            includeSpend = try c.decodeIfPresent(Bool.self, forKey: .includeSpend) ?? true
            includeDaysRemaining = try c.decodeIfPresent(Bool.self, forKey: .includeDaysRemaining) ?? false
            playSound = try c.decodeIfPresent(Bool.self, forKey: .playSound) ?? true
        }
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
        /// Popover-only: per-model spend for the billing period.
        public var modelsThisPeriod: Bool

        public static let menuBarDefault = SurfaceToggles(
            cursorModelsPercent: true,
            otherModelsPercent: true,
            totalPercent: false,
            planSpend: false,
            bonus: false,
            onDemand: false,
            daysRemaining: false,
            burnRateEstimate: false,
            modelsThisPeriod: false
        )

        public static let popoverDefault = SurfaceToggles(
            cursorModelsPercent: true,
            otherModelsPercent: true,
            totalPercent: true,
            planSpend: true,
            bonus: true,
            onDemand: true,
            daysRemaining: true,
            burnRateEstimate: true,
            modelsThisPeriod: true
        )

        public init(
            cursorModelsPercent: Bool,
            otherModelsPercent: Bool,
            totalPercent: Bool,
            planSpend: Bool,
            bonus: Bool,
            onDemand: Bool,
            daysRemaining: Bool,
            burnRateEstimate: Bool,
            modelsThisPeriod: Bool = false
        ) {
            self.cursorModelsPercent = cursorModelsPercent
            self.otherModelsPercent = otherModelsPercent
            self.totalPercent = totalPercent
            self.planSpend = planSpend
            self.bonus = bonus
            self.onDemand = onDemand
            self.daysRemaining = daysRemaining
            self.burnRateEstimate = burnRateEstimate
            self.modelsThisPeriod = modelsThisPeriod
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            cursorModelsPercent = try c.decodeIfPresent(Bool.self, forKey: .cursorModelsPercent) ?? true
            otherModelsPercent = try c.decodeIfPresent(Bool.self, forKey: .otherModelsPercent) ?? true
            totalPercent = try c.decodeIfPresent(Bool.self, forKey: .totalPercent) ?? false
            planSpend = try c.decodeIfPresent(Bool.self, forKey: .planSpend) ?? false
            bonus = try c.decodeIfPresent(Bool.self, forKey: .bonus) ?? false
            onDemand = try c.decodeIfPresent(Bool.self, forKey: .onDemand) ?? false
            daysRemaining = try c.decodeIfPresent(Bool.self, forKey: .daysRemaining) ?? false
            burnRateEstimate = try c.decodeIfPresent(Bool.self, forKey: .burnRateEstimate) ?? false
            // Default on so upgraded installs get the popover section without a reset.
            modelsThisPeriod = try c.decodeIfPresent(Bool.self, forKey: .modelsThisPeriod) ?? true
        }
    }

    public static let presetNotificationThresholds: [Double] = [50, 75, 80, 85, 90, 95, 100]

    public static let `default` = DisplayPreferences(
        refreshIntervalMinutes: 5,
        launchAtLogin: false,
        showInMenuBar: true,
        menuBarFormat: .detailed,
        menuBarLabelStyle: .icons,
        warningThresholdPercent: 95,
        menuBarWarnings: .default,
        notificationsEnabled: false,
        notificationThresholds: [85, 95],
        notificationChannels: .default,
        notifyOnSessionExpired: true,
        notificationContent: .default,
        menuBar: .menuBarDefault,
        popover: .popoverDefault
    )

    public init(
        refreshIntervalMinutes: Int,
        launchAtLogin: Bool,
        showInMenuBar: Bool,
        menuBarFormat: MenuBarFormat,
        menuBarLabelStyle: MenuBarLabelStyle = .icons,
        warningThresholdPercent: Double,
        menuBarWarnings: MenuBarWarningThresholds = .default,
        notificationsEnabled: Bool = false,
        notificationThresholds: [Double] = [85, 95],
        notificationChannels: NotificationChannels = .default,
        notifyOnSessionExpired: Bool = true,
        notificationContent: NotificationContent = .default,
        menuBar: SurfaceToggles,
        popover: SurfaceToggles
    ) {
        self.refreshIntervalMinutes = refreshIntervalMinutes
        self.launchAtLogin = launchAtLogin
        self.showInMenuBar = showInMenuBar
        self.menuBarFormat = menuBarFormat
        self.menuBarLabelStyle = menuBarLabelStyle
        self.warningThresholdPercent = warningThresholdPercent
        self.menuBarWarnings = menuBarWarnings
        self.notificationsEnabled = notificationsEnabled
        self.notificationThresholds = Self.normalizeThresholds(notificationThresholds)
        self.notificationChannels = notificationChannels
        self.notifyOnSessionExpired = notifyOnSessionExpired
        self.notificationContent = notificationContent
        self.menuBar = menuBar
        self.popover = popover
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        refreshIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .refreshIntervalMinutes) ?? 5
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        showInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showInMenuBar) ?? true
        menuBarFormat = try c.decodeIfPresent(MenuBarFormat.self, forKey: .menuBarFormat) ?? .detailed
        menuBarLabelStyle = try c.decodeIfPresent(MenuBarLabelStyle.self, forKey: .menuBarLabelStyle) ?? .icons
        let legacyWarning = try c.decodeIfPresent(Double.self, forKey: .warningThresholdPercent) ?? 95
        warningThresholdPercent = legacyWarning
        if let warnings = try c.decodeIfPresent(MenuBarWarningThresholds.self, forKey: .menuBarWarnings) {
            menuBarWarnings = warnings
        } else {
            menuBarWarnings = .migrated(fromLegacy: legacyWarning)
        }
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false
        notificationThresholds = Self.normalizeThresholds(
            try c.decodeIfPresent([Double].self, forKey: .notificationThresholds) ?? [85, 95]
        )
        notificationChannels = try c.decodeIfPresent(NotificationChannels.self, forKey: .notificationChannels) ?? .default
        notifyOnSessionExpired = try c.decodeIfPresent(Bool.self, forKey: .notifyOnSessionExpired) ?? true
        notificationContent = try c.decodeIfPresent(NotificationContent.self, forKey: .notificationContent) ?? .default
        menuBar = try c.decodeIfPresent(SurfaceToggles.self, forKey: .menuBar) ?? .menuBarDefault
        popover = try c.decodeIfPresent(SurfaceToggles.self, forKey: .popover) ?? .popoverDefault
    }

    public static func normalizeThresholds(_ values: [Double]) -> [Double] {
        Array(Set(values.map { min(100, max(1, $0.rounded())) })).sorted()
    }

    public mutating func toggleNotificationThreshold(_ value: Double) {
        var set = Set(notificationThresholds)
        let v = min(100, max(1, value.rounded()))
        if set.contains(v) {
            set.remove(v)
        } else {
            set.insert(v)
        }
        notificationThresholds = Array(set).sorted()
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
