import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { cycleKey, evaluateThresholds } from "./NotificationService";
import type { MeterConfiguration, UsageSnapshot } from "./types";

const config: MeterConfiguration = {
  refreshIntervalMinutes: 5,
  statusBarEnabled: true,
  statusBar: { cursorModels: true, otherModels: true, total: true, grokBot: true },
  notificationsEnabled: true,
  warningPercent: 85,
  criticalPercent: 95,
  useFixture: false,
};

function snap(percent: number, cycle = "2026-09-01"): UsageSnapshot {
  return {
    fetchedAt: "2026-08-19T12:00:00.000Z",
    provider: "cursor",
    membershipType: "pro",
    planDisplayName: "Pro",
    billingCycleEnd: cycle,
    otherModelsPercentUsed: percent,
    onDemandEnabled: false,
    modelBreakdown: [],
    displayMessages: {},
    freshness: "live",
    dataSource: "cursor-dashboard-api",
  };
}

describe("evaluateThresholds", () => {
  it("notifies once at warning and once at critical", () => {
    const warn = evaluateThresholds(snap(84), config, undefined);
    assert.equal(warn.crossings.length, 0);

    const first = evaluateThresholds(snap(85), config, warn.nextState);
    assert.equal(first.crossings.some((c) => c.level === "warning"), true);

    const dup = evaluateThresholds(snap(86), config, first.nextState);
    assert.equal(dup.crossings.length, 0);

    const crit = evaluateThresholds(snap(95), config, dup.nextState);
    assert.equal(crit.crossings.some((c) => c.level === "critical"), true);

    const critDup = evaluateThresholds(snap(96), config, crit.nextState);
    assert.equal(critDup.crossings.length, 0);
  });

  it("resets when the billing cycle changes", () => {
    const first = evaluateThresholds(snap(90, "cycle-a"), config, undefined);
    assert.ok(first.crossings.length > 0);
    const next = evaluateThresholds(snap(90, "cycle-b"), config, first.nextState);
    assert.ok(next.crossings.length > 0);
    assert.equal(cycleKey(snap(90, "cycle-b")), "cycle-b");
  });
});
