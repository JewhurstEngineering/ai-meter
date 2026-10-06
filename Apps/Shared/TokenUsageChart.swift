import SwiftUI
import Charts
import AIMeterCore

/// Daily token bars by model. Same ranges as cursor.com/dashboard/usage.
struct TokenUsageChart: View {
    let days: [UsageSnapshot.DailySpend]
    var onDemandEnabled: Bool = false
    var onDemandUsedCents: Int?
    var height: CGFloat = 168
    var showsTitle: Bool = true

    @State private var range: TokenUsageRange = .thirtyDays

    private static let palette: [Color] = [
        Color(red: 0.16, green: 0.62, blue: 0.36),
        Color(red: 0.93, green: 0.70, blue: 0.22),
        Color(red: 0.24, green: 0.46, blue: 0.84),
        Color(red: 0.16, green: 0.70, blue: 0.74),
        Color(red: 0.54, green: 0.36, blue: 0.78),
        Color(red: 0.90, green: 0.46, blue: 0.20),
        Color(red: 0.28, green: 0.54, blue: 0.70),
        Color(red: 0.84, green: 0.38, blue: 0.54),
    ]

    var body: some View {
        let summary = TokenUsageSeries.summary(
            days: days,
            range: range,
            onDemandEnabled: onDemandEnabled,
            onDemandUsedCents: onDemandUsedCents
        )
        VStack(alignment: .leading, spacing: 8) {
            header(summary)
            if showsWaiting(summary) {
                Text(waitingMessage(summary))
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            } else {
                statRow(summary)
                if summary.segments.isEmpty {
                    Text("No tokens in this range.")
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                } else {
                    chart(summary)
                    legend(summary)
                }
                Text("Input, output, and cache, by day.")
                    .appFont(.caption2)
                    .foregroundStyle(.secondary)
                if summary.includedTokens == nil {
                    Text("On-demand is on, so included and on-demand tokens aren't split.")
                        .appFont(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityText(summary))
    }

    private func header(_ summary: TokenUsageSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                if showsTitle {
                    Text("Tokens by day")
                        .appFont(.caption, weight: .semibold)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(rangeLabel(summary))
                    .appFont(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ViewThatFits(in: .horizontal) {
                chipRow
                ScrollView(.horizontal, showsIndicators: false) {
                    chipRow
                }
            }
        }
    }

    private var chipRow: some View {
        HStack(spacing: 4) {
            ForEach(TokenUsageRange.allCases) { item in
                let selected = item == range
                Button {
                    range = item
                } label: {
                    Text(item.title)
                        .appFont(.caption2, weight: selected ? .semibold : .regular)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selected ? Color.primary.opacity(0.12) : Color.primary.opacity(0.04))
                        )
                }
                .buttonStyle(.borderless)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func statRow(_ summary: TokenUsageSummary) -> some View {
        HStack(spacing: 6) {
            stat("Total tokens", MenuBarFormatter.compactCount(summary.totalTokens))
            stat("Included", tokenText(summary.includedTokens))
            stat("On-demand", tokenText(summary.onDemandTokens))
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .appFont(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .appFont(.subheadline, weight: .semibold, mono: true)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func chart(_ summary: TokenUsageSummary) -> some View {
        let axisEnd = Calendar.current.date(byAdding: .day, value: 1, to: summary.rangeEnd) ?? summary.rangeEnd
        return Chart(summary.segments) { segment in
            BarMark(
                x: .value("Day", segment.day, unit: .day),
                y: .value("Tokens", segment.tokens)
            )
            .foregroundStyle(by: .value("Model", segment.model))
        }
        .chartForegroundStyleScale(domain: summary.legend, range: colors(for: summary.legend))
        .chartLegend(.hidden)
        .chartXScale(domain: summary.rangeStart ... axisEnd)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: labelStride(summary))) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.month(.defaultDigits).day()))
                            .appFont(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisValueLabel {
                    if let tokens = value.as(Int.self) ?? value.as(Double.self).map({ Int($0.rounded()) }) {
                        Text(MenuBarFormatter.compactCount(tokens))
                            .appFont(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: height)
        .accessibilityLabel("Token usage by day")
    }

    private func legend(_ summary: TokenUsageSummary) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
            alignment: .leading,
            spacing: 4
        ) {
            ForEach(Array(summary.legend.enumerated()), id: \.element) { index, model in
                HStack(spacing: 5) {
                    Circle()
                        .fill(colors(for: summary.legend)[index])
                        .frame(width: 7, height: 7)
                    Text(model)
                        .appFont(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private func colors(for legend: [String]) -> [Color] {
        legend.indices.map { Self.palette[$0 % Self.palette.count] }
    }

    private func tokenText(_ tokens: Int?) -> String {
        guard let tokens else { return "—" }
        return MenuBarFormatter.compactCount(tokens)
    }

    private func rangeLabel(_ summary: TokenUsageSummary) -> String {
        let style = Date.FormatStyle().month(.abbreviated).day()
        if Calendar.current.isDate(summary.rangeStart, inSameDayAs: summary.rangeEnd) {
            return summary.rangeStart.formatted(style)
        }
        return "\(summary.rangeStart.formatted(style)) - \(summary.rangeEnd.formatted(style))"
    }

    private func labelStride(_ summary: TokenUsageSummary) -> Int {
        let days = Calendar.current.dateComponents([.day], from: summary.rangeStart, to: summary.rangeEnd).day ?? 0
        let count = days + 1
        if count <= 8 { return 1 }
        if count <= 16 { return 2 }
        return 5
    }

    private func showsWaiting(_ summary: TokenUsageSummary) -> Bool {
        if summary.awaitingTokenDetail { return true }
        return summary.missingEarlierDays && summary.totalTokens == 0
    }

    private func waitingMessage(_ summary: TokenUsageSummary) -> String {
        if summary.awaitingTokenDetail {
            return "Daily tokens load on the next refresh."
        }
        return "No daily tokens for this range yet. They load on the next refresh."
    }

    private func accessibilityText(_ summary: TokenUsageSummary) -> String {
        "Tokens by day, \(summary.range.title), \(MenuBarFormatter.compactCount(summary.totalTokens)) total"
    }
}
