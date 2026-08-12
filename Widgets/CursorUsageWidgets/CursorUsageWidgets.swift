import WidgetKit
import SwiftUI
import CursorUsageCore

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, snapshot: WidgetSnapshotStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = Entry(date: .now, snapshot: WidgetSnapshotStore.read())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct CursorUsageWidgetEntryView: View {
    var entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.snapshot?.planDisplayName ?? "Cursor")
                .font(.caption.weight(.semibold))
            if let om = entry.snapshot?.otherModelsPercentUsed {
                Text("\(Int(om.rounded()))%")
                    .font(.title.bold())
                    .monospacedDigit()
                Text("Other Models")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if let cm = entry.snapshot?.cursorModelsPercentUsed {
                Text("\(Int(cm.rounded()))%")
                    .font(.title.bold())
                    .monospacedDigit()
                Text("Cursor Models")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Open app to sync")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let days = entry.snapshot?.daysRemaining {
                Text("\(days)d left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
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
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CursorUsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Cursor Usage")
        .description("Glance at Cursor Models / Other Models usage.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
