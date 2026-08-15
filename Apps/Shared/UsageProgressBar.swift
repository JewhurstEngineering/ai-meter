import SwiftUI
import AIMeterCore

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
        case "Cursor Models", "5-hour", "Session": return .stripes
        case "Other Models", "7-day", "Weekly": return .dots
        case "Total included", "Total Included", "Total": return .hatch
        default: return .dashes
        }
    }

    static func forRole(_ role: QuotaWindowRole) -> ProgressBarPattern {
        switch role {
        case .cursorModels, .session: return .stripes
        case .otherModels, .weekly: return .dots
        case .totalIncluded: return .hatch
        case .extra: return .dashes
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
