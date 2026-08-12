import SwiftUI
import CursorUsageCore
import ServiceManagement

struct GeneralSettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @State private var notificationPermissionHint: String?

    private let intervals = [1, 2, 5, 15, 30]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanel(
                    title: "App behavior",
                    systemImage: "bolt.horizontal.circle",
                    subtitle: "Launch, sync cadence, and alerts."
                ) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Launch at login", isOn: launchAtLoginBinding)
                            Picker("Refresh every", selection: refreshBinding) {
                                ForEach(intervals, id: \.self) { minutes in
                                    Text("\(minutes) min").tag(minutes)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 180, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        warningAndNotifications
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Text("Menu bar and popover layout live under the Layout tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var warningAndNotifications: some View {
        let threshold = store.preferences.warningThresholdPercent
        // Complementary cool surface; keep the slider itself warning-red.
        let surface = Color(red: 0.93, green: 0.96, blue: 0.98)
        let border = Color(red: 0.55, green: 0.68, blue: 0.78)

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption2)
                    Text("Menu bar warning")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(threshold))%")
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.red.opacity(0.12)))
                }

                Slider(value: thresholdBinding, in: 50...100, step: 1)
                    .tint(.red)

                Text("Shows a red dot on the menu bar icon when Cursor Models, Other Models, or Total included hits this level.")
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(surface))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(border.opacity(0.55), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: notificationsBinding) {
                    Label("System notifications", systemImage: "bell.badge.fill")
                        .font(.subheadline.weight(.semibold))
                }

                Text("Get a macOS banner when usage crosses a selected threshold (once per threshold each billing cycle).")
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)

                if store.preferences.notificationsEnabled {
                    Text("Notify at")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    // Wrap chips so 7 options don't overflow.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(DisplayPreferences.presetNotificationThresholds, id: \.self) { value in
                            let selected = store.preferences.notificationThresholds.contains(value)
                            Button {
                                var prefs = store.preferences
                                prefs.toggleNotificationThreshold(value)
                                store.applyPreferences(prefs)
                            } label: {
                                Text("\(Int(value))%")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(selected ? UsageAppearance.accentOtherModels : Color.primary.opacity(0.06))
                                    )
                                    .foregroundStyle(selected ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if let notificationPermissionHint {
                        Text(notificationPermissionHint)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(UsageAppearance.accentOtherModels.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(UsageAppearance.accentOtherModels.opacity(0.25), lineWidth: 1)
            )
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.launchAtLogin },
            set: { newValue in
                var prefs = store.preferences
                prefs.launchAtLogin = newValue
                store.applyPreferences(prefs)
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {}
            }
        )
    }

    private var refreshBinding: Binding<Int> {
        Binding(
            get: { store.preferences.refreshIntervalMinutes },
            set: { value in
                var prefs = store.preferences
                prefs.refreshIntervalMinutes = value
                store.applyPreferences(prefs)
            }
        )
    }

    private var thresholdBinding: Binding<Double> {
        Binding(
            get: { store.preferences.warningThresholdPercent },
            set: { value in
                var prefs = store.preferences
                prefs.warningThresholdPercent = value
                store.applyPreferences(prefs)
            }
        )
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.notificationsEnabled },
            set: { value in
                var prefs = store.preferences
                prefs.notificationsEnabled = value
                store.applyPreferences(prefs)
                if value {
                    Task {
                        let ok = await UsageNotificationService.requestAuthorizationIfNeeded()
                        notificationPermissionHint = ok
                            ? nil
                            : "Notifications are blocked — enable them for Cursor Usage Tracker in System Settings → Notifications."
                    }
                }
            }
        )
    }
}
