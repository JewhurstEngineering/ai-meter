import Foundation

/// Anthropic 429s unknown / stale User-Agents on `GET /api/oauth/usage`.
/// Match the installed Claude Code version when we can; otherwise a known-good fallback.
enum ClaudeCodeVersion {
    static let fallback = "2.1.233"

    static func userAgent(installed: String? = detectInstalled()) -> String {
        "claude-code/\(installed ?? fallback)"
    }

    static func detectInstalled() -> String? {
        #if os(macOS)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let binaries = [
            home.appendingPathComponent(".local/bin/claude"),
            URL(fileURLWithPath: "/opt/homebrew/bin/claude"),
            URL(fileURLWithPath: "/usr/local/bin/claude"),
        ]
        for url in binaries {
            if let version = version(fromBinary: url) { return version }
        }
        return newestVersion(
            in: home.appendingPathComponent(".local/share/claude/versions")
        )
        #else
        return nil
        #endif
    }

    static func parse(_ raw: String) -> String? {
        let pattern = #"(\d+\.\d+\.\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        guard let match = regex.firstMatch(in: raw, range: range),
              let swiftRange = Range(match.range(at: 1), in: raw)
        else { return nil }
        return String(raw[swiftRange])
    }

    #if os(macOS)
    static func version(fromBinary url: URL) -> String? {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue
        else { return nil }
        let dest = url.resolvingSymlinksInPath()
        if let version = parse(dest.lastPathComponent) { return version }
        var dir = dest.deletingLastPathComponent()
        for _ in 0..<6 {
            let pkg = dir.appendingPathComponent("package.json")
            if let version = version(fromPackageJSON: pkg) { return version }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        return nil
    }

    static func newestVersion(in directory: URL) -> String? {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path)
        else { return nil }
        return names.compactMap(parse).sorted(by: isNewer).last
    }

    static func version(fromPackageJSON url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = obj["name"] as? String,
              name == "@anthropic-ai/claude-code" || name == "claude-code",
              let raw = obj["version"] as? String
        else { return nil }
        return parse(raw)
    }
    #endif

    static func isNewer(_ lhs: String, _ rhs: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            s.split(separator: ".").compactMap { Int($0) }
        }
        let a = parts(lhs)
        let b = parts(rhs)
        for i in 0..<max(a.count, b.count) {
            let l = i < a.count ? a[i] : 0
            let r = i < b.count ? b[i] : 0
            if l != r { return l < r }
        }
        return false
    }
}
