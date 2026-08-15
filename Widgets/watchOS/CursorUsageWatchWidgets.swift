import WidgetKit
import SwiftUI
import AIMeterCore

struct WatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchEntry {
        WatchEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        completion(WatchEntry(date: .now, snapshot: WidgetSnapshotStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        let entry = WatchEntry(date: .now, snapshot: WidgetSnapshotStore.read())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

struct WatchEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct WatchComplicationView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WatchEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            rectangular
        case .accessoryInline:
            Text(inlineText)
        case .accessoryCorner:
            Text(percentText)
                .widgetLabel { Text("Other") }
        default:
            circular
        }
    }

    private var circular: some View {
        Gauge(value: gaugeValue) {
            Text("Oth")
        } currentValueLabel: {
            Text(percentText)
                .font(.caption.weight(.bold).monospacedDigit())
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(nil)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.snapshot?.planDisplayName ?? "Cursor")
                .font(.headline)
            Text("Other \(percentText)")
                .font(.caption.monospacedDigit())
            if let used = entry.snapshot?.planUsedCents, let limit = entry.snapshot?.planLimitCents {
                Text("\(MenuBarFormatter.usd(used)) / \(MenuBarFormatter.usd(limit))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var percentText: String {
        guard let value = entry.snapshot?.otherModelsPercentUsed else { return "—" }
        return "\(Int(value.rounded()))%"
    }

    private var inlineText: String {
        "Other \(percentText)"
    }

    private var gaugeValue: Double {
        min(1, max(0, (entry.snapshot?.otherModelsPercentUsed ?? 0) / 100))
    }
}

@main
struct CursorUsageWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CursorUsageWatchWidget()
    }
}

struct CursorUsageWatchWidget: Widget {
    let kind = "CursorUsageWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchProvider()) { entry in
            WatchComplicationView(entry: entry)
        }
        .configurationDisplayName("AI Meter")
        .description("Other Models % from the iPhone snapshot. No tokens on Watch.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
