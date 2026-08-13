import SwiftUI
import CursorUsageCore

struct ThemeSettingsView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanel(
                    title: "Appearance",
                    systemImage: "circle.lefthalf.filled",
                    subtitle: "Settings and the popover. The menu bar stays native macOS."
                ) {
                    Picker("Appearance", selection: appearanceBinding) {
                        ForEach(DisplayPreferences.AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                SettingsPanel(
                    title: "Color",
                    systemImage: "paintpalette",
                    subtitle: "Accents for pools, switches, and warnings."
                ) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 168), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(DisplayPreferences.ColorTheme.allCases) { option in
                            ThemeChoiceCard(
                                option: option,
                                selected: store.preferences.colorTheme == option,
                                palette: ThemePalette.resolved(
                                    option,
                                    scheme: previewScheme,
                                    custom: store.preferences.customThemeColors
                                )
                            ) {
                                var prefs = store.preferences
                                prefs.colorTheme = option
                                store.applyPreferences(prefs)
                            }
                        }
                    }
                }

                if store.preferences.colorTheme == .custom {
                    SettingsPanel(
                        title: "Custom colors",
                        systemImage: "eyedropper",
                        subtitle: "Four colors for the metrics in Settings and the popover."
                    ) {
                        HStack(alignment: .top, spacing: 16) {
                            customPicker("Cursor Models", \.cursorModels)
                            customPicker("Other Models", \.otherModels)
                            customPicker("Total included", \.total)
                            customPicker("Subscription $", \.spend)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var previewScheme: ColorScheme {
        store.preferences.appearanceMode.colorScheme(systemIsDark: SystemAppearanceMonitor.shared.isDark)
    }

    private var appearanceBinding: Binding<DisplayPreferences.AppearanceMode> {
        Binding(
            get: { store.preferences.appearanceMode },
            set: { value in
                var prefs = store.preferences
                prefs.appearanceMode = value
                store.applyPreferences(prefs)
            }
        )
    }

    private func customPicker(
        _ title: String,
        _ keyPath: WritableKeyPath<DisplayPreferences.CustomThemeColors, DisplayPreferences.ThemeSwatch>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ColorPicker(
                title,
                selection: Binding(
                    get: { store.preferences.customThemeColors[keyPath: keyPath].color },
                    set: { newColor in
                        var prefs = store.preferences
                        prefs.customThemeColors[keyPath: keyPath] = DisplayPreferences.ThemeSwatch(newColor)
                        store.applyPreferences(prefs)
                    }
                ),
                supportsOpacity: false
            )
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ThemeChoiceCard: View {
    let option: DisplayPreferences.ColorTheme
    let selected: Bool
    let palette: ThemePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(Array(palette.swatches.enumerated()), id: \.offset) { _, color in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(color)
                            .frame(height: 22)
                    }
                }
                Text(option.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(option.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 28, alignment: .top)
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
                        selected ? palette.tint : Color.primary.opacity(0.10),
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
}
