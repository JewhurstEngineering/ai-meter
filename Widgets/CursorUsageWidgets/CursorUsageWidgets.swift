import WidgetKit
import SwiftUI
import AppIntents
import CursorUsageCore

enum WidgetMetric: String, AppEnum {
    case otherModels
    case cursorModels
    case total
    case spend
    case daysLeft

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Highlight")
    static var caseDisplayRepresentations: [WidgetMetric: DisplayRepresentation] = [
        .otherModels: "Other Models %",
        .cursorModels: "Cursor Models %",
        .total: "Total included %",
        .spend: "Plan spend",
        .daysLeft: "Days remaining",
    ]
}

struct UsageWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Usage widget"
    static var description = IntentDescription("Choose which number the small widget highlights.")

    @Parameter(title: "Highlight")
    var metric: WidgetMetric

    init() {
        metric = .otherModels
    }

    init(metric: WidgetMetric) {
        self.metric = metric
    }
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snapshot: nil, metric: .otherModels)
    }

    func snapshot(for configuration: UsageWidgetIntent, in context: Context) async -> Entry {
        Entry(date: .now, snapshot: WidgetSnapshotStore.read(), metric: configuration.metric)
    }

    func timeline(for configuration: UsageWidgetIntent, in context: Context) async -> Timeline<Entry> {
        let entry = Entry(date: .now, snapshot: WidgetSnapshotStore.read(), metric: configuration.metric)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60)))
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let metric: WidgetMetric
}

private enum WidgetPalette {
    static let cursor = Color(red: 0.22, green: 0.48, blue: 0.86)
    static let other = Color(red: 0.55, green: 0.35, blue: 0.82)
    static let total = Color(red: 0.20, green: 0.55, blue: 0.58)
}

struct CursorUsageWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Entry

    var body: some View {
        switch family {
        case .systemLarge:
            largeBody
        case .systemMedium:
            mediumBody
        default:
            smallBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            header(size: 16, showSpend: false)
            Spacer(minLength: 0)
            Text(heroValue)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.55)
                .lineLimit(1)
            Text(heroCaption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if entry.metric != .daysLeft, let days = entry.snapshot?.daysRemaining {
                Text("\(days)d left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(size: 18, showSpend: true)
            if let snap = entry.snapshot {
                poolRow("Cursor Models", percent: snap.cursorModelsPercentUsed, color: WidgetPalette.cursor, highlight: entry.metric == .cursorModels)
                poolRow("Other Models", percent: snap.otherModelsPercentUsed, color: WidgetPalette.other, highlight: entry.metric == .otherModels)
                poolRow("Total", percent: snap.totalPercentUsed, color: WidgetPalette.total, highlight: entry.metric == .total)
                if let days = snap.daysRemaining {
                    Text("\(days)d left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            } else {
                emptyLabel
            }
            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            header(size: 20, showSpend: true)
            if let snap = entry.snapshot {
                poolRow("Cursor Models", percent: snap.cursorModelsPercentUsed, color: WidgetPalette.cursor, highlight: entry.metric == .cursorModels)
                poolRow("Other Models", percent: snap.otherModelsPercentUsed, color: WidgetPalette.other, highlight: entry.metric == .otherModels)
                poolRow("Total", percent: snap.totalPercentUsed, color: WidgetPalette.total, highlight: entry.metric == .total)
                if let days = snap.daysRemaining {
                    Text("\(days)d left in cycle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            } else {
                emptyLabel
            }
            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func header(size: CGFloat, showSpend: Bool) -> some View {
        HStack(spacing: 6) {
            AppLogo(size: size)
            Text(entry.snapshot?.planDisplayName ?? "Cursor")
                .font(.caption.weight(.semibold))
            Spacer()
            if showSpend, let used = entry.snapshot?.planUsedCents, let limit = entry.snapshot?.planLimitCents {
                Text("\(MenuBarFormatter.usd(used)) / \(MenuBarFormatter.usd(limit))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if entry.snapshot?.showWarning == true {
                Circle().fill(.red).frame(width: 7, height: 7)
                    .accessibilityLabel("Usage warning")
            }
        }
    }

    private func poolRow(_ title: String, percent: Double?, color: Color, highlight: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(highlight ? .caption2.weight(.bold) : .caption2)
                .frame(width: 92, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(1, max(0, (percent ?? 0) / 100)))
                }
            }
            .frame(height: highlight ? 8 : 6)
            Text(percent.map { "\(Int($0.rounded()))%" } ?? "—")
                .font(.caption2.monospacedDigit().weight(highlight ? .bold : .semibold))
                .frame(width: 36, alignment: .trailing)
        }
    }

    private var emptyLabel: some View {
        Text("Open Cursor Usage Tracker to sync.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var heroValue: String {
        guard let snap = entry.snapshot else { return "—" }
        switch entry.metric {
        case .otherModels:
            return percent(snap.otherModelsPercentUsed)
        case .cursorModels:
            return percent(snap.cursorModelsPercentUsed)
        case .total:
            return percent(snap.totalPercentUsed)
        case .spend:
            return snap.planUsedCents.map(MenuBarFormatter.usd) ?? "—"
        case .daysLeft:
            return snap.daysRemaining.map { "\($0)d" } ?? "—"
        }
    }

    private var heroCaption: String {
        switch entry.metric {
        case .otherModels: return "Other Models"
        case .cursorModels: return "Cursor Models"
        case .total: return "Total included"
        case .spend:
            if let limit = entry.snapshot?.planLimitCents {
                return "of \(MenuBarFormatter.usd(limit)) plan"
            }
            return "Plan spend"
        case .daysLeft: return "left in cycle"
        }
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))%"
    }
}

@main
struct CursorUsageWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CursorUsageWidget()
    }
}

struct CursorUsageWidget: Widget {
    let kind = "CursorUsageWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, provider: Provider()) { entry in
            CursorUsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Cursor Usage")
        .description("Highlight Other Models, Cursor Models, total, spend, or days left. Small, medium, and large.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
