import SwiftUI
import CursorUsageCore

struct LayoutSettingsView: View {
    @EnvironmentObject private var store: UsageStore
    /// Bumps after Settings becomes key so any leftover native controls redraw.
    @State private var appearanceEpoch = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // | Menu bar metrics | Shared options | Popover metrics |
                HStack(alignment: .top, spacing: 12) {
                    SettingsPanel(
                        title: "Menu bar",
                        systemImage: "menubar.rectangle",
                        subtitle: "Metrics in the system menu bar."
                    ) {
                        metricToggles(menuToggle)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    SettingsPanel(
                        title: "Display",
                        systemImage: "slider.horizontal.3",
                        subtitle: "Shared menu bar presentation."
                    ) {
                        Toggle("Show title text in menu bar", isOn: showMenuBarBinding)
                            .toggleStyle(.checkbox)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Density")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Picker("Density", selection: formatBinding) {
                                Text("Compact").tag(DisplayPreferences.MenuBarFormat.compact)
                                Text("Detailed").tag(DisplayPreferences.MenuBarFormat.detailed)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Labels")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Picker("Labels", selection: labelStyleBinding) {
                                Text("Icons").tag(DisplayPreferences.MenuBarLabelStyle.icons)
                                Text("Words").tag(DisplayPreferences.MenuBarLabelStyle.shortWords)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }

                        Text(labelStyleHelp)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Detailed shows every enabled metric. The live menu bar uses a native status item so macOS is less likely to clip it with “…” (very crowded menu bars can still compress items).")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    SettingsPanel(
                        title: "Popover",
                        systemImage: "rectangle.portrait.on.rectangle.portrait",
                        subtitle: "Metrics in the click panel."
                    ) {
                        metricToggles(popoverToggle, includeModelsThisPeriod: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .id(appearanceEpoch)

                SettingsPanel(
                    title: "Live examples",
                    systemImage: "eye",
                    subtitle: "Interactive — toggles above update these previews immediately."
                ) {
                    HStack(alignment: .top, spacing: 14) {
                        MenuBarPreviewStrip(
                            presentation: store.menuBarPresentation,
                            showText: store.preferences.showInMenuBar
                        )
                        .frame(maxWidth: .infinity, alignment: .top)

                        PopoverPreviewCard(
                            snapshot: store.snapshot,
                            preferences: store.preferences
                        )
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            // Settings often paints before the window is key (accessory app).
            // Rebuild once after focus settles so tinted controls match state.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                appearanceEpoch += 1
            }
        }
    }

    @ViewBuilder
    private func metricToggles(
        _ binding: (WritableKeyPath<DisplayPreferences.SurfaceToggles, Bool>) -> Binding<Bool>,
        includeModelsThisPeriod: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MetricToggleRow(title: "Cursor Models %", systemImage: "sparkles", isOn: binding(\.cursorModelsPercent))
            MetricToggleRow(title: "Other Models %", systemImage: "cpu", isOn: binding(\.otherModelsPercent))
            MetricToggleRow(title: "Total included %", systemImage: "chart.pie", isOn: binding(\.totalPercent))
            MetricToggleRow(title: "Subscription $", systemImage: "dollarsign.circle", isOn: binding(\.planSpend))
            MetricToggleRow(title: "Bonus", systemImage: "gift", isOn: binding(\.bonus))
            MetricToggleRow(title: "On-demand", systemImage: "creditcard", isOn: binding(\.onDemand))
            MetricToggleRow(title: "Days remaining", systemImage: "calendar", isOn: binding(\.daysRemaining))
            if includeModelsThisPeriod {
                MetricToggleRow(
                    title: "Models this period",
                    systemImage: "list.bullet.rectangle",
                    isOn: binding(\.modelsThisPeriod)
                )
            }
        }
    }

    private var labelStyleHelp: String {
        switch store.preferences.menuBarLabelStyle {
        case .icons:
            return "Icons: sparkles / cpu / credit card stand in for each metric."
        case .shortWords:
            return "Words: “Cursor 12% · Other 88% · On-demand off”."
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

// MARK: - Previews (live)

private struct MenuBarPreviewStrip: View {
    let presentation: MenuBarPresentation
    let showText: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Menu bar example")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 5) {
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
                } else {
                    Text("(icon only)")
                        .foregroundStyle(.white.opacity(0.7))
                }
                if presentation.showWarningDot {
                    Circle().fill(.red).frame(width: 6, height: 6)
                }
                Spacer(minLength: 0)
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        let t = preferences.popover
        VStack(alignment: .leading, spacing: 6) {
            Text("Popover example")
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

                if t.cursorModelsPercent {
                    previewPool(title: "Cursor Models", icon: "sparkles", percent: snapshot?.cursorModelsPercentUsed ?? 2)
                }
                if t.otherModelsPercent {
                    previewPool(title: "Other Models", icon: "cpu", percent: snapshot?.otherModelsPercentUsed ?? 88)
                }
                if t.totalPercent {
                    previewPool(title: "Total included", icon: "chart.pie", percent: snapshot?.totalPercentUsed ?? 12)
                }

                if t.planSpend, let used = snapshot?.planUsedCents, let limit = snapshot?.planLimitCents {
                    Label("\(MenuBarFormatter.usd(used)) / \(MenuBarFormatter.usd(limit)) base", systemImage: "dollarsign.circle")
                        .font(.caption2)
                }
                if t.bonus, let bonus = snapshot?.bonusCents, bonus > 0 {
                    Label("+\(MenuBarFormatter.usd(bonus)) bonus", systemImage: "gift")
                        .font(.caption2)
                        .foregroundStyle(UsageAppearance.accentSpend)
                }
                if t.onDemand {
                    HStack {
                        Label("On-demand", systemImage: "creditcard")
                        Spacer()
                        Text(snapshot?.onDemandEnabled == true ? "Enabled" : "Disabled")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(snapshot?.onDemandEnabled == true ? .green : .red)
                    }
                    .font(.caption)
                }
                if t.daysRemaining, let days = snapshot?.daysRemainingInCycle {
                    Label("\(days)d left", systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if t.modelsThisPeriod {
                    Divider()
                    Label("Models this period", systemImage: "list.bullet.rectangle")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    let models = snapshot?.modelBreakdown ?? [
                        .init(model: "claude-fable-5-thinking-high", totalCents: 465),
                        .init(model: "cursor-grok-4.5-high", totalCents: 300),
                    ]
                    ForEach(Array(models.prefix(3))) { row in
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(UsageAppearance.accentOtherModels.opacity(0.7))
                            Text(row.model)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(MenuBarFormatter.usd(row.totalCents))
                                .monospacedDigit()
                        }
                        .font(.caption2)
                    }
                    let total = snapshot?.totalModelCostCents ?? models.reduce(0) { $0 + $1.totalCents }
                    HStack {
                        Text("Total").fontWeight(.semibold)
                        Spacer()
                        Text(MenuBarFormatter.usd(total)).fontWeight(.bold).monospacedDigit()
                    }
                    .font(.caption2)
                }

                if !t.cursorModelsPercent && !t.otherModelsPercent && !t.totalPercent
                    && !t.planSpend && !t.bonus && !t.onDemand && !t.daysRemaining && !t.modelsThisPeriod
                {
                    Text("Enable a Popover metric above to preview it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
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
