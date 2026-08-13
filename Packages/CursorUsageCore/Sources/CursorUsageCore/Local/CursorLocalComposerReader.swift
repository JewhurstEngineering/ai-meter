import Foundation

#if os(macOS)
import SQLite3

public struct LocalComposerSummary: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var mode: String?
    public var model: String?
    public var projectFolder: String?
    public var updatedAt: Date?
    public var status: String?

    public init(
        id: String,
        name: String,
        mode: String? = nil,
        model: String? = nil,
        projectFolder: String? = nil,
        updatedAt: Date? = nil,
        status: String? = nil
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.model = model
        self.projectFolder = projectFolder
        self.updatedAt = updatedAt
        self.status = status
    }

    public var modeLabel: String {
        switch (mode ?? "").lowercased() {
        case "agent": return "Agent"
        case "chat": return "Chat"
        case "plan": return "Plan"
        case "edit": return "Edit"
        case let other where !other.isEmpty: return other.capitalized
        default: return "Chat"
        }
    }
}

/// Recent Composer/Agent chats. `composer.composerHeaders` is a stale index;
/// recency comes from `~/.cursor/projects/*/agent-transcripts` plus a point
/// lookup of `composerData:{id}` in the IDE database.
public enum CursorLocalComposerReader {
    public static var defaultDatabaseURL: URL {
        CursorLocalAuthReader.defaultDatabaseURL
    }

    public static var defaultTranscriptsRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cursor/projects")
    }

    public static func recent(
        limit: Int = 4,
        databaseURL: URL = defaultDatabaseURL,
        transcriptsRoot: URL = defaultTranscriptsRoot
    ) -> [LocalComposerSummary] {
        let cap = max(1, limit)
        let candidates = transcriptSessions(root: transcriptsRoot, limit: max(cap * 6, 24))
        guard !candidates.isEmpty else { return [] }

        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_close(db) }

        var rows: [LocalComposerSummary] = []
        var seen = Set<String>()
        for candidate in candidates {
            if seen.contains(candidate.id) { continue }
            seen.insert(candidate.id)
            guard let json = readValue(db: db, key: "composerData:\(candidate.id)", table: "cursorDiskKV"),
                  let data = json.data(using: .utf8),
                  let parsed = decodeComposerData(data, fallbackDate: candidate.modifiedAt)
            else {
                continue
            }
            rows.append(parsed)
            if rows.count >= cap { break }
        }
        return rows.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
    }

    public static func decodeHeadersJSON(_ data: Data) -> [LocalComposerSummary] {
        guard let decoded = try? JSONDecoder().decode(ComposerIndex.self, from: data) else {
            return []
        }
        return (decoded.allComposers ?? []).compactMap { summary(from: $0, fallbackDate: nil) }
    }

    public static func decodeComposerData(_ data: Data, fallbackDate: Date? = nil) -> LocalComposerSummary? {
        guard let entry = try? JSONDecoder().decode(ComposerEntry.self, from: data) else {
            return nil
        }
        return summary(from: entry, fallbackDate: fallbackDate)
    }

    private static func transcriptSessions(root: URL, limit: Int) -> [TranscriptSession] {
        let fm = FileManager.default
        guard let projects = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var sessions: [TranscriptSession] = []
        for project in projects {
            let transcripts = project.appendingPathComponent("agent-transcripts")
            guard let dirs = try? fm.contentsOfDirectory(
                at: transcripts,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }
            for dir in dirs {
                let id = dir.lastPathComponent
                guard isUUID(id) else { continue }
                let jsonl = dir.appendingPathComponent("\(id).jsonl")
                let modified = modificationDate(of: jsonl) ?? modificationDate(of: dir)
                sessions.append(TranscriptSession(id: id, modifiedAt: modified ?? .distantPast))
            }
        }
        return sessions
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(limit)
            .map { $0 }
    }

    private static func summary(from composer: ComposerEntry, fallbackDate: Date?) -> LocalComposerSummary? {
        if composer.isDraft == true || composer.isArchived == true || composer.isBestOfNSubcomposer == true {
            return nil
        }
        let name = composer.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let folderPath = composer.workspaceIdentifier?.uri?.fsPath
            ?? composer.workspaceIdentifier?.uri?.path
        let folder = folderPath.map { URL(fileURLWithPath: $0).lastPathComponent }
        let millis = composer.conversationCheckpointLastUpdatedAt
            ?? composer.lastUpdatedAt
            ?? composer.createdAt
        let fromMillis = millis.map { Date(timeIntervalSince1970: $0 > 10_000_000_000 ? $0 / 1000 : $0) }
        let updated = [fromMillis, fallbackDate].compactMap { $0 }.max()
        return LocalComposerSummary(
            id: composer.composerId ?? UUID().uuidString,
            name: (name?.isEmpty == false) ? name! : "Untitled chat",
            mode: composer.unifiedMode ?? composer.forceMode,
            model: composer.modelConfig?.modelName,
            projectFolder: folder?.isEmpty == false ? folder : nil,
            updatedAt: updated,
            status: composer.status
        )
    }

    private static func readValue(db: OpaquePointer?, key: String, table: String) -> String? {
        let escapedKey = key.replacingOccurrences(of: "'", with: "''")
        let escapedTable = table.replacingOccurrences(of: "'", with: "''")
        let sql = "SELECT value FROM \(escapedTable) WHERE key = '\(escapedKey)' LIMIT 1;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let cString = sqlite3_column_text(statement, 0)
        else {
            return nil
        }
        return String(cString: cString)
    }

    private static func modificationDate(of url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    private static func isUUID(_ value: String) -> Bool {
        UUID(uuidString: value) != nil
    }

    private struct TranscriptSession {
        var id: String
        var modifiedAt: Date
    }

    private struct ComposerIndex: Decodable {
        var allComposers: [ComposerEntry]?
    }

    private struct ComposerEntry: Decodable {
        var composerId: String?
        var name: String?
        var unifiedMode: String?
        var forceMode: String?
        var status: String?
        var createdAt: Double?
        var lastUpdatedAt: Double?
        var conversationCheckpointLastUpdatedAt: Double?
        var isDraft: Bool?
        var isArchived: Bool?
        var isBestOfNSubcomposer: Bool?
        var modelConfig: ModelConfig?
        var workspaceIdentifier: WorkspaceIdentifier?
    }

    private struct ModelConfig: Decodable {
        var modelName: String?
    }

    private struct WorkspaceIdentifier: Decodable {
        var uri: WorkspaceURI?
    }

    private struct WorkspaceURI: Decodable {
        var fsPath: String?
        var path: String?

        enum CodingKeys: String, CodingKey {
            case fsPath, path
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            fsPath = try c.decodeIfPresent(String.self, forKey: .fsPath)
            path = try c.decodeIfPresent(String.self, forKey: .path)
        }
    }
}
#endif
