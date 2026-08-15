import Foundation

enum CodexUsageMapper {
    static func map(_ data: Data, fetchedAt: Date = .now) throws -> UsageSnapshot {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderUsageError.decodingFailed
        }
        let rate = obj["rate_limit"] as? [String: Any] ?? obj
        var windows: [QuotaWindow] = []
        if let primary = window(rate["primary_window"] ?? rate["primary"], id: "session", title: "5-hour", role: .session) {
            windows.append(primary)
        }
        if let secondary = window(rate["secondary_window"] ?? rate["secondary"], id: "weekly", title: "7-day", role: .weekly) {
            windows.append(secondary)
        }
        if let extras = obj["additional_rate_limits"] as? [[String: Any]] {
            for extra in extras {
                let name = (extra["limit_name"] as? String) ?? (extra["metered_feature"] as? String) ?? "Extra"
                let nested = extra["rate_limit"] as? [String: Any] ?? extra
                if let weekly = window(
                    nested["secondary_window"] ?? nested["primary_window"] ?? nested["secondary"] ?? nested["primary"],
                    id: "extra-\(name)",
                    title: name,
                    role: .extra
                ) {
                    windows.append(weekly)
                }
            }
        }
        if let review = obj["code_review_rate_limit"] as? [String: Any],
           let weekly = window(review["primary_window"] ?? review["secondary_window"], id: "code_review", title: "Code review", role: .extra)
        {
            windows.append(weekly)
        }
        guard !windows.isEmpty else { throw ProviderUsageError.decodingFailed }

        let plan = (obj["plan_type"] as? String) ?? "codex"
        return UsageSnapshot(
            fetchedAt: fetchedAt,
            membershipType: plan.lowercased(),
            planDisplayName: displayPlan(plan),
            provider: .codex,
            windows: windows,
            spend: credits(obj["credits"] as? [String: Any])
        )
    }

    private static func window(_ raw: Any?, id: String, title: String, role: QuotaWindowRole) -> QuotaWindow? {
        guard let obj = raw as? [String: Any] else { return nil }
        let percent = number(obj["used_percent"] ?? obj["usedPercent"] ?? obj["percent"])
        guard let percent else { return nil }
        let reset = date(obj["reset_at"] ?? obj["resets_at"] ?? obj["resetsAt"])
            ?? relativeReset(obj["reset_after_seconds"])
        return QuotaWindow(
            id: id,
            title: title,
            percentUsed: percent,
            resetsAt: reset,
            kind: .rolling,
            role: role
        )
    }

    private static func credits(_ obj: [String: Any]?) -> SpendMeter? {
        guard let obj else { return nil }
        let has = (obj["has_credits"] as? Bool) ?? false
        let unlimited = (obj["unlimited"] as? Bool) ?? false
        let balance = dollarsToCents(obj["balance"])
        guard has || unlimited || balance != nil else { return nil }
        return SpendMeter(
            title: "Credits",
            usedCents: nil,
            limitCents: nil,
            remainingCents: balance,
            enabled: has || unlimited || (balance ?? 0) > 0,
            unlimited: unlimited
        )
    }

    private static func displayPlan(_ raw: String) -> String {
        switch raw.lowercased() {
        case "plus": return "ChatGPT Plus"
        case "pro": return "ChatGPT Pro"
        case "prolite", "pro_lite": return "ChatGPT Pro"
        case "free": return "ChatGPT Free"
        case "team": return "ChatGPT Team"
        default:
            if raw.localizedCaseInsensitiveContains("chatgpt") || raw.localizedCaseInsensitiveContains("codex") {
                return raw
            }
            return "Codex \(raw)"
        }
    }

    private static func number(_ value: Any?) -> Double? {
        if let n = value as? Double { return n }
        if let n = value as? Int { return Double(n) }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private static func dollarsToCents(_ value: Any?) -> Int? {
        guard let n = number(value) else { return nil }
        if abs(n) >= 100, floor(n) == n { return Int(n) }
        return Int((n * 100).rounded())
    }

    private static func date(_ value: Any?) -> Date? {
        guard let n = number(value), n > 1_000_000 else { return nil }
        return Date(timeIntervalSince1970: n > 10_000_000_000 ? n / 1000 : n)
    }

    private static func relativeReset(_ value: Any?) -> Date? {
        guard let n = number(value), n > 0 else { return nil }
        return Date().addingTimeInterval(n)
    }
}
