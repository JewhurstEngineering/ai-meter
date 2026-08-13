import SwiftUI
import AppKit

struct UsageProgressBar: View {
    let percent: Double
    var tint: Color? = nil
    var pattern: ProgressBarPattern = .stripes
    @Environment(\.appTheme) private var theme
    @Environment(\.appUsePatterns) private var usePatterns
    @Environment(\.appHighContrast) private var highContrast

    var body: some View {
        GeometryReader { geo in
            let clamped = min(max(percent / 100.0, 0), 1)
            let color = tint ?? theme.poolColor(percent: percent)
            let fillWidth = max(6, geo.size.width * clamped)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(highContrast ? 0.28 : 0.14))
                ZStack {
                    Capsule()
                        .fill(color)
                    if usePatterns {
                        pattern.overlay
                            .foregroundStyle(Color.white.opacity(highContrast ? 0.55 : 0.38))
                            .clipShape(Capsule())
                    }
                }
                .frame(width: fillWidth)
            }
        }
        .frame(height: highContrast ? 10 : 8)
        .accessibilityValue("\(Int(percent.rounded())) percent")
    }
}

enum ProgressBarPattern {
    case stripes, dots, hatch, dashes

    static func forPool(_ title: String) -> ProgressBarPattern {
        switch title {
        case "Cursor Models": return .stripes
        case "Other Models": return .dots
        case "Total included", "Total Included", "Total": return .hatch
        default: return .dashes
        }
    }

    @ViewBuilder
    var overlay: some View {
        switch self {
        case .stripes:
            Canvas { ctx, size in
                var x: CGFloat = -size.height
                while x < size.width + size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    ctx.stroke(path, with: .foreground, lineWidth: 2)
                    x += 7
                }
            }
        case .dots:
            Canvas { ctx, size in
                let step: CGFloat = 6
                var x: CGFloat = 4
                while x < size.width {
                    let r = CGRect(x: x - 1.2, y: size.height / 2 - 1.2, width: 2.4, height: 2.4)
                    ctx.fill(Path(ellipseIn: r), with: .foreground)
                    x += step
                }
            }
        case .hatch:
            Canvas { ctx, size in
                var x: CGFloat = -size.height
                while x < size.width + size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: x + size.height, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    ctx.stroke(path, with: .foreground, lineWidth: 1.5)
                    x += 6
                }
            }
        case .dashes:
            Canvas { ctx, size in
                var x: CGFloat = 3
                while x < size.width {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: size.height / 2))
                    path.addLine(to: CGPoint(x: x + 4, y: size.height / 2))
                    ctx.stroke(path, with: .foreground, lineWidth: 2)
                    x += 8
                }
            }
        }
    }
}

struct SettingsPanel<Content: View>: View {
    let title: String
    var systemImage: String
    var subtitle: String? = nil
    var compact: Bool = false
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
                        .font(compact ? .subheadline.weight(.semibold) : .headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            content()
        }
        .padding(compact ? 10 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
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

struct MetricToggleRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.subheadline)
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(ReliableSwitchToggleStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
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
