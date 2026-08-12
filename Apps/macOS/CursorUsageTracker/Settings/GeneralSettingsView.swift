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
                    title: "Startup & sync",
                    systemImage: "bolt.horizontal.circle",
                    subtitle: "When the app launches and how often it refreshes."
                ) {
                    HStack(spacing: 20) {
                        Toggle("Launch at login", isOn: launchAtLoginBinding)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 8) {
                            Text("Refresh every")
                                .foregroundStyle(.secondary)
                            Picker("Refresh every", selection: refreshBinding) {
                                ForEach(intervals, id: \.self) { minutes in
                                    Text("\(minutes) min").tag(minutes)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 100, alignment: .trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    menuBarWarningCard
                        .frame(maxWidth: .infinity, alignment: .top)
                    systemNotificationsCard
                        .frame(maxWidth: .infinity, alignment: .top)
                }

                HStack(spacing: 8) {
                    Image(systemName: "rectangle.split.2x1")
                        .foregroundStyle(.tint)
                    Text("Menu bar and popover layout live under the ")
                        + Text("Layout").fontWeight(.semibold)
                        + Text(" tab.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var menuBarWarningCard: some View {
        let threshold = store.preferences.warningThresholdPercent
        let surface = Color(red: 0.93, green: 0.96, blue: 0.98)
        let border = Color(red: 0.55, green: 0.68, blue: 0.78)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "menubar.rectangle")
                    .foregroundStyle(.tint)
                Text("Menu bar warning")
                    .font(.headline)
                Spacer()
                Text("\(Int(threshold))%")
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.red.opacity(0.12)))
            }

            Text("Red dot on the menu bar icon when a watched pool hits this level.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("50%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("100%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Slider(value: thresholdBinding, in: 50...100, step: 1)
                    .tint(.red)
            }

            Label("Watches Cursor Models, Other Models, and Total included", systemImage: "eye")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(surface))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(border.opacity(0.55), lineWidth: 1)
        )
    }

    private var systemNotificationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(UsageAppearance.accentOtherModels)
                Text("System notifications")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: notificationsBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            Text("macOS banner when usage crosses a selected threshold (once per threshold each billing cycle).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if store.preferences.notificationsEnabled {
                Text("Notify at")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 48), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
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
                                .padding(.vertical, 7)
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
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Turn on to choose thresholds.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(UsageAppearance.accentOtherModels.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(UsageAppearance.accentOtherModels.opacity(0.25), lineWidth: 1)
        )
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
