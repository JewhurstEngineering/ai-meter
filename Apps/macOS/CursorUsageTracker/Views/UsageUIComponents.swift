import SwiftUI
import AppKit

enum UsageAppearance {
    static func poolColor(percent: Double) -> Color {
        switch percent {
        case ..<60: return Color(red: 0.18, green: 0.62, blue: 0.48) // teal-green
        case ..<85: return Color(red: 0.90, green: 0.62, blue: 0.16) // amber
        default: return Color(red: 0.86, green: 0.28, blue: 0.30) // coral red
        }
    }

    static var accentCursorModels: Color { Color(red: 0.22, green: 0.48, blue: 0.86) }
    static var accentOtherModels: Color { Color(red: 0.55, green: 0.35, blue: 0.82) }
    static var accentTotal: Color { Color(red: 0.20, green: 0.55, blue: 0.58) }
    static var accentSpend: Color { Color(red: 0.15, green: 0.45, blue: 0.40) }

    static func color(forPool title: String, percent: Double) -> Color {
        // Prefer semantic pool accent until high usage, then warn by threshold color.
        if percent >= 85 { return poolColor(percent: percent) }
        switch title {
        case "Cursor Models": return accentCursorModels
        case "Other Models": return accentOtherModels
        case "Total included", "Total Included": return accentTotal
        default: return poolColor(percent: percent)
        }
    }
}

struct UsageProgressBar: View {
    let percent: Double
    var tint: Color? = nil

    var body: some View {
        GeometryReader { geo in
            let clamped = min(max(percent / 100.0, 0), 1)
            let color = tint ?? UsageAppearance.poolColor(percent: percent)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(color.gradient)
                    .frame(width: max(6, geo.size.width * clamped))
            }
        }
        .frame(height: 8)
    }
}

struct SettingsPanel<Content: View>: View {
    let title: String
    var systemImage: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct MetricToggleRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }
}
