import Foundation

#if os(macOS)
import CryptoKit
import SQLite3

/// Recent Cursor Agent CLI sessions from `~/.cursor/chats/{projectHash}/{chatId}/store.db`.
/// Separate from IDE `agent-transcripts` / `composerData`. Never reads message blobs.
public enum CursorCLISessionReader {
    public static var defaultChatsRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cursor/chats")
    }

    public static var defaultProjectsRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cursor/projects")
    }

    public static func recent(
        limit: Int = 4,
        chatsRoot: URL = defaultChatsRoot,
        projectsRoot: URL = defaultProjectsRoot
    ) -> [LocalComposerSummary] {
        let cap = max(1, limit)
        let folders = chatFolders(root: chatsRoot)
        guard !folders.isEmpty else { return [] }

        let workspaceByHash = workspaceLabels(projectsRoot: projectsRoot)
        var rows: [LocalComposerSummary] = []
        rows.reserveCapacity(min(cap, folders.count))

        for folder in folders.prefix(cap * 3) {
            let meta = readMeta(storeURL: folder.storeURL)
            let name = cleanedName(meta?.name) ?? "CLI chat"
            let updated = meta?.createdAt.flatMap(dateFromMillis) ?? folder.modifiedAt
            rows.append(
                LocalComposerSummary(
                    id: folder.chatID,
                    name: name,
                    mode: meta?.mode,
                    model: meta?.model,
                    projectFolder: workspaceByHash[folder.projectHash],
                    updatedAt: updated,
                    status: nil,
                    source: "cli"
                )
            )
            if rows.count >= cap { break }
        }
        return rows.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
    }

    public static func decodeMetaJSON(_ data: Data) -> CLISessionMeta? {
        try? JSONDecoder().decode(CLISessionMeta.self, from: data)
    }

    public static func decodeMetaValue(_ raw: String) -> CLISessionMeta? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8), let parsed = decodeMetaJSON(data) {
            return parsed
        }
        guard let decoded = dataFromHex(trimmed) else { return nil }
        return decodeMetaJSON(decoded)
    }

    public static func md5Hex(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public struct CLISessionMeta: Decodable, Sendable, Equatable {
        public var name: String?
        public var mode: String?
        public var createdAt: Double?
        public var model: String?
        public var cwd: String?
        public var workspace: String?
        public var workspacePath: String?

        public init(
            name: String? = nil,
            mode: String? = nil,
            createdAt: Double? = nil,
            model: String? = nil,
            cwd: String? = nil,
            workspace: String? = nil,
            workspacePath: String? = nil
        ) {
            self.name = name
            self.mode = mode
            self.createdAt = createdAt
            self.model = model
            self.cwd = cwd
            self.workspace = workspace
            self.workspacePath = workspacePath
        }
    }

    private struct ChatFolder {
        var projectHash: String
        var chatID: String
        var storeURL: URL
        var modifiedAt: Date
    }

    private static func chatFolders(root: URL) -> [ChatFolder] {
        let fm = FileManager.default
        guard let projects = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var folders: [ChatFolder] = []
        for project in projects {
            let hash = project.lastPathComponent
            guard hash.count >= 8 else { continue }
            guard let chats = try? fm.contentsOfDirectory(
                at: project,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }
            for chat in chats {
                let id = chat.lastPathComponent
                guard UUID(uuidString: id) != nil else { continue }
                let store = chat.appendingPathComponent("store.db")
                let modified = modificationDate(of: store) ?? modificationDate(of: chat) ?? .distantPast
                folders.append(
                    ChatFolder(projectHash: hash, chatID: id, storeURL: store, modifiedAt: modified)
                )
            }
        }
        return folders.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    private static func readMeta(storeURL: URL) -> CLISessionMeta? {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return nil }
        var db: OpaquePointer?
        guard sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }
        let sql = "SELECT value FROM meta WHERE key = '0' LIMIT 1;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let cString = sqlite3_column_text(statement, 0)
        else {
            return nil
        }
        return decodeMetaValue(String(cString: cString))
    }

    /// Map CLI project hashes (MD5 of cwd) back to a folder name when we can.
    private static func workspaceLabels(projectsRoot: URL) -> [String: String] {
        var map: [String: String] = [:]
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(
            at: projectsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return map
        }

        for dir in dirs {
            let encoded = dir.lastPathComponent
            if encoded.hasPrefix(".") { continue }
            let reconstructed = "/" + encoded.replacingOccurrences(of: "-", with: "/")
            remember(path: reconstructed, into: &map)
            if let cwd = realPathIfExists(reconstructed) {
                remember(path: cwd, into: &map)
            }
        }
        return map
    }

    private static func remember(path: String, into map: inout [String: String]) {
        let folder = URL(fileURLWithPath: path).lastPathComponent
        guard !folder.isEmpty else { return }
        map[md5Hex(path)] = folder
    }

    private static func realPathIfExists(_ path: String) -> String? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }

    private static func cleanedName(_ name: String?) -> String? {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func dateFromMillis(_ value: Double) -> Date {
        Date(timeIntervalSince1970: value > 10_000_000_000 ? value / 1000 : value)
    }

    private static func modificationDate(of url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    private static func dataFromHex(_ hex: String) -> Data? {
        let chars = Array(hex)
        guard chars.count >= 2, chars.count.isMultiple(of: 2) else { return nil }
        guard chars.allSatisfy(\.isHexDigit) else { return nil }
        var data = Data(capacity: chars.count / 2)
        var index = 0
        while index < chars.count {
            let byte = String(chars[index]) + String(chars[index + 1])
            guard let value = UInt8(byte, radix: 16) else { return nil }
            data.append(value)
            index += 2
        }
        return data
    }
}
#endif
