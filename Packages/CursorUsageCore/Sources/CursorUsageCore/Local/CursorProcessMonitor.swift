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
                let apps = "\(appCount) apps"
                let windows = windowCount == 1 ? "1 window" : "\(windowCount) windows"
                parts.append("Cursor · \(apps) · \(windows)")
            } else {
                let windows = windowCount == 1 ? "1 window" : "\(max(windowCount, 1)) windows"
                parts.append("Cursor · \(windows)")
            }
        } else {
            parts.append("Cursor not running")
        }
        if cliRunning {
            parts.append("CLI running")
        }
        return parts.joined(separator: " · ")
    }
}

public enum CursorProcessMonitor {
    public static func snapshot() -> CursorProcessSnapshot {
        let running = NSWorkspace.shared.runningApplications
        let helpersAndApp = running.filter(isCursorProcess)
        let apps = helpersAndApp.filter { $0.activationPolicy == .regular }
        let pids = Set(helpersAndApp.map(\.processIdentifier))
        return CursorProcessSnapshot(
            appCount: max(apps.count, apps.isEmpty && !helpersAndApp.isEmpty ? 1 : 0),
            windowCount: windowCount(for: pids),
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

    private static func isCursorApp(_ app: NSRunningApplication) -> Bool {
        isCursorProcess(app) && app.activationPolicy == .regular
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

    private static func windowCount(for pids: Set<pid_t>) -> Int {
        guard !pids.isEmpty else { return 0 }
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return 0
        }
        return info.filter { dict in
            guard let pid = dict[kCGWindowOwnerPID as String] as? pid_t, pids.contains(pid) else {
                return false
            }
            let layer = dict[kCGWindowLayer as String] as? Int ?? 0
            return layer == 0
        }.count
    }
}
#endif
