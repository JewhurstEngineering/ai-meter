import WidgetKit
import SwiftUI
import AppIntents
import CursorUsageCore

enum WidgetMetric: String, AppEnum {
    case otherModels
    case cursorModels
    case total
    case onDemand
    case spend
    case daysLeft
    case rotate

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Show")
    static var caseDisplayRepresentations: [WidgetMetric: DisplayRepresentation] = [
        .cursorModels: "Cursor Models",
        .otherModels: "Other Models",
        .total: "Total",
        .onDemand: "On-demand",
        .spend: "Plan spend",
        .daysLeft: "Days remaining",
        .rotate: "Rotate",
    ]
}

protocol UsageMetricIntent: WidgetConfigurationIntent {
    var metric: WidgetMetric? { get }
    static var defaultMetric: WidgetMetric { get }
}

extension UsageMetricIntent {
    var resolvedMetric: WidgetMetric { metric ?? Self.defaultMetric }
}

struct UsageWidgetIntent: WidgetConfigurationIntent, UsageMetricIntent {
    static var title: LocalizedStringResource = "Usage widget"
    static var description = IntentDescription("Choose which number the small widget highlights.")
    static var defaultMetric: WidgetMetric { .otherModels }

    @Parameter(title: "Show")
    var metric: WidgetMetric?

    init() {
        metric = Self.defaultMetric
    }

    init(metric: WidgetMetric) {
        self.metric = metric
    }
}

struct CursorModelsWidgetIntent: WidgetConfigurationIntent, UsageMetricIntent {
    static var title: LocalizedStringResource = "Cursor Models"
    static var isDiscoverable = false
    static var defaultMetric: WidgetMetric { .cursorModels }

    @Parameter(title: "Show")
    var metric: WidgetMetric?

    init() { metric = Self.defaultMetric }
    init(metric: WidgetMetric) { self.metric = metric }
}

struct OtherModelsWidgetIntent: WidgetConfigurationIntent, UsageMetricIntent {
    static var title: LocalizedStringResource = "Other Models"
    static var isDiscoverable = false
    static var defaultMetric: WidgetMetric { .otherModels }

    @Parameter(title: "Show")
    var metric: WidgetMetric?

    init() { metric = Self.defaultMetric }
    init(metric: WidgetMetric) { self.metric = metric }
}

struct TotalUsageWidgetIntent: WidgetConfigurationIntent, UsageMetricIntent {
    static var title: LocalizedStringResource = "Total included"
    static var isDiscoverable = false
    static var defaultMetric: WidgetMetric { .total }

    @Parameter(title: "Show")
    var metric: WidgetMetric?

    init() { metric = Self.defaultMetric }
    init(metric: WidgetMetric) { self.metric = metric }
}

struct OnDemandWidgetIntent: WidgetConfigurationIntent, UsageMetricIntent {
    static var title: LocalizedStringResource = "On-demand"
    static var isDiscoverable = false
    static var defaultMetric: WidgetMetric { .onDemand }

    @Parameter(title: "Show")
    var metric: WidgetMetric?

    init() { metric = Self.defaultMetric }
    init(metric: WidgetMetric) { self.metric = metric }
}

struct RotateUsageWidgetIntent: WidgetConfigurationIntent, UsageMetricIntent {
    static var title: LocalizedStringResource = "Rotate usage"
    static var isDiscoverable = false
    static var defaultMetric: WidgetMetric { .rotate }

    @Parameter(title: "Show")
    var metric: WidgetMetric?

    init() { metric = Self.defaultMetric }
    init(metric: WidgetMetric) { self.metric = metric }
}

enum UsageTimeline {
    static let rotateInterval: TimeInterval = 15 * 60
    static let rotateCycle: [WidgetMetric] = [.cursorModels, .otherModels, .total, .onDemand]

    static func placeholder() -> Entry {
        Entry(date: .now, snapshot: nil, metric: .otherModels)
    }

    static func snapshot(metric: WidgetMetric) -> Entry {
        let display = metric == .rotate ? rotateCycle[0] : metric
        return Entry(date: .now, snapshot: WidgetSnapshotStore.read(), metric: display)
    }

    static func timeline(metric: WidgetMetric) -> Timeline<Entry> {
        let snap = WidgetSnapshotStore.read()
        let now = Date()
        if metric == .rotate {
            let entries = rotateCycle.enumerated().map { index, display in
                Entry(
                    date: now.addingTimeInterval(TimeInterval(index) * rotateInterval),
                    snapshot: snap,
                    metric: display
                )
            }
            return Timeline(entries: entries, policy: .atEnd)
        }
        return Timeline(
            entries: [Entry(date: now, snapshot: snap, metric: metric)],
            policy: .after(now.addingTimeInterval(60))
        )
    }
}

struct Provider<Intent: UsageMetricIntent>: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> Entry {
        UsageTimeline.placeholder()
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        UsageTimeline.snapshot(metric: configuration.resolvedMetric)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        UsageTimeline.timeline(metric: configuration.resolvedMetric)
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
                mediumFooter(snap)
            } else {
                emptyLabel
            }
            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(size: 20, showSpend: true)
            if let snap = entry.snapshot {
                poolRow("Cursor Models", percent: snap.cursorModelsPercentUsed, color: WidgetPalette.cursor, highlight: entry.metric == .cursorModels)
                poolRow("Other Models", percent: snap.otherModelsPercentUsed, color: WidgetPalette.other, highlight: entry.metric == .otherModels)
                poolRow("Total", percent: snap.totalPercentUsed, color: WidgetPalette.total, highlight: entry.metric == .total)

                Divider().padding(.vertical, 2)

                largeOnDemand(snap)
                largeCycle(snap)
                largeModels(snap)
            } else {
                emptyLabel
                Spacer(minLength: 0)
            }
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

    private func mediumFooter(_ snap: WidgetSnapshot) -> some View {
        HStack(spacing: 0) {
            Text("On-demand \(onDemandCompact(snap))")
            if let bonus = snap.bonusCents, bonus > 0 {
                Text(" · +\(MenuBarFormatter.usd(bonus)) bonus")
            }
            Spacer(minLength: 8)
            if let days = snap.daysRemaining {
                Text("\(days)d left")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.top, 2)
    }

    private func largeOnDemand(_ snap: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("On-demand")
                    .fontWeight(.semibold)
                Spacer()
                Text(snap.onDemandEnabled ? "Enabled" : "Disabled")
                    .fontWeight(.bold)
                    .foregroundStyle(snap.onDemandEnabled ? Color.green : Color.red)
            }
            if let used = snap.onDemandUsedCents {
                HStack {
                    Text("Billable")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(MenuBarFormatter.usd(used))
                        .font(.caption.monospacedDigit().weight(.semibold))
                }
            }
            HStack {
                Text("Limit")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(onDemandLimitLabel(snap))
                    .font(.caption.monospacedDigit().weight(.semibold))
            }
        }
        .font(.caption)
    }

    private func largeCycle(_ snap: WidgetSnapshot) -> some View {
        Group {
            if snap.billingCycleEnd != nil || snap.daysRemaining != nil {
                HStack(spacing: 4) {
                    if let end = snap.billingCycleEnd {
                        Text("Ends \(end.formatted(date: .abbreviated, time: .omitted))")
                    }
                    if let days = snap.daysRemaining {
                        Text("· \(days)d left")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func largeModels(_ snap: WidgetSnapshot) -> some View {
        let rows = Array((snap.modelBreakdown ?? []).prefix(5))
        return VStack(alignment: .leading, spacing: 4) {
            Text("Models this period")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text("No model spend yet this period.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows) { row in
                    HStack(spacing: 8) {
                        Text(row.model)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 8)
                        Text(MenuBarFormatter.usd(row.totalCents))
                            .font(.caption2.monospacedDigit())
                    }
                }
                if let total = snap.totalModelCostCents {
                    HStack {
                        Text("Total")
                            .font(.caption2.weight(.semibold))
                        Spacer()
                        Text(MenuBarFormatter.usd(total))
                            .font(.caption2.monospacedDigit().weight(.semibold))
                    }
                    .padding(.top, 1)
                }
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
        case .onDemand, .rotate:
            return onDemandHero(snap)
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
        case .onDemand, .rotate:
            return onDemandCaption(entry.snapshot)
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

    private func onDemandHero(_ snap: WidgetSnapshot) -> String {
        if !snap.onDemandEnabled { return "Off" }
        if snap.isOnDemandUnlimited {
            return snap.onDemandUsedCents.map(MenuBarFormatter.usd) ?? "Unlimited"
        }
        return snap.onDemandUsedCents.map(MenuBarFormatter.usd) ?? "—"
    }

    private func onDemandCaption(_ snap: WidgetSnapshot?) -> String {
        guard let snap else { return "On-demand" }
        if !snap.onDemandEnabled { return "On-demand" }
        if snap.isOnDemandUnlimited { return "Unlimited" }
        if let limit = snap.onDemandLimitCents, limit > 0 {
            return "of \(MenuBarFormatter.usd(limit)) on-demand"
        }
        return "On-demand"
    }

    private func onDemandCompact(_ snap: WidgetSnapshot) -> String {
        if !snap.onDemandEnabled { return "Off" }
        if snap.isOnDemandUnlimited { return "Unlimited" }
        return snap.onDemandUsedCents.map(MenuBarFormatter.usd) ?? "On"
    }

    private func onDemandLimitLabel(_ snap: WidgetSnapshot) -> String {
        if snap.isOnDemandUnlimited { return "Unlimited" }
        if let limit = snap.onDemandLimitCents { return MenuBarFormatter.usd(limit) }
        return snap.onDemandEnabled ? "—" : "$0"
    }
}

@main
struct CursorUsageWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CursorUsageWidget()
        CursorModelsUsageWidget()
        OtherModelsUsageWidget()
        TotalUsageWidget()
        OnDemandUsageWidget()
        RotateUsageWidget()
    }
}

struct CursorUsageWidget: Widget {
    let kind = "CursorUsageWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, provider: Provider<UsageWidgetIntent>()) { entry in
            CursorUsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Cursor Usage")
        .description("Included pools, spend, and on-demand. Small, medium, and large.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CursorModelsUsageWidget: Widget {
    let kind = "CursorModelsUsageWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, provider: Provider<CursorModelsWidgetIntent>()) { entry in
            CursorUsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Cursor Models")
        .description("Included Cursor Models pool.")
        .supportedFamilies([.systemSmall])
    }
}

struct OtherModelsUsageWidget: Widget {
    let kind = "OtherModelsUsageWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, provider: Provider<OtherModelsWidgetIntent>()) { entry in
            CursorUsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Other Models")
        .description("Included Other Models pool.")
        .supportedFamilies([.systemSmall])
    }
}

struct TotalUsageWidget: Widget {
    let kind = "TotalUsageWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, provider: Provider<TotalUsageWidgetIntent>()) { entry in
            CursorUsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Total")
        .description("Total included usage.")
        .supportedFamilies([.systemSmall])
    }
}

struct OnDemandUsageWidget: Widget {
    let kind = "OnDemandUsageWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, provider: Provider<OnDemandWidgetIntent>()) { entry in
            CursorUsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("On-demand")
        .description("On-demand billable usage.")
        .supportedFamilies([.systemSmall])
    }
}

struct RotateUsageWidget: Widget {
    let kind = "RotateUsageWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, provider: Provider<RotateUsageWidgetIntent>()) { entry in
            CursorUsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Rotate")
        .description("Cycles Cursor, Other, Total, and On-demand every 15 minutes.")
        .supportedFamilies([.systemSmall])
    }
}
