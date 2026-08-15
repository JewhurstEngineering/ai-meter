import SwiftUI
import AIMeterCore
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct ThemePalette: Equatable {
    var tint: Color
    var cursorModels: Color
    var otherModels: Color
    var total: Color
    var spend: Color
    var ok: Color
    var warn: Color
    var danger: Color

    func poolColor(percent: Double) -> Color {
        switch percent {
        case ..<60: return ok
        case ..<85: return warn
        default: return danger
        }
    }

    func color(forPool title: String, percent: Double) -> Color {
        color(forRole: role(forPoolTitle: title), percent: percent)
    }

    func color(forWindow window: QuotaWindow, percent: Double) -> Color {
        color(forRole: window.role, percent: percent)
    }

    func color(forRole role: QuotaWindowRole, percent: Double) -> Color {
        if percent >= 85 { return poolColor(percent: percent) }
        switch role {
        case .cursorModels, .session: return cursorModels
        case .otherModels, .weekly: return otherModels
        case .totalIncluded: return total
        case .extra: return spend
        }
    }

    private func role(forPoolTitle title: String) -> QuotaWindowRole {
        switch title {
        case "Cursor Models": return .cursorModels
        case "Other Models": return .otherModels
        case "Total included", "Total Included", "Total": return .totalIncluded
        case "5-hour", "Session": return .session
        case "7-day", "Weekly": return .weekly
        default: return .extra
        }
    }

    var swatches: [Color] { [cursorModels, otherModels, total, spend] }

    func adapted(
        for vision: DisplayPreferences.ColorVision,
        highContrast _: Bool,
        scheme: ColorScheme
    ) -> ThemePalette {
        let dark = scheme == .dark
        switch vision {
        case .typical:
            return self
        case .deuteranopia:
            return .cvdDeuteranopia
        case .protanopia:
            return .cvdProtanopia
        case .tritanopia:
            return .cvdTritanopia
        case .monochrome:
            return dark ? .monoDark : .monoLight
        }
    }

    static func resolved(_ preferences: DisplayPreferences, scheme: ColorScheme) -> ThemePalette {
        resolved(preferences.colorTheme, scheme: scheme, custom: preferences.customThemeColors)
    }

    static func resolved(
        _ theme: DisplayPreferences.ColorTheme,
        scheme: ColorScheme,
        custom: DisplayPreferences.CustomThemeColors = .default
    ) -> ThemePalette {
        let dark = scheme == .dark
        switch theme {
        case .original: return .original
        case .cursor: return dark ? .cursorDark : .cursorLight
        case .system: return .systemAdaptive
        case .ink: return dark ? .inkDark : .inkLight
        case .harbor: return dark ? .harborDark : .harborLight
        case .forest: return dark ? .forestDark : .forestLight
        case .tokyoNight: return dark ? .tokyoNightDark : .tokyoNightLight
        case .catppuccin: return dark ? .catppuccinMocha : .catppuccinLatte
        case .dracula: return .dracula
        case .nord: return dark ? .nordDark : .nordLight
        case .solarized: return dark ? .solarizedDark : .solarizedLight
        case .oneDark: return dark ? .oneDark : .oneLight
        case .gruvbox: return dark ? .gruvboxDark : .gruvboxLight
        case .monokai: return .monokai
        case .nightOwl: return dark ? .nightOwlDark : .nightOwlLight
        case .synthwave: return .synthwave
        case .ayu: return dark ? .ayuDark : .ayuLight
        case .github: return dark ? .githubDark : .githubLight
        case .custom: return .fromCustom(custom)
        }
    }

    private static func fromCustom(_ c: DisplayPreferences.CustomThemeColors) -> ThemePalette {
        let cursor = c.cursorModels.color
        let other = c.otherModels.color
        let total = c.total.color
        let spend = c.spend.color
        return ThemePalette(
            tint: cursor,
            cursorModels: cursor,
            otherModels: other,
            total: total,
            spend: spend,
            ok: spend,
            warn: other,
            danger: Color(red: 0.86, green: 0.28, blue: 0.30)
        )
    }

    // MARK: - Original (shipped 0.1.x)

    private static let original = pack(
        cursor: (0.22, 0.48, 0.86),
        other: (0.55, 0.35, 0.82),
        total: (0.20, 0.55, 0.58),
        spend: (0.15, 0.45, 0.40),
        ok: (0.18, 0.62, 0.48),
        warn: (0.90, 0.62, 0.16),
        danger: (0.86, 0.28, 0.30)
    )

    // MARK: - Cursor / ink / harbor / forest

    private static let cursorDark = pack(
        cursor: (0.84, 0.81, 0.74), other: (0.52, 0.58, 0.64),
        total: (0.58, 0.62, 0.54), spend: (0.70, 0.66, 0.56),
        ok: (0.52, 0.64, 0.56), warn: (0.78, 0.58, 0.34), danger: (0.72, 0.40, 0.34),
        tint: (0.86, 0.84, 0.78)
    )
    private static let cursorLight = pack(
        cursor: (0.22, 0.20, 0.17), other: (0.32, 0.40, 0.48),
        total: (0.34, 0.42, 0.36), spend: (0.30, 0.28, 0.22),
        ok: (0.26, 0.46, 0.36), warn: (0.70, 0.46, 0.16), danger: (0.66, 0.28, 0.22),
        tint: (0.16, 0.15, 0.13)
    )

    private static let systemAdaptive = ThemePalette(
        tint: Color.accentColor,
        cursorModels: Color.accentColor,
        otherModels: Color.gray,
        total: Color.teal,
        spend: Color.brown,
        ok: Color.green,
        warn: Color.orange,
        danger: Color.red
    )

    private static let inkDark = pack(
        cursor: (0.90, 0.90, 0.88), other: (0.62, 0.62, 0.60),
        total: (0.78, 0.78, 0.76), spend: (0.84, 0.84, 0.82),
        ok: (0.72, 0.72, 0.70), warn: (0.82, 0.82, 0.78), danger: (0.78, 0.28, 0.24)
    )
    private static let inkLight = pack(
        cursor: (0.10, 0.10, 0.10), other: (0.38, 0.38, 0.38),
        total: (0.22, 0.22, 0.22), spend: (0.16, 0.16, 0.16),
        ok: (0.20, 0.20, 0.20), warn: (0.28, 0.28, 0.28), danger: (0.72, 0.12, 0.10)
    )

    private static let harborDark = pack(
        cursor: (0.62, 0.70, 0.76), other: (0.78, 0.52, 0.36),
        total: (0.48, 0.56, 0.60), spend: (0.72, 0.58, 0.42),
        ok: (0.46, 0.62, 0.58), warn: (0.82, 0.58, 0.32), danger: (0.74, 0.36, 0.30)
    )
    private static let harborLight = pack(
        cursor: (0.28, 0.38, 0.46), other: (0.62, 0.34, 0.20),
        total: (0.32, 0.40, 0.44), spend: (0.48, 0.32, 0.20),
        ok: (0.22, 0.44, 0.40), warn: (0.72, 0.42, 0.14), danger: (0.64, 0.22, 0.18)
    )

    private static let forestDark = pack(
        cursor: (0.58, 0.66, 0.48), other: (0.55, 0.46, 0.36),
        total: (0.48, 0.58, 0.50), spend: (0.70, 0.64, 0.48),
        ok: (0.50, 0.64, 0.46), warn: (0.76, 0.60, 0.34), danger: (0.70, 0.38, 0.30)
    )
    private static let forestLight = pack(
        cursor: (0.30, 0.42, 0.26), other: (0.42, 0.32, 0.22),
        total: (0.28, 0.40, 0.34), spend: (0.40, 0.34, 0.22),
        ok: (0.26, 0.46, 0.30), warn: (0.66, 0.44, 0.16), danger: (0.62, 0.26, 0.20)
    )

    // MARK: - Editor palettes

    private static let tokyoNightDark = hexPack(
        cursor: "7ad5ff", other: "bb9af7", total: "f7768e", spend: "e0af68",
        ok: "9ece6a", warn: "e0af68", danger: "f7768e", tint: "7ad5ff"
    )
    private static let tokyoNightLight = hexPack(
        cursor: "0d9bd1", other: "7a5af5", total: "d14d72", spend: "b8860b",
        ok: "3d8b40", warn: "b8860b", danger: "d14d72", tint: "0d9bd1"
    )

    private static let catppuccinMocha = hexPack(
        cursor: "74c7ec", other: "cba6f7", total: "f2cdcd", spend: "a6e3a1",
        ok: "a6e3a1", warn: "f9e2af", danger: "f38ba8", tint: "cba6f7"
    )
    private static let catppuccinLatte = hexPack(
        cursor: "209fb5", other: "8839ef", total: "ea76cb", spend: "40a02b",
        ok: "40a02b", warn: "df8e1d", danger: "d20f39", tint: "8839ef"
    )

    private static let dracula = hexPack(
        cursor: "8BE9FD", other: "FF79C6", total: "BD93F9", spend: "50FA7B",
        ok: "50FA7B", warn: "F1FA8C", danger: "FF5555", tint: "BD93F9"
    )

    private static let nordDark = hexPack(
        cursor: "81a1c1", other: "88c0d0", total: "5e81ac", spend: "ebcb8b",
        ok: "a3be8c", warn: "ebcb8b", danger: "bf616a", tint: "88c0d0"
    )
    private static let nordLight = hexPack(
        cursor: "5e81ac", other: "088f9e", total: "4c566a", spend: "b48ead",
        ok: "a3be8c", warn: "d08770", danger: "bf616a", tint: "5e81ac"
    )

    private static let solarizedDark = hexPack(
        cursor: "268bd2", other: "cb4b16", total: "2aa198", spend: "b58900",
        ok: "859900", warn: "b58900", danger: "dc322f", tint: "268bd2"
    )
    private static let solarizedLight = hexPack(
        cursor: "268bd2", other: "cb4b16", total: "2aa198", spend: "b58900",
        ok: "859900", warn: "b58900", danger: "dc322f", tint: "073642"
    )

    private static let oneDark = hexPack(
        cursor: "61afef", other: "c678dd", total: "56b6c2", spend: "98c379",
        ok: "98c379", warn: "e5c07b", danger: "e06c75", tint: "61afef"
    )
    private static let oneLight = hexPack(
        cursor: "4078f2", other: "a626a4", total: "0184bc", spend: "50a14f",
        ok: "50a14f", warn: "c18401", danger: "e45649", tint: "4078f2"
    )

    private static let gruvboxDark = hexPack(
        cursor: "83a598", other: "fe8019", total: "b8bb26", spend: "d79921",
        ok: "b8bb26", warn: "fe8019", danger: "fb4934", tint: "fe8019"
    )
    private static let gruvboxLight = hexPack(
        cursor: "076678", other: "af3a03", total: "79740e", spend: "b57614",
        ok: "79740e", warn: "af3a03", danger: "9d0006", tint: "af3a03"
    )

    private static let monokai = hexPack(
        cursor: "66d9ef", other: "f92672", total: "ae81ff", spend: "a6e22e",
        ok: "a6e22e", warn: "fd971f", danger: "f92672", tint: "f92672"
    )

    private static let nightOwlDark = hexPack(
        cursor: "82aaff", other: "c792ea", total: "7fdbca", spend: "ecc48d",
        ok: "addb67", warn: "ecc48d", danger: "ef5350", tint: "82aaff"
    )
    private static let nightOwlLight = hexPack(
        cursor: "4876d6", other: "994cc3", total: "08916a", spend: "c96765",
        ok: "2aa298", warn: "e0af22", danger: "de3d3b", tint: "4876d6"
    )

    private static let synthwave = hexPack(
        cursor: "2de2e6", other: "f92aad", total: "72f1b8", spend: "f97e72",
        ok: "72f1b8", warn: "fede5d", danger: "f92aad", tint: "f92aad"
    )

    private static let ayuDark = hexPack(
        cursor: "36a3d9", other: "f29718", total: "f2594b", spend: "e6b450",
        ok: "c2d94c", warn: "e6b450", danger: "f2594b", tint: "e6b450"
    )
    private static let ayuLight = hexPack(
        cursor: "399ee6", other: "fa8d3e", total: "f07171", spend: "e6b450",
        ok: "86b300", warn: "fa8d3e", danger: "f07171", tint: "fa8d3e"
    )

    private static let githubDark = hexPack(
        cursor: "58a6ff", other: "d2a8ff", total: "ff7b72", spend: "7ee787",
        ok: "7ee787", warn: "d29922", danger: "ff7b72", tint: "58a6ff"
    )
    private static let githubLight = hexPack(
        cursor: "0969da", other: "8250df", total: "cf222e", spend: "1a7f37",
        ok: "1a7f37", warn: "9a6700", danger: "cf222e", tint: "0969da"
    )

    /// Okabe–Ito: blue / orange / sky / purple — distinct under deuteranopia.
    private static let cvdDeuteranopia = hexPack(
        cursor: "0072B2", other: "E69F00", total: "56B4E9", spend: "CC79A7",
        ok: "009E73", warn: "F0E442", danger: "D55E00", tint: "0072B2"
    )
    /// Protanopia: skip vermillion/orange pairs; yellow + blue + gray.
    private static let cvdProtanopia = hexPack(
        cursor: "0072B2", other: "F0E442", total: "56B4E9", spend: "999999",
        ok: "009E73", warn: "F0E442", danger: "000000", tint: "0072B2"
    )
    /// Tritanopia: vermillion / purple / green, no blue–yellow pair.
    private static let cvdTritanopia = hexPack(
        cursor: "D55E00", other: "CC79A7", total: "009E73", spend: "000000",
        ok: "009E73", warn: "E69F00", danger: "000000", tint: "D55E00"
    )
    private static let monoDark = pack(
        cursor: (0.92, 0.92, 0.92), other: (0.58, 0.58, 0.58),
        total: (0.78, 0.78, 0.78), spend: (0.48, 0.48, 0.48),
        ok: (0.82, 0.82, 0.82), warn: (0.62, 0.62, 0.62), danger: (1, 1, 1)
    )
    private static let monoLight = pack(
        cursor: (0.10, 0.10, 0.10), other: (0.42, 0.42, 0.42),
        total: (0.22, 0.22, 0.22), spend: (0.50, 0.50, 0.50),
        ok: (0.18, 0.18, 0.18), warn: (0.38, 0.38, 0.38), danger: (0.05, 0.05, 0.05)
    )

    // MARK: - Helpers

    private static func pack(
        cursor: (Double, Double, Double),
        other: (Double, Double, Double),
        total: (Double, Double, Double),
        spend: (Double, Double, Double),
        ok: (Double, Double, Double),
        warn: (Double, Double, Double),
        danger: (Double, Double, Double),
        tint: (Double, Double, Double)? = nil
    ) -> ThemePalette {
        let t = tint ?? cursor
        return ThemePalette(
            tint: rgb(t),
            cursorModels: rgb(cursor),
            otherModels: rgb(other),
            total: rgb(total),
            spend: rgb(spend),
            ok: rgb(ok),
            warn: rgb(warn),
            danger: rgb(danger)
        )
    }

    private static func hexPack(
        cursor: String, other: String, total: String, spend: String,
        ok: String, warn: String, danger: String, tint: String? = nil
    ) -> ThemePalette {
        ThemePalette(
            tint: hex(tint ?? cursor),
            cursorModels: hex(cursor),
            otherModels: hex(other),
            total: hex(total),
            spend: hex(spend),
            ok: hex(ok),
            warn: hex(warn),
            danger: hex(danger)
        )
    }

    private static func rgb(_ t: (Double, Double, Double)) -> Color {
        Color(red: t.0, green: t.1, blue: t.2)
    }

    private static func hex(_ hex: String) -> Color {
        DisplayPreferences.ThemeSwatch(hex: hex).color
    }
}

extension DisplayPreferences.ThemeSwatch {
    var color: Color { Color(red: red, green: green, blue: blue) }

    init(_ color: Color) {
        #if os(macOS)
        let ns = NSColor(color)
        let rgb = ns.usingColorSpace(.sRGB) ?? ns
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(red: Double(r), green: Double(g), blue: Double(b))
        #elseif os(iOS)
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(red: Double(r), green: Double(g), blue: Double(b))
        #else
        self.init(red: 0.5, green: 0.5, blue: 0.5)
        #endif
    }
}

private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue = ThemePalette.resolved(.cursor, scheme: .light)
}

extension EnvironmentValues {
    var appTheme: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }

    var appUsePatterns: Bool {
        get { self[UsePatternsKey.self] }
        set { self[UsePatternsKey.self] = newValue }
    }

    var appHighContrast: Bool {
        get { self[HighContrastKey.self] }
        set { self[HighContrastKey.self] = newValue }
    }

    var appScale: CGFloat {
        get { self[AppScaleKey.self] }
        set { self[AppScaleKey.self] = newValue }
    }

    var appTextScale: CGFloat {
        get { self[AppTextScaleKey.self] }
        set { self[AppTextScaleKey.self] = newValue }
    }
}

private struct UsePatternsKey: EnvironmentKey {
    static let defaultValue = false
}

private struct HighContrastKey: EnvironmentKey {
    static let defaultValue = false
}

private struct AppScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

private struct AppTextScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

struct AppThemed<Content: View>: View {
    let preferences: DisplayPreferences
    @ViewBuilder var content: () -> Content
    @Environment(\.colorScheme) private var systemScheme
    #if os(macOS)
    @ObservedObject private var system = SystemAppearanceMonitor.shared
    #endif

    var body: some View {
        #if os(macOS)
        let systemIsDark = system.isDark
        #else
        let systemIsDark = systemScheme == .dark
        #endif
        let scheme = preferences.appearanceMode.colorScheme(systemIsDark: systemIsDark)
        let palette = ThemePalette.resolved(preferences, scheme: scheme)
            .adapted(
                for: preferences.colorVision,
                highContrast: preferences.highContrast,
                scheme: scheme
            )
        let themed = content()
            .environment(\.appTheme, palette)
            .environment(\.colorScheme, scheme)
            .environment(\.appUsePatterns, preferences.distinguishWithoutColor || preferences.colorVision != .typical)
            .environment(\.appHighContrast, preferences.highContrast)
            .environment(\.appScale, preferences.interfaceSize.scale)
            .environment(\.appTextScale, preferences.textSize.textScale)
            .preferredColorScheme(scheme)
            .tint(palette.tint)
        themed
            .dynamicTypeSize(preferences.textSize.dynamicTypeSize)
            #if os(macOS)
            .background(WindowAppearanceBridge(appearance: preferences.appearanceMode.nsAppearance))
            #endif
    }
}

#if os(macOS)
/// Follows macOS light/dark without setting `NSApp.appearance` (that would tint the menu bar).
@MainActor
final class SystemAppearanceMonitor: ObservableObject {
    static let shared = SystemAppearanceMonitor()

    @Published private(set) var isDark: Bool
    private var observation: NSKeyValueObservation?

    private init() {
        isDark = Self.read()
        observation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            let dark = Self.read()
            DispatchQueue.main.async { self?.isDark = dark }
        }
    }

    static func read() -> Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

enum WindowAppearanceApplier {
    /// Settings chrome + content. Skips the status item. Does not set `NSApp.appearance`.
    static func apply(_ appearance: NSAppearance?) {
        for window in NSApp.windows where shouldTheme(window) {
            apply(appearance, to: window)
        }
    }

    static func apply(_ appearance: NSAppearance?, to window: NSWindow) {
        window.appearance = appearance
        if let content = window.contentView {
            apply(appearance, to: content)
        }
        window.contentView?.superview?.appearance = appearance
    }

    private static func apply(_ appearance: NSAppearance?, to view: NSView) {
        view.appearance = appearance
        for sub in view.subviews {
            apply(appearance, to: sub)
        }
    }

    static func shouldTheme(_ window: NSWindow) -> Bool {
        if window.level == .statusBar { return false }
        if window.styleMask.contains(.nonactivatingPanel) { return false }
        return window.styleMask.contains(.titled)
    }

    /// Restore a usable Settings size and allow the user to resize it.
    /// SwiftUI Settings often sets contentMinSize == contentMaxSize, which makes
    /// `.resizable` a no-op even when the style mask looks right.
    static func configureChrome(scale: CGFloat) {
        let s = max(scale, 0.5)
        let minContent = NSSize(width: 800, height: 520)
        let idealContent = NSSize(width: (960 * s).rounded(), height: (680 * s).rounded())
        for window in NSApp.windows where shouldTheme(window) {
            unlockResize(window, minContent: minContent)
            window.setContentSize(idealContent)
        }
    }

    static func unlockResize(_ window: NSWindow, minContent: NSSize = NSSize(width: 800, height: 520)) {
        if !window.styleMask.contains(.resizable) {
            window.styleMask.insert([.titled, .closable, .miniaturizable, .resizable])
        }
        if window.contentMaxSize.width < 10_000 || window.contentMaxSize.height < 10_000 {
            window.contentMaxSize = NSSize(width: 12_000, height: 12_000)
            window.maxSize = NSSize(width: 12_000, height: 12_000)
        }
        if abs(window.contentMinSize.width - minContent.width) > 1
            || abs(window.contentMinSize.height - minContent.height) > 1
        {
            window.contentMinSize = minContent
            window.minSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: minContent)).size
        }
        window.standardWindowButton(.zoomButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isEnabled = true
    }
}

/// Keeps re-applying resize unlock; SwiftUI Settings resets contentMaxSize on layout.
struct SettingsResizeUnlock: NSViewRepresentable {
    func makeNSView(context: Context) -> SettingsResizeUnlockView {
        SettingsResizeUnlockView()
    }

    func updateNSView(_ nsView: SettingsResizeUnlockView, context: Context) {
        nsView.unlock()
    }
}

final class SettingsResizeUnlockView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        unlock()
        DispatchQueue.main.async { [weak self] in self?.unlock() }
    }

    override func layout() {
        super.layout()
        DispatchQueue.main.async { [weak self] in self?.unlock() }
    }

    func unlock() {
        guard let window else { return }
        WindowAppearanceApplier.unlockResize(window)
    }
}

/// Pushes appearance onto the hosting window when Settings / the popover first attach.
private struct WindowAppearanceBridge: NSViewRepresentable {
    var appearance: NSAppearance?

    func makeNSView(context: Context) -> AppearanceProbeView {
        let view = AppearanceProbeView()
        view.appearanceToApply = appearance
        return view
    }

    func updateNSView(_ nsView: AppearanceProbeView, context: Context) {
        nsView.appearanceToApply = appearance
        nsView.apply()
        DispatchQueue.main.async { nsView.apply() }
    }
}

private final class AppearanceProbeView: NSView {
    var appearanceToApply: NSAppearance?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        apply()
    }

    func apply() {
        WindowAppearanceApplier.apply(appearanceToApply)
        guard let window, WindowAppearanceApplier.shouldTheme(window) else { return }
        WindowAppearanceApplier.apply(appearanceToApply, to: window)
        WindowAppearanceApplier.unlockResize(window)
    }
}
#endif

extension DisplayPreferences.AppearanceMode {
    func colorScheme(systemIsDark: Bool) -> ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return systemIsDark ? .dark : .light
        }
    }

    #if os(macOS)
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
    #endif
}

extension DisplayPreferences.InterfaceSize {
    /// Layout magnification. 1.0 always restores Default (not a sticky minimum).
    var scale: CGFloat {
        switch self {
        case .defaultSize: return 1.0
        case .large: return 1.22
        case .extraLarge: return 1.44
        }
    }

    var popoverWidth: CGFloat { (360 * scale).rounded() }

    var settingsMinWidth: CGFloat { 900 }

    var settingsMinHeight: CGFloat { 600 }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .defaultSize: return .large
        case .large: return .xLarge
        case .extraLarge: return .xxLarge
        }
    }

    /// Point-size multiplier for labels. Dynamic Type is a no-op for most macOS SwiftUI fonts.
    var textScale: CGFloat {
        switch self {
        case .defaultSize: return 1.0
        case .large: return 1.22
        case .extraLarge: return 1.44
        }
    }
}

extension View {
    func appThemed(_ preferences: DisplayPreferences) -> some View {
        AppThemed(preferences: preferences) { self }
    }

    /// Lay out at 1×, then magnify. Scale is absolute, so Default (1.0) always shrinks back.
    func appLayoutScale(_ scale: CGFloat) -> some View {
        modifier(FillLayoutScale(scale: scale))
    }

    func appIntrinsicScale(_ scale: CGFloat) -> some View {
        modifier(IntrinsicLayoutScale(scale: scale))
    }

    func appFont(_ style: Font.TextStyle, weight: Font.Weight = .regular, mono: Bool = false) -> some View {
        modifier(AppFontModifier(style: style, weight: weight, mono: mono))
    }
}

private struct AppFontModifier: ViewModifier {
    @Environment(\.appTextScale) private var scale
    let style: Font.TextStyle
    var weight: Font.Weight
    var mono: Bool

    func body(content: Content) -> some View {
        let font = Font.system(size: AppTypeMetrics.pointSize(style) * scale, weight: weight)
        content.font(mono ? font.monospacedDigit() : font)
    }
}

private enum AppTypeMetrics {
    static func pointSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 26
        case .title: return 21
        case .title2: return 17
        case .title3: return 15
        case .headline: return 13
        case .body: return 13
        case .callout: return 12
        case .subheadline: return 11
        case .footnote: return 10
        case .caption: return 10
        case .caption2: return 10
        @unknown default: return 13
        }
    }
}

/// Settings: fill the window, lay out smaller, draw larger.
private struct FillLayoutScale: ViewModifier {
    let scale: CGFloat

    func body(content: Content) -> some View {
        GeometryReader { geo in
            let s = max(scale, 0.5)
            content
                .frame(
                    width: geo.size.width / s,
                    height: geo.size.height / s,
                    alignment: .topLeading
                )
                .scaleEffect(s, anchor: .topLeading)
                .frame(
                    width: geo.size.width,
                    height: geo.size.height,
                    alignment: .topLeading
                )
        }
    }
}

/// Popover: lay out at 360pt, magnify drawing, then claim scaled space.
private struct IntrinsicLayoutScale: ViewModifier {
    let scale: CGFloat
    @State private var height: CGFloat = 240

    func body(content: Content) -> some View {
        let s = max(scale, 0.5)
        content
            .frame(width: 360, alignment: .topLeading)
            .fixedSize(horizontal: true, vertical: true)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { height = proxy.size.height }
                        .onChange(of: proxy.size.height) { _, h in height = h }
                }
            )
            .scaleEffect(s, anchor: .topLeading)
            .frame(width: 360 * s, height: max(height, 1) * s, alignment: .topLeading)
    }
}
