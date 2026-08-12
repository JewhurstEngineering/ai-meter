import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Fires local notifications when watched usage crosses configured thresholds.
/// Dedupes per billing-cycle + threshold so the same alert does not spam.
public enum UsageNotificationService {
    private static let firedKeyPrefix = "usageAlert.fired."

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
            await postNotification(
                threshold: threshold,
                current: highest,
                plan: snapshot.planDisplayName,
                poolLabel: poolLabel
            )
            defaults.set(true, forKey: key)
        }
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
    private static func postNotification(
        threshold: Double,
        current: Double,
        plan: String,
        poolLabel: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "Cursor \(plan) · \(Int(threshold))% threshold"
        content.body = "\(poolLabel) is at \(Int(current.rounded()))% of included usage."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "cursor-usage-\(Int(threshold))-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
    #endif
}
