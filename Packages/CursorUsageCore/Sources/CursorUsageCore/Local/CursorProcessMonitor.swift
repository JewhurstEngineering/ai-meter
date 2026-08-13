import Foundation

#if os(macOS)
import AppKit
import CoreGraphics

public struct CursorProcessSnapshot: Sendable, Equatable {
    public var appCount: Int
    public var windowCount: Int
    public var cliRunning: Bool

    public init(appCount: Int = 0, windowCount: Int = 0, cliRunning: Bool = false) {
        self.appCount = appCount
        self.windowCount = windowCount
        self.cliRunning = cliRunning
    }

    public var isRunning: Bool { appCount > 0 || cliRunning }

    public var summaryLine: String {
        var parts: [String] = []
        if appCount > 0 {
            if appCount > 1 {
                parts.append("Cursor · \(appCount) apps · \(windowPhrase)")
            } else {
                parts.append("Cursor · \(windowPhrase)")
            }
        } else {
            parts.append("Cursor not running")
        }
        if cliRunning {
            parts.append("CLI running")
        }
        return parts.joined(separator: " · ")
    }

    public var windowPhrase: String {
        windowCount == 1 ? "1 window" : "\(windowCount) windows"
    }
}

public enum CursorProcessMonitor {
    public static func snapshot() -> CursorProcessSnapshot {
        let running = NSWorkspace.shared.runningApplications
        let helpersAndApp = running.filter(isCursorProcess)
        let apps = helpersAndApp.filter { $0.activationPolicy == .regular }
        let workspaces = running.filter(isCursorFileWatcher).count
        let windows = max(onscreenEditorWindows(), workspaces)
        return CursorProcessSnapshot(
            appCount: max(apps.count, apps.isEmpty && windows > 0 ? 1 : 0),
            windowCount: windows,
            cliRunning: running.contains(where: isCursorCLI)
        )
    }

    private static func isCursorProcess(_ app: NSRunningApplication) -> Bool {
        if isCursorCLI(app) { return false }
        if let bundle = app.bundleIdentifier?.lowercased() {
            if bundle.contains("cursorusagetracker") || bundle.contains("cursor-usage") { return false }
            if bundle.hasPrefix("com.todesktop.") { return true }
            if bundle == "com.anysphere.cursor" { return true }
            if bundle.contains("cursor") { return true }
        }
        let name = (app.localizedName ?? "").lowercased()
        return name == "cursor" || name.hasPrefix("cursor helper") || name == "cursor nightly"
    }

    /// Electron file-watchers are 1:1 with open Cursor windows/workspaces,
    /// including windows on other Spaces that `CGWindowList` on-screen misses.
    private static func isCursorFileWatcher(_ app: NSRunningApplication) -> Bool {
        (app.localizedName ?? "").lowercased().hasPrefix("cursor helper: filewatcher")
    }

    /// Visible Cursor editor frames. Ignores 32pt titlebar strips, overlay
    /// layers, and Apple’s `CursorUIViewService`.
    private static func onscreenEditorWindows() -> Int {
        let options: CGWindowListOption = [.optionAll]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return 0
        }
        return info.filter { dict in
            let owner = (dict[kCGWindowOwnerName as String] as? String) ?? ""
            guard owner == "Cursor" else { return false }
            let layer = dict[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { return false }
            let alpha = (dict[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            guard alpha >= 0.5 else { return false }
            let bounds = dict[kCGWindowBounds as String] as? [String: Any]
            let width = (bounds?["Width"] as? NSNumber)?.doubleValue ?? 0
            let height = (bounds?["Height"] as? NSNumber)?.doubleValue ?? 0
            return width >= 200 && height >= 200
        }.count
    }

    private static func isCursorCLI(_ app: NSRunningApplication) -> Bool {
        let name = (app.localizedName ?? "").lowercased()
        if name.contains("cursor-agent") || name == "cursor agent" { return true }
        if let bundle = app.bundleIdentifier?.lowercased(), bundle.contains("cursor-agent") {
            return true
        }
        if let exec = app.executableURL?.lastPathComponent.lowercased() {
            return exec == "cursor-agent" || exec.hasPrefix("cursor-agent")
        }
        return false
    }
}
#endif
