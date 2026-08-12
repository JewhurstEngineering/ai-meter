import SwiftUI
import CursorUsageCore

struct LayoutSettingsView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanel(
                    title: "Live preview",
                    systemImage: "eye",
                    subtitle: "Updates as you change the options below."
                ) {
                    MenuBarPreviewStrip(presentation: store.menuBarPresentation, showText: store.preferences.showInMenuBar)
                    PopoverPreviewCard(snapshot: store.snapshot, preferences: store.preferences)
                }

                HStack(alignment: .top, spacing: 16) {
                    SettingsPanel(
                        title: "Menu bar",
                        systemImage: "menubar.rectangle",
                        subtitle: "Compact glance strip in the system menu bar."
                    ) {
                        Toggle("Show title text in menu bar", isOn: showMenuBarBinding)

                        Picker("Density", selection: formatBinding) {
                            Text("Compact").tag(DisplayPreferences.MenuBarFormat.compact)
                            Text("Detailed").tag(DisplayPreferences.MenuBarFormat.detailed)
                        }
                        .pickerStyle(.segmented)

                        Picker("Labels", selection: labelStyleBinding) {
                            Text("Icons").tag(DisplayPreferences.MenuBarLabelStyle.icons)
                            Text("Short words").tag(DisplayPreferences.MenuBarLabelStyle.shortWords)
                        }
                        .pickerStyle(.segmented)

                        Text(labelStyleHelp)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider().padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 10) {
                            MetricToggleRow(title: "Cursor Models %", systemImage: "sparkles", isOn: menuToggle(\.cursorModelsPercent))
                            MetricToggleRow(title: "Other Models %", systemImage: "cpu", isOn: menuToggle(\.otherModelsPercent))
                            MetricToggleRow(title: "Total included %", systemImage: "chart.pie", isOn: menuToggle(\.totalPercent))
                            MetricToggleRow(title: "Subscription $", systemImage: "dollarsign.circle", isOn: menuToggle(\.planSpend))
                            MetricToggleRow(title: "Bonus", systemImage: "gift", isOn: menuToggle(\.bonus))
                            MetricToggleRow(title: "On-demand", systemImage: "creditcard", isOn: menuToggle(\.onDemand))
                            MetricToggleRow(title: "Days remaining", systemImage: "calendar", isOn: menuToggle(\.daysRemaining))
                        }
                    }

                    SettingsPanel(
                        title: "Popover",
                        systemImage: "rectangle.portrait.on.rectangle.portrait",
                        subtitle: "What appears when you click the menu bar item."
                    ) {
                        Text("Detail panel metrics")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 10) {
                            MetricToggleRow(title: "Cursor Models %", systemImage: "sparkles", isOn: popoverToggle(\.cursorModelsPercent))
                            MetricToggleRow(title: "Other Models %", systemImage: "cpu", isOn: popoverToggle(\.otherModelsPercent))
                            MetricToggleRow(title: "Total included %", systemImage: "chart.pie", isOn: popoverToggle(\.totalPercent))
                            MetricToggleRow(title: "Plan spend", systemImage: "dollarsign.circle", isOn: popoverToggle(\.planSpend))
                            MetricToggleRow(title: "Bonus", systemImage: "gift", isOn: popoverToggle(\.bonus))
                            MetricToggleRow(title: "On-demand", systemImage: "creditcard", isOn: popoverToggle(\.onDemand))
                            MetricToggleRow(title: "Days remaining", systemImage: "calendar", isOn: popoverToggle(\.daysRemaining))
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var labelStyleHelp: String {
        switch store.preferences.menuBarLabelStyle {
        case .icons:
            return "Icons mode: sparkles = Cursor Models, cpu = Other Models, credit card = On-demand — no CM/OM/OD text."
        case .shortWords:
            return "Short words mode: “Cursor 12% · Other 88% · On-demand off” — readable, a bit longer."
        }
    }

    private var showMenuBarBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.showInMenuBar },
            set: { value in
                var prefs = store.preferences
                prefs.showInMenuBar = value
                store.applyPreferences(prefs)
            }
        )
    }

    private var formatBinding: Binding<DisplayPreferences.MenuBarFormat> {
        Binding(
            get: { store.preferences.menuBarFormat },
            set: { value in
                var prefs = store.preferences
                prefs.menuBarFormat = value
                store.applyPreferences(prefs)
            }
        )
    }

    private var labelStyleBinding: Binding<DisplayPreferences.MenuBarLabelStyle> {
        Binding(
            get: { store.preferences.menuBarLabelStyle },
            set: { value in
                var prefs = store.preferences
                prefs.menuBarLabelStyle = value
                store.applyPreferences(prefs)
            }
        )
    }

    private func menuToggle(_ keyPath: WritableKeyPath<DisplayPreferences.SurfaceToggles, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.preferences.menuBar[keyPath: keyPath] },
            set: { value in
                var prefs = store.preferences
                prefs.menuBar[keyPath: keyPath] = value
                store.applyPreferences(prefs)
            }
        )
    }

    private func popoverToggle(_ keyPath: WritableKeyPath<DisplayPreferences.SurfaceToggles, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.preferences.popover[keyPath: keyPath] },
            set: { value in
                var prefs = store.preferences
                prefs.popover[keyPath: keyPath] = value
                store.applyPreferences(prefs)
            }
        )
    }
}

// MARK: - Previews

private struct MenuBarPreviewStrip: View {
    let presentation: MenuBarPresentation
    let showText: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Menu bar")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundStyle(.white.opacity(0.95))
                if showText {
                    ForEach(Array(presentation.segments.enumerated()), id: \.offset) { index, segment in
                        if index > 0 {
                            Text("·").foregroundStyle(.white.opacity(0.55))
                        }
                        HStack(spacing: 2) {
                            if let icon = segment.systemImage {
                                Image(systemName: icon)
                            }
                            Text(segment.text)
                        }
                        .foregroundStyle(.white)
                    }
                }
                if presentation.showWarningDot {
                    Circle().fill(.red).frame(width: 6, height: 6)
                }
                Spacer(minLength: 0)
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.18, green: 0.32, blue: 0.55),
                                Color(red: 0.12, green: 0.22, blue: 0.40),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
    }
}

private struct PopoverPreviewCard: View {
    let snapshot: UsageSnapshot?
    let preferences: DisplayPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Popover")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(snapshot?.planDisplayName ?? "Pro+")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if preferences.popover.cursorModelsPercent {
                    previewPool(title: "Cursor Models", icon: "sparkles", percent: snapshot?.cursorModelsPercentUsed ?? 2)
                }
                if preferences.popover.otherModelsPercent {
                    previewPool(title: "Other Models", icon: "cpu", percent: snapshot?.otherModelsPercentUsed ?? 88)
                }
                if preferences.popover.totalPercent {
                    previewPool(title: "Total included", icon: "chart.pie", percent: snapshot?.totalPercentUsed ?? 12)
                }

                if preferences.popover.onDemand {
                    HStack {
                        Label("On-demand", systemImage: "creditcard")
                        Spacer()
                        Text(snapshot?.onDemandEnabled == true ? "Enabled" : "Disabled")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(snapshot?.onDemandEnabled == true ? .green : .red)
                    }
                    .font(.caption)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func previewPool(title: String, icon: String, percent: Double) -> some View {
        let tint = UsageAppearance.color(forPool: title, percent: percent)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text("\(Int(percent.rounded()))%")
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }
            .font(.caption2.weight(.semibold))
            UsageProgressBar(percent: percent, tint: tint)
                .frame(height: 6)
        }
    }
}
