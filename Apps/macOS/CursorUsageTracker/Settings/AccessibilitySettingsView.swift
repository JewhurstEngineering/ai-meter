import SwiftUI
import CursorUsageCore

struct AccessibilitySettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanel(
                    title: "Interface size",
                    systemImage: "textformat.size",
                    subtitle: "Zooms Settings and the popover, including icons and bars. Default always returns to 100%. macOS Zoom (Control–scroll) still works for the whole screen."
                ) {
                    Picker("Interface size", selection: sizeBinding) {
                        ForEach(DisplayPreferences.InterfaceSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel("Interface size")

                    Text("Zooms Settings and the popover — icons, bars, and padding included. Default is 100%.")
                        .appFont(.caption2)
                        .foregroundStyle(.secondary)
                }

                SettingsPanel(
                    title: "Text size",
                    systemImage: "textformat",
                    subtitle: "Makes labels larger without zooming the window or controls."
                ) {
                    Picker("Text size", selection: textSizeBinding) {
                        ForEach(DisplayPreferences.InterfaceSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel("Text size")

                    Text("Use this if you only want bigger type. Interface size still zooms everything.")
                        .appFont(.caption2)
                        .foregroundStyle(.secondary)
                }

                SettingsPanel(
                    title: "Color vision",
                    systemImage: "eye",
                    subtitle: "Replaces Theme accents with palettes that stay distinct. Does not change the menu bar."
                ) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 160), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(DisplayPreferences.ColorVision.allCases) { option in
                            visionCard(option)
                        }
                    }
                }

                SettingsPanel(
                    title: "Don’t rely on color alone",
                    systemImage: "square.grid.3x3",
                    subtitle: "Patterns on progress bars, plus stronger chrome if you want it."
                ) {
                    MetricToggleRow(
                        title: "Patterns on usage bars",
                        systemImage: "circle.dotted",
                        isOn: patternsBinding
                    )
                    MetricToggleRow(
                        title: "High contrast borders",
                        systemImage: "circle.lefthalf.filled",
                        isOn: contrastBinding
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .appFont(.caption2, weight: .semibold)
                            .foregroundStyle(.secondary)
                        previewBar("Cursor Models", 24)
                        previewBar("Other Models", 62)
                        previewBar("Total included", 91)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func previewBar(_ title: String, _ percent: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .appFont(.caption, weight: .semibold)
                Spacer()
                Text("\(Int(percent))%")
                    .appFont(.caption, weight: .bold, mono: true)
                    .foregroundStyle(theme.color(forPool: title, percent: percent))
            }
            UsageProgressBar(
                percent: percent,
                tint: theme.color(forPool: title, percent: percent),
                pattern: .forPool(title)
            )
            .frame(height: 8)
        }
    }

    private func visionCard(_ option: DisplayPreferences.ColorVision) -> some View {
        let selected = store.preferences.colorVision == option
        let swatches = ThemePalette.resolved(store.preferences, scheme: .dark)
            .adapted(for: option, highContrast: false, scheme: .dark)
            .swatches
        return Button {
            var prefs = store.preferences
            prefs.colorVision = option
            if option != .typical {
                prefs.distinguishWithoutColor = true
            }
            store.applyPreferences(prefs)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(Array(swatches.enumerated()), id: \.offset) { _, color in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(color)
                            .frame(height: 22)
                    }
                }
                Text(option.title)
                    .appFont(.subheadline, weight: .semibold)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(option.subtitle)
                    .appFont(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        selected ? theme.tint : Color.primary.opacity(0.10),
                        lineWidth: selected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(option.title)
        .accessibilityHint(option.subtitle)
    }

    private var textSizeBinding: Binding<DisplayPreferences.InterfaceSize> {
        Binding(
            get: { store.preferences.textSize },
            set: { value in
                var prefs = store.preferences
                prefs.textSize = value
                store.applyPreferences(prefs)
            }
        )
    }

    private var sizeBinding: Binding<DisplayPreferences.InterfaceSize> {
        Binding(
            get: { store.preferences.interfaceSize },
            set: { value in
                var prefs = store.preferences
                prefs.interfaceSize = value
                store.applyPreferences(prefs)
            }
        )
    }

    private var patternsBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.distinguishWithoutColor },
            set: { value in
                var prefs = store.preferences
                prefs.distinguishWithoutColor = value
                store.applyPreferences(prefs)
            }
        )
    }

    private var contrastBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.highContrast },
            set: { value in
                var prefs = store.preferences
                prefs.highContrast = value
                store.applyPreferences(prefs)
            }
        )
    }
}
