import WidgetKit
import SwiftUI
import AppIntents
import CursorUsageCore

enum WidgetMetric: String, AppEnum {
    case otherModels
    case cursorModels
    case total
    case spend
    case today
    case daysLeft

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Highlight")
    static var caseDisplayRepresentations: [WidgetMetric: DisplayRepresentation] = [
        .otherModels: "Other Models %",
        .cursorModels: "Cursor Models %",
        .total: "Total included %",
        .spend: "Plan spend",
        .today: "Today’s spend",
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

struct DailyProvider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snapshot: nil, metric: .today)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, snapshot: WidgetSnapshotStore.read(), metric: .today))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = Entry(date: .now, snapshot: WidgetSnapshotStore.read(), metric: .today)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60))))
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
    static let spend = Color(red: 0.18, green: 0.62, blue: 0.45)
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
            if entry.metric == .today || entry.metric == .spend {
                WidgetSparkline(values: sparkValues, accent: WidgetPalette.spend, height: 18)
            } else if let days = entry.snapshot?.daysRemaining {
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
                HStack {
                    footerStat("Today", usd(snap.todaySpendCents))
                    Spacer()
                    footerStat("Avg/day", usd(snap.cycleAverageCents))
                    Spacer()
                    if let days = snap.daysRemaining {
                        footerStat("Left", "\(days)d")
                    }
                }
                .padding(.top, 2)
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

                VStack(alignment: .leading, spacing: 6) {
                    Text("Last 7 days")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    WidgetSparkline(values: sparkValues, accent: WidgetPalette.spend, height: 44)
                    HStack {
                        footerStat("Today", usd(snap.todaySpendCents))
                        Spacer()
                        footerStat("Yesterday", usd(snap.yesterdaySpendCents))
                        Spacer()
                        footerStat("Avg/day", usd(snap.cycleAverageCents))
                        Spacer()
                        footerStat("Pace", usd(snap.remainingPaceCents))
                    }
                }
                .padding(.top, 4)
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

    private func footerStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
        }
    }

    private var emptyLabel: some View {
        Text("Open Cursor Usage Tracker to sync.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var sparkValues: [Int] {
        let values = entry.snapshot?.last7DaySpendCents ?? []
        if values.count == 7 { return values }
        return Array(repeating: 0, count: 7)
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
        case .today:
            return usd(snap.todaySpendCents)
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
        case .today: return "Today"
        case .daysLeft: return "left in cycle"
        }
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))%"
    }

    private func usd(_ cents: Int?) -> String {
        cents.map(MenuBarFormatter.usd) ?? "—"
    }
}

struct DailyUsageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Entry

    var body: some View {
        if family == .systemMedium {
            mediumBody
        } else {
            smallBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                AppLogo(size: 16)
                Text("Today")
                    .font(.caption.weight(.semibold))
                Spacer()
                if entry.snapshot?.showWarning == true {
                    Circle().fill(.red).frame(width: 7, height: 7)
                }
            }
            Spacer(minLength: 0)
            Text(usd(entry.snapshot?.todaySpendCents))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.55)
                .lineLimit(1)
            Text(vsAverage)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            WidgetSparkline(values: sparkValues, accent: WidgetPalette.spend, height: 18)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                AppLogo(size: 18)
                Text(entry.snapshot?.planDisplayName ?? "Cursor")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Daily")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if entry.snapshot != nil {
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(usd(entry.snapshot?.todaySpendCents))
                            .font(.title.monospacedDigit().weight(.bold))
                        Text("today")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    WidgetSparkline(values: sparkValues, accent: WidgetPalette.spend, height: 40)
                        .frame(maxWidth: .infinity)
                }
                HStack {
                    stat("Yesterday", usd(entry.snapshot?.yesterdaySpendCents))
                    Spacer()
                    stat("Avg/day", usd(entry.snapshot?.cycleAverageCents))
                    Spacer()
                    stat("Pace left", usd(entry.snapshot?.remainingPaceCents))
                }
            } else {
                Text("Open Cursor Usage Tracker to sync.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var vsAverage: String {
        guard let today = entry.snapshot?.todaySpendCents, let avg = entry.snapshot?.cycleAverageCents, avg > 0 else {
            return "vs cycle average"
        }
        let delta = today - avg
        if delta == 0 { return "in line with avg" }
        let prefix = delta > 0 ? "+" : "−"
        return "\(prefix)\(MenuBarFormatter.usd(abs(delta))) vs avg"
    }

    private var sparkValues: [Int] {
        let values = entry.snapshot?.last7DaySpendCents ?? []
        if values.count == 7 { return values }
        return Array(repeating: 0, count: 7)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
        }
    }

    private func usd(_ cents: Int?) -> String {
        cents.map(MenuBarFormatter.usd) ?? "—"
    }
}

struct WidgetSparkline: View {
    let values: [Int]
    var accent: Color
    var height: CGFloat

    var body: some View {
        let peak = max(values.max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                Capsule()
                    .fill(index == values.count - 1 ? accent : accent.opacity(0.35))
                    .frame(height: max(3, CGFloat(value) / CGFloat(peak) * height))
            }
        }
        .frame(height: height, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

@main
struct CursorUsageWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CursorUsageWidget()
        CursorDailyWidget()
    }
}

struct CursorUsageWidget: Widget {
    let kind = "CursorUsageWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, provider: Provider()) { entry in
            CursorUsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Cursor Usage")
        .description("Highlight Other Models, Cursor Models, total, spend, today, or days left. Small, medium, and large.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CursorDailyWidget: Widget {
    let kind = "CursorDailyUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyProvider()) { entry in
            DailyUsageWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily usage")
        .description("Today’s spend vs your cycle average, with a 7-day sparkline.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
