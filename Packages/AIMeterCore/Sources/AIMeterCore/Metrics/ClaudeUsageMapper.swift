import Foundation

enum ClaudeUsageMapper {
    static func map(_ data: Data, fetchedAt: Date = .now) throws -> UsageSnapshot {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderUsageError.decodingFailed
        }
        let windows = windows(from: obj)
        guard !windows.isEmpty else { throw ProviderUsageError.decodingFailed }

        let plan = string(obj["plan"] ?? obj["plan_type"] ?? obj["membership_type"]) ?? "Claude"
        let spend = spendMeter(from: obj)

        return UsageSnapshot(
            fetchedAt: fetchedAt,
            membershipType: plan.lowercased(),
            planDisplayName: displayPlan(plan),
            provider: .claude,
            windows: windows,
            spend: spend
        )
    }

    static func windows(from obj: [String: Any]) -> [QuotaWindow] {
        var result: [QuotaWindow] = []
        if let session = window(
            obj,
            keys: ["five_hour", "fiveHour", "five_hour_util", "session"],
            id: "session",
            title: "5-hour",
            role: .session
        ) {
            result.append(session)
        }
        if let weekly = window(
            obj,
            keys: ["seven_day", "sevenDay", "seven_day_util", "weekly"],
            id: "weekly",
            title: "7-day",
            role: .weekly
        ) {
            result.append(weekly)
        }

        let extraNames: [(String, String)] = [
            ("seven_day_sonnet", "Sonnet (week)"),
            ("seven_day_opus", "Opus (week)"),
            ("seven_day_oauth_apps", "OAuth apps (week)"),
            ("seven_day_omelette", "Omelette (week)"),
            ("seven_day_cowork", "Cowork (week)"),
        ]
        for (key, title) in extraNames {
            if let extra = window(obj, keys: [key], id: key, title: title, role: .extra) {
                result.append(extra)
            }
        }
        return result
    }

    private static func window(
        _ obj: [String: Any],
        keys: [String],
        id: String,
        title: String,
        role: QuotaWindowRole
    ) -> QuotaWindow? {
        for key in keys {
            if let nested = obj[key] as? [String: Any],
               let percent = percent(from: nested) {
                return QuotaWindow(
                    id: id,
                    title: title,
                    percentUsed: percent,
                    resetsAt: date(nested["resets_at"] ?? nested["resetsAt"] ?? nested["reset_at"]),
                    kind: .rolling,
                    role: role
                )
            }
            if let value = obj[key], let percent = scalarPercent(value) {
                return QuotaWindow(
                    id: id,
                    title: title,
                    percentUsed: percent,
                    resetsAt: date(obj["resets_at"] ?? obj["resetsAt"]),
                    kind: .rolling,
                    role: role
                )
            }
        }
        return nil
    }

    private static func spendMeter(from obj: [String: Any]) -> SpendMeter? {
        let extra = obj["extra_usage"] as? [String: Any]
        let overage = obj["overage"] as? [String: Any] ?? extra
        guard let overage else { return nil }
        let used = cents(overage["used"] ?? overage["used_credits"] ?? overage["used_cents"])
        let limit = cents(
            overage["limit"]
                ?? overage["monthly_limit"]
                ?? overage["monthly_credit_limit"]
                ?? overage["limit_cents"]
        )
        let remaining = cents(overage["remaining"] ?? overage["remaining_credits"])
        let enabled = bool(overage["is_enabled"] ?? overage["enabled"]) ?? (used != nil || limit != nil)
        guard enabled || used != nil else { return nil }
        return SpendMeter(
            title: "Extra usage",
            usedCents: used,
            limitCents: limit,
            remainingCents: remaining,
            enabled: enabled,
            unlimited: enabled && (limit == nil || (limit ?? 0) <= 0)
        )
    }

    /// Claude `/api/oauth/usage` reports `utilization` / `used_percentage` on a 0–100 scale.
    /// Values like `1.0` mean 1%, not a fraction — do not multiply by 100.
    static func percent(from obj: [String: Any]) -> Double? {
        if let v = obj["utilization"]
            ?? obj["used_percentage"]
            ?? obj["usedPercentage"]
            ?? obj["used_percent"]
            ?? obj["usedPercent"]
            ?? obj["percent"]
        {
            return number(v)
        }
        return nil
    }

    private static func scalarPercent(_ value: Any) -> Double? {
        number(value)
    }

    private static func number(_ value: Any) -> Double? {
        if let n = value as? Double { return n }
        if let n = value as? Int { return Double(n) }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private static func cents(_ value: Any?) -> Int? {
        guard let value, let n = number(value) else { return nil }
        if n >= 1000 { return Int(n.rounded()) }
        return Int((n * 100).rounded())
    }

    private static func bool(_ value: Any?) -> Bool? {
        if let b = value as? Bool { return b }
        return nil
    }

    private static func string(_ value: Any?) -> String? {
        value as? String
    }

    private static func date(_ value: Any?) -> Date? {
        guard let value else { return nil }
        if let n = number(value), n > 1_000_000 {
            return Date(timeIntervalSince1970: n > 10_000_000_000 ? n / 1000 : n)
        }
        if let s = value as? String {
            return UsageSnapshotMapper.parseDate(s)
        }
        return nil
    }

    private static func displayPlan(_ raw: String) -> String {
        switch raw.lowercased() {
        case "pro": return "Claude Pro"
        case "max", "max_5x", "max5x": return "Claude Max"
        case "max_20x", "max20x": return "Claude Max 20x"
        case "free": return "Claude Free"
        default:
            if raw.localizedCaseInsensitiveContains("claude") { return raw }
            return "Claude \(raw)"
        }
    }
}
