import SwiftUI
import AppKit
import AIMeterCore

struct SettingsPanel<Content: View>: View {
    let title: String
    var systemImage: String
    var subtitle: String? = nil
    var compact: Bool = false
    /// Stretch to the tallest sibling in an `HStack`.
    var fillsHeight: Bool = false
    @ViewBuilder var content: () -> Content
    @Environment(\.appTheme) private var theme
    @Environment(\.appHighContrast) private var highContrast

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            HStack(spacing: compact ? 8 : 10) {
                Image(systemName: systemImage)
                    .font(compact ? .body : .title3)
                    .foregroundStyle(theme.tint)
                    .frame(width: compact ? 22 : 28, height: compact ? 22 : 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .appFont(compact ? .subheadline : .headline, weight: .semibold)
                    if let subtitle {
                        Text(subtitle)
                            .appFont(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            content()
            if fillsHeight {
                Spacer(minLength: 0)
            }
        }
        .padding(compact ? 10 : 14)
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                .strokeBorder(
                    Color.primary.opacity(highContrast ? 0.42 : 0.08),
                    lineWidth: highContrast ? 2 : 1
                )
        )
    }
}

/// Tallest sibling wins. Use on each column, then `onPreferenceChange` + `minHeight`.
struct MatchedHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    func reportMatchedHeight() -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(key: MatchedHeightKey.self, value: geo.size.height)
            }
        )
    }

    func fillMatchedHeight(_ height: CGFloat) -> some View {
        frame(minHeight: height > 0 ? height : nil, alignment: .top)
    }
}

struct MetricToggleRow: View {
    let title: String
    let systemImage: String
    var providers: [ProviderKind] = []
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .appFont(.subheadline)
            if !providers.isEmpty {
                ProviderScopeIcons(providers: providers)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(ReliableSwitchToggleStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityTitle: String {
        guard !providers.isEmpty else { return title }
        let names = providers.map(\.displayName).joined(separator: " and ")
        return "\(title), \(names)"
    }
}

/// Tiny provider glyphs so a setting’s audience is obvious (Claude + Codex vs Cursor).
struct ProviderScopeIcons: View {
    let providers: [ProviderKind]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(providers) { provider in
                Image(systemName: provider.systemImage)
                    .font(.caption2.weight(.semibold))
                    .accessibilityLabel(provider.displayName)
            }
        }
        .foregroundStyle(.secondary)
        .help(providers.map(\.displayName).joined(separator: " · "))
    }
}

/// Compact switch that does not rely on AppKit’s inactive-window switch chrome.
struct ReliableSwitchToggleStyle: ToggleStyle {
    var onColor: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        ThemedSwitch(configuration: configuration, onColor: onColor)
    }
}

private struct ThemedSwitch: View {
    let configuration: ToggleStyleConfiguration
    var onColor: Color?
    @Environment(\.appTheme) private var theme

    var body: some View {
        let isOn = configuration.isOn
        let fill = onColor ?? theme.tint
        HStack(spacing: 0) {
            configuration.label
            Capsule()
                .fill(isOn ? fill : Color.primary.opacity(0.18))
                .frame(width: 34, height: 20)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .shadow(color: .black.opacity(0.22), radius: 1, y: 0.5)
                        .frame(width: 16, height: 16)
                        .padding(2)
                }
                .animation(.easeInOut(duration: 0.12), value: isOn)
                .onTapGesture {
                    configuration.isOn.toggle()
                }
                .accessibilityAddTraits(.isButton)
        }
    }
}
