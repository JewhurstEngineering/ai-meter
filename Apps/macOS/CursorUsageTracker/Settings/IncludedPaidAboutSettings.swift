import SwiftUI
import CursorUsageCore

struct IncludedUsageSettingsView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        Form {
            if let snapshot = store.snapshot {
                Section("Subscription") {
                    LabeledContent("Plan", value: snapshot.planDisplayName)
                    LabeledContent("Status", value: snapshot.subscriptionStatus ?? "—")
                    if let used = snapshot.planUsedCents {
                        LabeledContent("Current period total", value: MenuBarFormatter.usd(used))
                    }
                    if let start = snapshot.billingCycleStart, let end = snapshot.billingCycleEnd {
                        LabeledContent(
                            "Billing period",
                            value: "\(start.formatted(date: .abbreviated, time: .shortened)) – \(end.formatted(date: .abbreviated, time: .shortened))"
                        )
                    }
                    if let days = snapshot.daysRemainingInCycle {
                        LabeledContent("Days remaining", value: "\(days) days left")
                    }
                }
                Section("Included pools") {
                    if let p = snapshot.cursorModelsPercentUsed {
                        LabeledContent("Cursor Models", value: "\(Int(p.rounded()))% used")
                    }
                    if let p = snapshot.otherModelsPercentUsed {
                        LabeledContent("Other Models", value: "\(Int(p.rounded()))% used")
                    }
                    if let p = snapshot.totalPercentUsed {
                        LabeledContent("Total included", value: String(format: "%.1f%%", p))
                    }
                    if let bonus = snapshot.bonusCents, bonus > 0 {
                        LabeledContent("Bonus", value: MenuBarFormatter.usd(bonus))
                    }
                }
                Section("Models this period") {
                    ForEach(snapshot.modelBreakdown) { row in
                        LabeledContent(row.model, value: MenuBarFormatter.usd(row.totalCents))
                    }
                    if let total = snapshot.totalModelCostCents {
                        LabeledContent("Total", value: MenuBarFormatter.usd(total))
                            .fontWeight(.semibold)
                    }
                }
            } else {
                Text("Sign in and refresh to see included usage.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct PaidUsageSettingsView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        Form {
            Section("Usage Based Pricing") {
                if let snapshot = store.snapshot {
                    LabeledContent("Usage-based pricing") {
                        Text(snapshot.onDemandEnabled ? "Enabled" : "Disabled")
                            .foregroundStyle(snapshot.onDemandEnabled ? Color.primary : Color.red)
                    }
                    if let used = snapshot.onDemandUsedCents {
                        LabeledContent("Billable usage", value: MenuBarFormatter.usd(used))
                    }
                    if let limit = snapshot.onDemandLimitCents {
                        LabeledContent("Current usage limit", value: MenuBarFormatter.usd(limit))
                    } else {
                        LabeledContent("Current usage limit", value: snapshot.onDemandEnabled ? "—" : "$0")
                    }
                } else {
                    Text("Sign in and refresh to see paid usage.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutSettingsView: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("App", value: "Cursor Usage Tracker")
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
                Text("Personal open-source menu bar meter for Cursor Pro, Pro+, and Ultra. Unofficial session APIs may change; re-auth when needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
