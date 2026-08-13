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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                AppLogo(size: 16)
                Text(entry.snapshot?.planDisplayName ?? "Cursor")
                    .font(.caption.weight(.semibold))
                Spacer()
                if entry.snapshot?.showWarning == true {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .accessibilityLabel("Usage warning")
                }
            }
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
                Text("Open the menu bar app to sync")
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
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                AppLogo(size: 18)
                Text(entry.snapshot?.planDisplayName ?? "Cursor")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let used = entry.snapshot?.planUsedCents, let limit = entry.snapshot?.planLimitCents {
                    Text("\(usd(used)) / \(usd(limit))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if entry.snapshot?.showWarning == true {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .accessibilityLabel("Usage warning")
                }
            }
            if let snap = entry.snapshot {
                poolRow("Cursor Models", percent: snap.cursorModelsPercentUsed, color: Color(red: 0.22, green: 0.48, blue: 0.86))
                poolRow("Other Models", percent: snap.otherModelsPercentUsed, color: Color(red: 0.55, green: 0.35, blue: 0.82))
                poolRow("Total", percent: snap.totalPercentUsed, color: Color(red: 0.20, green: 0.55, blue: 0.58))
            } else {
                Text("Open Cursor Usage Tracker to sync.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func poolRow(_ title: String, percent: Double?, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption2)
                .frame(width: 92, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(1, max(0, (percent ?? 0) / 100)))
                }
            }
            .frame(height: 6)
            Text(percent.map { "\(Int($0.rounded()))%" } ?? "—")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .frame(width: 36, alignment: .trailing)
        }
    }

    private func usd(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        if dollars == floor(dollars) {
            return String(format: "$%.0f", dollars)
        }
        return String(format: "$%.2f", dollars)
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
        .description("Cursor Models, Other Models, and included spend on your desktop.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
