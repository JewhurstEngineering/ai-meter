import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Fires local notifications when watched channels hit their menu-bar warning levels,
/// or when a live session becomes unauthorized.
public enum UsageNotificationService {
    private static let firedKeyPrefix = "usageAlert.channel."
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

    public static func clearSessionExpiredDedupe(accountID: UUID? = nil, defaults: UserDefaults = .standard) {
        if let accountID {
            defaults.removeObject(forKey: sessionExpiredKey(accountID))
        } else {
            defaults.removeObject(forKey: sessionExpiredFiredKey)
        }
    }

    private static func sessionExpiredKey(_ accountID: UUID) -> String {
        "\(sessionExpiredFiredKey).\(accountID.uuidString)"
    }

    @MainActor
    public static func evaluate(
        snapshot: UsageSnapshot,
        preferences: DisplayPreferences,
        accountEmail: String? = nil,
        accountID: UUID? = nil,
        defaults: UserDefaults = .standard
    ) async {
        guard preferences.notificationsEnabled else { return }

        let authorized = await requestAuthorizationIfNeeded()
        guard authorized else { return }

        let cycleKey = cycleIdentity(for: snapshot)
        let accountKey = accountID?.uuidString ?? "default"
        let channels = preferences.notificationChannels
        let warnings = preferences.menuBarWarnings
        let contentOptions = preferences.notificationContent

        let watches: [(UsageSnapshot.WarningChannel, Bool, String)] = [
            (.cursorModels, channels.cursorModels, "Cursor Models"),
            (.otherModels, channels.otherModels, "Other Models"),
            (.onDemandAndLimits, channels.onDemandAndLimits, "On-demand & limits"),
            (.totalIncluded, channels.totalIncluded, "Total included"),
        ]

        for (channel, enabled, label) in watches {
            guard enabled else { continue }
            guard let status = snapshot.warningChannelStatus(channel, warnings: warnings), status.triggered else {
                continue
            }
            let key = "\(firedKeyPrefix)\(accountKey).\(cycleKey).\(channel.rawValue)"
            if defaults.bool(forKey: key) { continue }
            await postChannelNotification(
                channelLabel: label,
                detail: status.detail,
                thresholdDescription: thresholdDescription(for: channel, warnings: warnings, snapshot: snapshot),
                snapshot: snapshot,
                contentOptions: contentOptions,
                accountEmail: accountEmail
            )
            defaults.set(true, forKey: key)
        }
    }

    private static func thresholdDescription(
        for channel: UsageSnapshot.WarningChannel,
        warnings: DisplayPreferences.MenuBarWarningThresholds,
        snapshot: UsageSnapshot
    ) -> String {
        switch channel {
        case .cursorModels:
            return "\(Int(warnings.cursorModelsPercent))%"
        case .otherModels:
            return "\(Int(warnings.otherModelsPercent))%"
        case .totalIncluded:
            return "\(Int(warnings.totalIncludedPercent))%"
        case .onDemandAndLimits:
            if snapshot.isOnDemandUnlimited {
                return MenuBarFormatter.usd(warnings.onDemandUnlimitedAlertCents)
            }
            return "\(Int(warnings.onDemandAndLimitsPercent))%"
        }
    }

    @MainActor
    public static func notifySessionExpiredIfNeeded(
        preferences: DisplayPreferences,
        accountEmail: String?,
        accountID: UUID? = nil,
        defaults: UserDefaults = .standard
    ) async {
        guard preferences.notificationsEnabled else { return }
        guard preferences.notifyOnSessionExpired else { return }
        let firedKey = accountID.map { sessionExpiredKey($0) } ?? sessionExpiredFiredKey
        if defaults.bool(forKey: firedKey) { return }

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
            identifier: "cursor-usage-session-expired-\(accountID?.uuidString ?? UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
        defaults.set(true, forKey: firedKey)
        #endif
    }

    private static func cycleIdentity(for snapshot: UsageSnapshot) -> String {
        if let end = snapshot.billingCycleEnd {
            return ISO8601DateFormatter().string(from: end)
        }
        return "unknown-cycle"
    }

    #if canImport(UserNotifications)
    private static func postChannelNotification(
        channelLabel: String,
        detail: String,
        thresholdDescription: String,
        snapshot: UsageSnapshot,
        contentOptions: DisplayPreferences.NotificationContent,
        accountEmail: String?
    ) async {
        let content = UNMutableNotificationContent()
        let who: String
        if contentOptions.includePlanName {
            who = "Cursor \(snapshot.planDisplayName)"
        } else {
            who = "Cursor usage"
        }
        if let accountEmail, !accountEmail.isEmpty {
            content.title = "\(who) · \(channelLabel)"
            content.subtitle = accountEmail
        } else {
            content.title = "\(who) · \(channelLabel)"
        }

        var parts: [String] = []
        if contentOptions.includePoolPercent {
            parts.append("\(channelLabel) at \(detail) (alert \(thresholdDescription))")
        } else {
            parts.append("\(channelLabel) crossed \(thresholdDescription)")
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
            identifier: "cursor-usage-\(channelLabel)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
    #endif
}
