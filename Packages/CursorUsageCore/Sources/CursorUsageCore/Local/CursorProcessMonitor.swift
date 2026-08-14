import Foundation

#if os(macOS)
import AppKit
import CoreGraphics
import Darwin

public struct CursorProcessSnapshot: Sendable, Equatable {
    public var appCount: Int
    public var windowCount: Int
    public var cliProcessCount: Int
    public var cliInstalled: Bool
    public var cliVersion: String?

    public init(
        appCount: Int = 0,
        windowCount: Int = 0,
        cliProcessCount: Int = 0,
        cliInstalled: Bool = false,
        cliVersion: String? = nil
    ) {
        self.appCount = appCount
        self.windowCount = windowCount
        self.cliProcessCount = max(0, cliProcessCount)
        self.cliInstalled = cliInstalled
        self.cliVersion = cliVersion
    }

    /// Back-compat for older call sites.
    public var cliRunning: Bool { cliProcessCount > 0 }

    public var isEditorRunning: Bool { appCount > 0 }
    public var isRunning: Bool { isEditorRunning || cliRunning }
    public var showsCLIRow: Bool { cliInstalled || cliProcessCount > 0 }

    public var summaryLine: String {
        if appCount > 1 {
            return "Cursor · \(appCount) apps · \(windowPhrase)"
        }
        if appCount > 0 {
            return "Cursor · \(windowPhrase)"
        }
        return "Cursor not running"
    }

    public var cliSummaryLine: String {
        if cliProcessCount > 0 {
            if let cliVersion, !cliVersion.isEmpty {
                return "CLI · \(cliVersion)"
            }
            return "CLI running"
        }
        if cliInstalled {
            return "CLI not running"
        }
        return "CLI not installed"
    }

    public var windowPhrase: String {
        windowCount == 1 ? "1 window" : "\(windowCount) windows"
    }
}

public enum CursorProcessMonitor {
    public static var defaultCLIBinaryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin/cursor-agent")
    }

    public static func snapshot() -> CursorProcessSnapshot {
        let running = NSWorkspace.shared.runningApplications
        let helpersAndApp = running.filter(isCursorProcess)
        let apps = helpersAndApp.filter { $0.activationPolicy == .regular }
        let workspaces = running.filter(isCursorFileWatcher).count
        let windows = max(onscreenEditorWindows(), workspaces)
        let install = installedCLI()
        let fromWorkspace = running.filter(isCursorCLI).count
        let fromProc = cursorAgentProcessCount()
        return CursorProcessSnapshot(
            appCount: max(apps.count, apps.isEmpty && windows > 0 ? 1 : 0),
            windowCount: windows,
            cliProcessCount: max(fromProc, fromWorkspace),
            cliInstalled: install.installed,
            cliVersion: install.version
        )
    }

    /// `~/.local/bin/cursor-agent` plus Homebrew / usr/local copies.
    public static func installedCLI(
        extraBinaryURLs: [URL] = [],
        fileManager: FileManager = .default
    ) -> (installed: Bool, version: String?) {
        let home = fileManager.homeDirectoryForCurrentUser
        var candidates = extraBinaryURLs
        candidates.append(contentsOf: [
            home.appendingPathComponent(".local/bin/cursor-agent"),
            URL(fileURLWithPath: "/opt/homebrew/bin/cursor-agent"),
            URL(fileURLWithPath: "/usr/local/bin/cursor-agent"),
        ])

        for url in candidates {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            return (true, versionFromCLIBinary(url, fileManager: fileManager))
        }
        return (false, nil)
    }

    public static func versionFromCLIBinary(_ url: URL, fileManager: FileManager = .default) -> String? {
        let resolved: URL
        if let dest = try? fileManager.destinationOfSymbolicLink(atPath: url.path) {
            resolved = URL(fileURLWithPath: dest, relativeTo: url.deletingLastPathComponent()).standardizedFileURL
        } else {
            resolved = url.resolvingSymlinksInPath()
        }
        // …/versions/2026.08.04-aaa8809/cursor-agent
        let parent = resolved.deletingLastPathComponent()
        guard parent.deletingLastPathComponent().lastPathComponent == "versions" else {
            return nil
        }
        let version = parent.lastPathComponent
        return version.isEmpty ? nil : version
    }

    public static func isCursorAgentExecutable(path: String) -> Bool {
        let name = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        if name == "cursor-agent" || name.hasPrefix("cursor-agent") { return true }
        // Some installs wrap the binary as `agent`.
        if name == "agent", path.lowercased().contains("cursor-agent") { return true }
        return false
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
        if let exec = app.executableURL?.path, isCursorAgentExecutable(path: exec) {
            return true
        }
        let name = (app.localizedName ?? "").lowercased()
        if name.contains("cursor-agent") || name == "cursor agent" { return true }
        if let bundle = app.bundleIdentifier?.lowercased(), bundle.contains("cursor-agent") {
            return true
        }
        return false
    }

    /// CLI tools often never appear in `NSWorkspace.runningApplications`.
    private static func cursorAgentProcessCount() -> Int {
        let needed = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard needed > 0 else { return 0 }
        let stride = MemoryLayout<pid_t>.stride
        var pids = [pid_t](repeating: 0, count: Int(needed) / stride + 32)
        let filled = pids.withUnsafeMutableBufferPointer { buf -> Int32 in
            guard let base = buf.baseAddress else { return 0 }
            return proc_listpids(UInt32(PROC_ALL_PIDS), 0, base, Int32(buf.count * stride))
        }
        guard filled > 0 else { return 0 }
        let count = Int(filled) / stride
        var pathBuffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        var matches = 0
        for pid in pids.prefix(count) where pid > 0 {
            let result = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
            guard result > 0 else { continue }
            let path = String(cString: pathBuffer)
            if isCursorAgentExecutable(path: path) {
                matches += 1
            }
        }
        return matches
    }
}
#endif
