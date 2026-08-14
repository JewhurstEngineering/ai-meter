import Foundation

/// Snapshot export for share/save. Never includes tokens, cookies, or API keys.
public enum UsageExport {
    public static func csv(_ snapshot: UsageSnapshot) -> String {
        var lines: [String] = []
        lines.append("section,key,value")
        lines.append(csvRow("summary", "plan", snapshot.planDisplayName))
        lines.append(csvRow("summary", "membership", snapshot.membershipType))
        if let status = snapshot.subscriptionStatus {
            lines.append(csvRow("summary", "status", status))
        }
        if let p = snapshot.cursorModelsPercentUsed {
            lines.append(csvRow("summary", "cursor_models_percent", formatPercent(p)))
        }
        if let p = snapshot.otherModelsPercentUsed {
            lines.append(csvRow("summary", "other_models_percent", formatPercent(p)))
        }
        if let p = snapshot.totalPercentUsed {
            lines.append(csvRow("summary", "total_included_percent", formatPercent(p)))
        }
        if let used = snapshot.planUsedCents {
            lines.append(csvRow("summary", "plan_used_cents", "\(used)"))
        }
        if let limit = snapshot.planLimitCents {
            lines.append(csvRow("summary", "plan_limit_cents", "\(limit)"))
        }
        lines.append(csvRow("summary", "on_demand", snapshot.onDemandEnabled ? "enabled" : "disabled"))
        if let used = snapshot.onDemandUsedCents {
            lines.append(csvRow("summary", "on_demand_used_cents", "\(used)"))
        }
        if let limit = snapshot.onDemandLimitCents {
            lines.append(csvRow("summary", "on_demand_limit_cents", "\(limit)"))
        }
        if let days = snapshot.daysRemainingInCycle {
            lines.append(csvRow("summary", "days_remaining", "\(days)"))
        }
        if let start = snapshot.billingCycleStart {
            lines.append(csvRow("summary", "cycle_start", iso(start)))
        }
        if let end = snapshot.billingCycleEnd {
            lines.append(csvRow("summary", "cycle_end", iso(end)))
        }
        lines.append(csvRow("summary", "fetched_at", iso(snapshot.fetchedAt)))

        for row in snapshot.modelBreakdown {
            lines.append(csvRow("model", row.model, formatCents(row.totalCents)))
        }
        for cycle in snapshot.cycleHistory {
            let label = cycle.isCurrent ? "current" : "previous"
            lines.append(csvRow("cycle", "\(label)_\(iso(cycle.start))", formatCents(cycle.totalCents)))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func json(_ snapshot: UsageSnapshot) throws -> Data {
        let payload = JSONPayload(snapshot: snapshot)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    public static func writeTemporaryCSV(_ snapshot: UsageSnapshot) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cursor-usage-\(Int(snapshot.fetchedAt.timeIntervalSince1970)).csv")
        try csv(snapshot).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    public static func writeTemporaryJSON(_ snapshot: UsageSnapshot) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cursor-usage-\(Int(snapshot.fetchedAt.timeIntervalSince1970)).json")
        try json(snapshot).write(to: url, options: .atomic)
        return url
    }

    private static func csvRow(_ section: String, _ key: String, _ value: String) -> String {
        "\(escape(section)),\(escape(key)),\(escape(value))"
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private static func formatPercent(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func formatCents(_ cents: Double) -> String {
        String(format: "%.2f", cents)
    }

    private static func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private struct JSONPayload: Encodable {
        var plan: String
        var membership: String
        var status: String?
        var cursorModelsPercent: Double?
        var otherModelsPercent: Double?
        var totalIncludedPercent: Double?
        var planUsedCents: Int?
        var planLimitCents: Int?
        var onDemandEnabled: Bool
        var onDemandUsedCents: Int?
        var onDemandLimitCents: Int?
        var daysRemaining: Int?
        var cycleStart: Date?
        var cycleEnd: Date?
        var fetchedAt: Date
        var models: [ModelRow]
        var cycles: [CycleRow]

        struct ModelRow: Encodable {
            var model: String
            var totalCents: Double
        }

        struct CycleRow: Encodable {
            var start: Date
            var end: Date
            var totalCents: Double
            var isCurrent: Bool
        }

        init(snapshot: UsageSnapshot) {
            plan = snapshot.planDisplayName
            membership = snapshot.membershipType
            status = snapshot.subscriptionStatus
            cursorModelsPercent = snapshot.cursorModelsPercentUsed
            otherModelsPercent = snapshot.otherModelsPercentUsed
            totalIncludedPercent = snapshot.totalPercentUsed
            planUsedCents = snapshot.planUsedCents
            planLimitCents = snapshot.planLimitCents
            onDemandEnabled = snapshot.onDemandEnabled
            onDemandUsedCents = snapshot.onDemandUsedCents
            onDemandLimitCents = snapshot.onDemandLimitCents
            daysRemaining = snapshot.daysRemainingInCycle
            cycleStart = snapshot.billingCycleStart
            cycleEnd = snapshot.billingCycleEnd
            fetchedAt = snapshot.fetchedAt
            models = snapshot.modelBreakdown.map { ModelRow(model: $0.model, totalCents: $0.totalCents) }
            cycles = snapshot.cycleHistory.map {
                CycleRow(start: $0.start, end: $0.end, totalCents: $0.totalCents, isCurrent: $0.isCurrent)
            }
        }
    }
}
