import AppKit

enum AppInstall {
    static var applicationsURL: URL {
        FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first
            ?? URL(fileURLWithPath: "/Applications")
    }

    static var installedAppURL: URL {
        applicationsURL.appendingPathComponent("AI Meter.app", isDirectory: true)
    }

    static func isApplicationsPath(_ path: String) -> Bool {
        path.hasPrefix("/Applications/")
    }

    static var isRunningFromApplications: Bool {
        isApplicationsPath(Bundle.main.bundleURL.path)
    }

    static let bannerDismissedKey = "installToApplications.bannerDismissed"

    static func copyRunningAppToApplications() throws -> URL {
        let src = Bundle.main.bundleURL
        let dest = installedAppURL
        guard src.standardizedFileURL != dest.standardizedFileURL else {
            registerLaunchServices(at: dest)
            return dest
        }

        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        task.arguments = [src.path, dest.path]
        let err = Pipe()
        task.standardError = err
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "AppInstall",
                code: Int(task.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: message?.isEmpty == false
                        ? message!
                        : "Copy to Applications failed (ditto \(task.terminationStatus)).",
                ]
            )
        }
        registerLaunchServices(at: dest)
        return dest
    }

    /// Launch Services reuses the running bundle ID, so `NSWorkspace.open` just
    /// reactivates this Xcode copy. Detach `open -n` so it survives terminate.
    static func launchInstalledAndTerminate() {
        let dest = installedAppURL.path
        let escaped = dest.replacingOccurrences(of: "'", with: "'\\''")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = [
            "-c",
            "((sleep 1.2; /usr/bin/open -n '\(escaped)') &)",
        ]
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        NSApp.terminate(nil)
    }

    static func registerEmbeddedWidget() {
        registerLaunchServices(at: Bundle.main.bundleURL)
    }

    private static func registerLaunchServices(at appURL: URL) {
        let plugin = appURL
            .appendingPathComponent("Contents/PlugIns/AIMeterWidgets.appex", isDirectory: true)
        let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        _ = run("/usr/bin/xattr", ["-cr", appURL.path])
        _ = run(lsregister, ["-f", appURL.path])
        if FileManager.default.fileExists(atPath: plugin.path) {
            _ = run("/usr/bin/pluginkit", ["-a", plugin.path])
            _ = run("/usr/bin/pluginkit", ["-e", "use", "-i", "com.jamesware.aimeter.app.widgets"])
        }
    }

    @discardableResult
    private static func run(_ launchPath: String, _ arguments: [String]) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = arguments
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus
        } catch {
            return -1
        }
    }
}
