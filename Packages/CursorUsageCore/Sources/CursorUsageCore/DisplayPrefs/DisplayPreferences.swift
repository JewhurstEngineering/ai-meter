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
    /// How multiple saved sessions appear in the menu bar.
    public var menuBarAccountMode: MenuBarAccountMode
    /// Settings + popover chrome: follow macOS, or lock light/dark.
    public var appearanceMode: AppearanceMode
    /// Color language for pools, tints, and warnings.
    public var colorTheme: ColorTheme
    /// Four metric colors used when `colorTheme == .custom`.
    public var customThemeColors: CustomThemeColors
    /// Settings + popover type size (not macOS screen zoom).
    public var interfaceSize: InterfaceSize
    /// Replaces theme accents with a palette that stays distinct for this vision type.
    public var colorVision: ColorVision
    /// Hatch / dots on progress bars so metrics are not color-only.
    public var distinguishWithoutColor: Bool
    /// Stronger borders and fills in Settings and the popover.
    public var highContrast: Bool
    /// Warning channels the user cleared. Re-arms when that channel drops back under its alert.
    public var snoozedWarningChannels: [String]

    public enum AppearanceMode: String, Codable, Sendable, CaseIterable {
        case system
        case light
        case dark

        public var title: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
    }

    public struct ThemeSwatch: Codable, Sendable, Equatable {
        public var red: Double
        public var green: Double
        public var blue: Double

        public init(red: Double, green: Double, blue: Double) {
            self.red = Self.clamp(red)
            self.green = Self.clamp(green)
            self.blue = Self.clamp(blue)
        }

        /// `#RRGGBB` or `RRGGBB`.
        public init(hex: String) {
            var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            if s.hasPrefix("#") { s.removeFirst() }
            guard s.count == 6, let v = UInt32(s, radix: 16) else {
                self.init(red: 0.5, green: 0.5, blue: 0.5)
                return
            }
            self.init(
                red: Double((v >> 16) & 0xFF) / 255,
                green: Double((v >> 8) & 0xFF) / 255,
                blue: Double(v & 0xFF) / 255
            )
        }

        private static func clamp(_ v: Double) -> Double { min(1, max(0, v)) }
    }

    public struct CustomThemeColors: Codable, Sendable, Equatable {
        public var cursorModels: ThemeSwatch
        public var otherModels: ThemeSwatch
        public var total: ThemeSwatch
        public var spend: ThemeSwatch

        /// Original app accents (blue / purple / teal / pine).
        public static let `default` = CustomThemeColors(
            cursorModels: ThemeSwatch(red: 0.22, green: 0.48, blue: 0.86),
            otherModels: ThemeSwatch(red: 0.55, green: 0.35, blue: 0.82),
            total: ThemeSwatch(red: 0.20, green: 0.55, blue: 0.58),
            spend: ThemeSwatch(red: 0.15, green: 0.45, blue: 0.40)
        )

        public init(
            cursorModels: ThemeSwatch,
            otherModels: ThemeSwatch,
            total: ThemeSwatch,
            spend: ThemeSwatch
        ) {
            self.cursorModels = cursorModels
            self.otherModels = otherModels
            self.total = total
            self.spend = spend
        }
    }

    public enum ColorTheme: String, Codable, Sendable, CaseIterable, Identifiable {
        case original
        case cursor
        case system
        case ink
        case harbor
        case forest
        case tokyoNight
        case catppuccin
        case dracula
        case nord
        case solarized
        case oneDark
        case gruvbox
        case monokai
        case nightOwl
        case synthwave
        case ayu
        case github
        case custom

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .original: return "Original"
            case .cursor: return "Cursor"
            case .system: return "macOS"
            case .ink: return "Ink"
            case .harbor: return "Harbor"
            case .forest: return "Forest"
            case .tokyoNight: return "Tokyo Night"
            case .catppuccin: return "Catppuccin"
            case .dracula: return "Dracula"
            case .nord: return "Nord"
            case .solarized: return "Solarized"
            case .oneDark: return "One Dark"
            case .gruvbox: return "Gruvbox"
            case .monokai: return "Monokai"
            case .nightOwl: return "Night Owl"
            case .synthwave: return "SynthWave ’84"
            case .ayu: return "Ayu"
            case .github: return "GitHub"
            case .custom: return "Custom"
            }
        }

        public var subtitle: String {
            switch self {
            case .original: return "The blue / purple / teal we shipped with"
            case .cursor: return "Zinc and warm paper, like the IDE"
            case .system: return "Your accent color and system greens"
            case .ink: return "High-contrast print, almost no hue"
            case .harbor: return "Slate and copper"
            case .forest: return "Moss, bark, cream"
            case .tokyoNight: return "Midnight neon — cyan, pink, gold"
            case .catppuccin: return "Soothing pastels, mocha / latte"
            case .dracula: return "Purple canvas, neon accents"
            case .nord: return "Arctic frost and aurora"
            case .solarized: return "Precision teal-gray contrast"
            case .oneDark: return "Atom’s chalky dark slate"
            case .gruvbox: return "Warm sand, rust, and olive"
            case .monokai: return "Classic pink, cyan, and lime"
            case .nightOwl: return "Navy night, readable lavenders"
            case .synthwave: return "Retrowave pinks and laser green"
            case .ayu: return "Warm gold on near-black iron"
            case .github: return "github.com dark / light"
            case .custom: return "Pick the four metric colors"
            }
        }
    }

    public enum InterfaceSize: String, Codable, Sendable, CaseIterable, Identifiable {
        case defaultSize = "default"
        case large
        case extraLarge

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .defaultSize: return "Default"
            case .large: return "Large"
            case .extraLarge: return "Extra Large"
            }
        }
    }

    public enum ColorVision: String, Codable, Sendable, CaseIterable, Identifiable {
        case typical
        case deuteranopia
        case protanopia
        case tritanopia
        case monochrome

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .typical: return "Typical"
            case .deuteranopia: return "Red–green (deuteranopia)"
            case .protanopia: return "Red–green (protanopia)"
            case .tritanopia: return "Blue–yellow (tritanopia)"
            case .monochrome: return "Monochrome"
            }
        }

        public var subtitle: String {
            switch self {
            case .typical: return "Your Theme colors as-is"
            case .deuteranopia: return "Okabe–Ito blues, orange, and yellow"
            case .protanopia: return "Blue, yellow, and gray — avoids dim reds"
            case .tritanopia: return "Vermillion, purple, and green"
            case .monochrome: return "Lightness only — use with patterns"
            }
        }
    }

    public enum MenuBarFormat: String, Codable, Sendable, CaseIterable {
        case compact
        case detailed
    }

    public enum MenuBarLabelStyle: String, Codable, Sendable, CaseIterable {
        case icons
        case shortWords
    }

    public enum MenuBarAccountMode: String, Codable, Sendable, CaseIterable {
        case activeOnly
        case combined
        case separateItems

        public var title: String {
            switch self {
            case .activeOnly: return "Active"
            case .combined: return "Combined"
            case .separateItems: return "Separate"
            }
        }
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
            min(100, max(1, value.rounded()))
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
        popover: .popoverDefault,
        menuBarAccountMode: .activeOnly,
        appearanceMode: .system,
        colorTheme: .cursor,
        customThemeColors: .default,
        interfaceSize: .defaultSize,
        colorVision: .typical,
        distinguishWithoutColor: false,
        highContrast: false,
        snoozedWarningChannels: []
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
        popover: SurfaceToggles,
        menuBarAccountMode: MenuBarAccountMode = .activeOnly,
        appearanceMode: AppearanceMode = .system,
        colorTheme: ColorTheme = .cursor,
        customThemeColors: CustomThemeColors = .default,
        interfaceSize: InterfaceSize = .defaultSize,
        colorVision: ColorVision = .typical,
        distinguishWithoutColor: Bool = false,
        highContrast: Bool = false,
        snoozedWarningChannels: [String] = []
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
        self.menuBarAccountMode = menuBarAccountMode
        self.appearanceMode = appearanceMode
        self.colorTheme = colorTheme
        self.customThemeColors = customThemeColors
        self.interfaceSize = interfaceSize
        self.colorVision = colorVision
        self.distinguishWithoutColor = distinguishWithoutColor
        self.highContrast = highContrast
        self.snoozedWarningChannels = snoozedWarningChannels
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
        menuBarAccountMode = try c.decodeIfPresent(MenuBarAccountMode.self, forKey: .menuBarAccountMode) ?? .activeOnly
        appearanceMode = try c.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .system
        colorTheme = try c.decodeIfPresent(ColorTheme.self, forKey: .colorTheme) ?? .cursor
        customThemeColors = try c.decodeIfPresent(CustomThemeColors.self, forKey: .customThemeColors) ?? .default
        interfaceSize = try c.decodeIfPresent(InterfaceSize.self, forKey: .interfaceSize) ?? .defaultSize
        colorVision = try c.decodeIfPresent(ColorVision.self, forKey: .colorVision) ?? .typical
        distinguishWithoutColor = try c.decodeIfPresent(Bool.self, forKey: .distinguishWithoutColor) ?? false
        highContrast = try c.decodeIfPresent(Bool.self, forKey: .highContrast) ?? false
        snoozedWarningChannels = try c.decodeIfPresent([String].self, forKey: .snoozedWarningChannels) ?? []
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

    public mutating func snoozeWarning(_ channel: UsageSnapshot.WarningChannel) {
        let key = channel.rawValue
        if !snoozedWarningChannels.contains(key) {
            snoozedWarningChannels.append(key)
        }
    }

    public mutating func snoozeWarnings(_ channels: [UsageSnapshot.WarningChannel]) {
        for channel in channels {
            snoozeWarning(channel)
        }
    }

    /// Drop snoozes for channels that are no longer over their alert (so they can fire again).
    public mutating func pruneSnoozedWarnings(stillTriggered: Set<String>) {
        snoozedWarningChannels = snoozedWarningChannels.filter { stillTriggered.contains($0) }
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
