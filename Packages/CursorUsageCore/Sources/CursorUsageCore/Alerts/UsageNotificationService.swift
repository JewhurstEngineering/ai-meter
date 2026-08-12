import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Fires local notifications when watched usage crosses configured thresholds,
/// or when a live session becomes unauthorized.
/// Dedupes per billing-cycle + threshold so the same alert does not spam.
public enum UsageNotificationService {
    private static let firedKeyPrefix = "usageAlert.fired."
    private static let sessionExpiredFiredKey = "usageAlert.sessionExpired.fired"

    public static func requestAuthorizationIfNeeded() async -> Bool {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        default:
            return false
        }
        #else
        return false
        #endif
    }

    /// Clears the session-expired dedupe flag after a successful re-auth.
    public static func clearSessionExpiredDedupe(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: sessionExpiredFiredKey)
    }

    @MainActor
    public static func evaluate(
        snapshot: UsageSnapshot,
        preferences: DisplayPreferences,
        defaults: UserDefaults = .standard
    ) async {
        guard preferences.notificationsEnabled else { return }
        guard !preferences.notificationThresholds.isEmpty else { return }

        let authorized = await requestAuthorizationIfNeeded()
        guard authorized else { return }

        let highest = snapshot.highestWatchedPercent
        let cycleKey = cycleIdentity(for: snapshot)
        let poolLabel = leadingPoolLabel(for: snapshot)

        for threshold in preferences.notificationThresholds where highest >= threshold {
            let key = "\(firedKeyPrefix)\(cycleKey).\(Int(threshold))"
            if defaults.bool(forKey: key) { continue }
            await postUsageNotification(
                threshold: threshold,
                current: highest,
                poolLabel: poolLabel,
                snapshot: snapshot,
                contentOptions: preferences.notificationContent
            )
            defaults.set(true, forKey: key)
        }
    }

    /// Called when a refresh fails with unauthorized while a session was in use.
    /// Does not fire for intentional sign-out. Dedupes until re-auth succeeds.
    @MainActor
    public static func notifySessionExpiredIfNeeded(
        preferences: DisplayPreferences,
        accountEmail: String?,
        defaults: UserDefaults = .standard
    ) async {
        guard preferences.notificationsEnabled else { return }
        guard preferences.notifyOnSessionExpired else { return }
        if defaults.bool(forKey: sessionExpiredFiredKey) { return }

        let authorized = await requestAuthorizationIfNeeded()
        guard authorized else { return }

        #if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        content.title = "Cursor session expired"
        if let accountEmail, !accountEmail.isEmpty {
            content.body = "\(accountEmail) needs to sign in again. Open Settings → Authentication."
        } else {
            content.body = "Sign in again to keep usage updating. Open Settings → Authentication."
        }
        content.sound = preferences.notificationContent.playSound ? .default : nil

        let request = UNNotificationRequest(
            identifier: "cursor-usage-session-expired-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
        defaults.set(true, forKey: sessionExpiredFiredKey)
        #endif
    }

    private static func cycleIdentity(for snapshot: UsageSnapshot) -> String {
        if let end = snapshot.billingCycleEnd {
            return ISO8601DateFormatter().string(from: end)
        }
        return "unknown-cycle"
    }

    private static func leadingPoolLabel(for snapshot: UsageSnapshot) -> String {
        let candidates: [(String, Double?)] = [
            ("Other Models", snapshot.otherModelsPercentUsed),
            ("Cursor Models", snapshot.cursorModelsPercentUsed),
            ("Total included", snapshot.totalPercentUsed),
        ]
        return candidates
            .compactMap { name, value in value.map { (name, $0) } }
            .max(by: { $0.1 < $1.1 })?
            .0 ?? "usage"
    }

    #if canImport(UserNotifications)
    private static func postUsageNotification(
        threshold: Double,
        current: Double,
        poolLabel: String,
        snapshot: UsageSnapshot,
        contentOptions: DisplayPreferences.NotificationContent
    ) async {
        let content = UNMutableNotificationContent()
        if contentOptions.includePlanName {
            content.title = "Cursor \(snapshot.planDisplayName) · \(Int(threshold))% threshold"
        } else {
            content.title = "Cursor usage · \(Int(threshold))% threshold"
        }

        var parts: [String] = []
        if contentOptions.includePoolPercent {
            parts.append("\(poolLabel) at \(Int(current.rounded()))%")
        } else {
            parts.append("\(poolLabel) crossed \(Int(threshold))%")
        }
        if contentOptions.includeSpend, let used = snapshot.planUsedCents, let limit = snapshot.planLimitCents {
            parts.append("\(MenuBarFormatter.usd(used)) / \(MenuBarFormatter.usd(limit)) included")
        }
        if contentOptions.includeDaysRemaining, let days = snapshot.daysRemainingInCycle {
            parts.append("\(days)d left in cycle")
        }
        content.body = parts.joined(separator: " · ")
        content.sound = contentOptions.playSound ? .default : nil

        let request = UNNotificationRequest(
            identifier: "cursor-usage-\(Int(threshold))-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
    #endif
}
