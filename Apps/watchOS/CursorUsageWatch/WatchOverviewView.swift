import SwiftUI
import CursorUsageCore

struct WatchOverviewView: View {
    @EnvironmentObject private var session: WatchSessionBridge

    var body: some View {
        NavigationStack {
            Group {
                if let snap = session.snapshot {
                    usage(snap)
                } else {
                    ContentUnavailableView(
                        "Waiting for iPhone",
                        systemImage: "iphone",
                        description: Text("Open Cursor Usage on iPhone to sync a snapshot. Tokens never come to the Watch.")
                    )
                }
            }
            .navigationTitle("Cursor")
        }
    }

    @ViewBuilder
    private func usage(_ snap: WidgetSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(snap.planDisplayName)
                        .font(.headline)
                    Spacer()
                    if snap.showWarning {
                        Circle().fill(.red).frame(width: 6, height: 6)
                    }
                }

                Text(percent(snap.otherModelsPercentUsed))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("Other Models")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                metric("Cursor", value: percent(snap.cursorModelsPercentUsed))
                metric("Total", value: percent(snap.totalPercentUsed))

                if let used = snap.planUsedCents, let limit = snap.planLimitCents {
                    metric("Spend", value: "\(MenuBarFormatter.usd(used)) / \(MenuBarFormatter.usd(limit))")
                }

                if let days = snap.daysRemaining {
                    metric("Cycle", value: "\(days)d left")
                }

                if let top = snap.modelBreakdown?.first {
                    metric("Top model", value: top.model)
                }

                Text(updatedLabel(snap.generatedAt))
                    .font(.caption2)
                    .foregroundStyle(isStale(snap.generatedAt) ? .orange : .secondary)
            }
            .padding(.horizontal, 4)
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .font(.caption)
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))%"
    }

    private func isStale(_ date: Date) -> Bool {
        Date().timeIntervalSince(date) > 15 * 60
    }

    private func updatedLabel(_ date: Date) -> String {
        let minutes = max(0, Int(Date().timeIntervalSince(date) / 60))
        if minutes < 1 { return "Updated just now" }
        if minutes < 60 { return "Updated \(minutes)m ago" }
        let hours = minutes / 60
        return "Updated \(hours)h ago"
    }
}
