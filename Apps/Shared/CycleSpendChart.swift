import SwiftUI
import Charts
import CursorUsageCore

struct CycleSpendChart: View {
    let cycles: [UsageSnapshot.BillingCycleSpend]
    var height: CGFloat = 120
    @Environment(\.appTheme) private var theme

    var body: some View {
        let rows = cycles.sorted { $0.start < $1.start }
        Chart(rows) { row in
            BarMark(
                x: .value("Cycle", row.shortLabel),
                y: .value("Spend", max(0, row.totalCents / 100))
            )
            .foregroundStyle(row.isCurrent ? theme.spend : theme.spend.opacity(0.5))
            .cornerRadius(3)
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisValueLabel {
                    if let dollars = value.as(Double.self) {
                        Text("$\(Int(dollars.rounded()))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .frame(height: height)
        .accessibilityLabel("Spend by billing cycle")
    }
}

struct CursorBillingLinks: View {
    var compact: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            Link(destination: AppAbout.dashboardURL) {
                Label("Cursor dashboard", systemImage: "globe")
            }
            Link(destination: AppAbout.dashboardURL) {
                Label("Billing & invoices", systemImage: "doc.text")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(compact ? .small : .regular)
    }
}
