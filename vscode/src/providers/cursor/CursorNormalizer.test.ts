import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, it } from "node:test";
import { grokBotFromSand, mapCursorSnapshot } from "./CursorNormalizer";
import type {
  AggregatedUsageResponse,
  AuthStripeResponse,
  UsageSummaryResponse,
} from "./CursorTypes";
import { parseFlexibleInt } from "./CursorTypes";

const fixtures = join(__dirname, "..", "..", "..", "fixtures", "cursor");

function load<T>(name: string): T {
  return JSON.parse(readFileSync(join(fixtures, name), "utf8")) as T;
}

describe("mapCursorSnapshot", () => {
  it("parses both Ultra usage pools from fixtures", () => {
    const snap = mapCursorSnapshot({
      summary: load<UsageSummaryResponse>("usage_summary_ultra.json"),
      stripe: load<AuthStripeResponse>("auth_stripe_ultra.json"),
      aggregated: load<AggregatedUsageResponse>("aggregated_usage_ultra.json"),
    });

    assert.equal(snap.membershipType, "ultra");
    assert.equal(snap.planDisplayName, "Ultra");
    assert.equal(snap.cursorModelsPercentUsed, 3.817);
    assert.equal(snap.otherModelsPercentUsed, 100);
    assert.equal(snap.totalPercentUsed, 23.0848);
    assert.equal(snap.planUsedCents, 40000);
    assert.equal(snap.bonusCents, 17712);
    assert.equal(snap.onDemandEnabled, false);
    assert.equal(snap.modelBreakdown.length, 3);
    assert.equal(snap.modelBreakdown[0]?.model, "claude-fable-5-thinking-high");
    assert.equal(snap.modelBreakdown[0]?.inputTokens, 2_421_899);
    assert.equal(snap.dataSource, "cursor-dashboard-api");
  });

  it("handles missing Other Models pool and missing spend", () => {
    const snap = mapCursorSnapshot({
      summary: {
        membershipType: "pro",
        individualUsage: {
          plan: { autoPercentUsed: 12 },
        },
      },
    });
    assert.equal(snap.cursorModelsPercentUsed, 12);
    assert.equal(snap.otherModelsPercentUsed, undefined);
    assert.equal(snap.onDemandEnabled, false);
    assert.equal(snap.onDemandUsedCents, undefined);
    assert.equal(snap.modelBreakdown.length, 0);
  });

  it("handles null values and unknown extra fields", () => {
    const snap = mapCursorSnapshot({
      summary: {
        billingCycleStart: null as unknown as string,
        membershipType: "pro_plus",
        unexpected: true,
        individualUsage: {
          plan: {
            autoPercentUsed: 63,
            apiPercentUsed: 38,
            used: null as unknown as number,
          },
          onDemand: { enabled: true, used: 842, limit: null },
        },
      } as UsageSummaryResponse,
      stripe: { individualMembershipType: "pro_plus" },
    });
    assert.equal(snap.planDisplayName, "Pro+");
    assert.equal(snap.cursorModelsPercentUsed, 63);
    assert.equal(snap.otherModelsPercentUsed, 38);
    assert.equal(snap.onDemandEnabled, true);
    assert.equal(snap.onDemandUsedCents, 842);
    assert.equal(snap.onDemandLimitCents, undefined);
    assert.equal(snap.planUsedCents, undefined);
  });

  it("falls back to stripe membership when summary is empty", () => {
    const snap = mapCursorSnapshot({
      summary: {},
      stripe: { membershipType: "pro", individualMembershipType: "pro" },
    });
    assert.equal(snap.membershipType, "pro");
    assert.equal(snap.planDisplayName, "Pro");
    assert.equal(snap.cursorModelsPercentUsed, undefined);
  });

  it("maps the 68% mock fixture", () => {
    const snap = mapCursorSnapshot({
      summary: load<UsageSummaryResponse>("usage_summary_mock.json"),
    });
    assert.equal(snap.cursorModelsPercentUsed, 68);
    assert.equal(snap.otherModelsPercentUsed, 42);
    assert.equal(snap.onDemandUsedCents, 842);
  });
});

describe("grokBotFromSand", () => {
  it("maps an included weekly allowance and its reset", () => {
    const window = grokBotFromSand({
      usagePercent: 42.4,
      hasNonZeroIncludedLimit: true,
      includedLimitZero: false,
      usesPooledEnterpriseAllowance: false,
      nextResetTimestampUtc: "2026-09-28T00:00:00.000Z",
    });
    assert.equal(window?.percent, 42.4);
    assert.equal(window?.resetsAt, "2026-09-28T00:00:00.000Z");
  });

  it("accepts a string percent and a millisecond reset", () => {
    const window = grokBotFromSand({
      usagePercent: "18",
      hasNonZeroIncludedLimit: true,
      nextResetTimestamp: 1_780_000_000_000,
    });
    assert.equal(window?.percent, 18);
    assert.equal(window?.resetsAt, new Date(1_780_000_000_000).toISOString());
  });

  it("hides plans with no personal allowance", () => {
    assert.equal(
      grokBotFromSand({ usagePercent: 0, hasNonZeroIncludedLimit: false, includedLimitZero: true }),
      undefined
    );
    assert.equal(
      grokBotFromSand({
        usagePercent: 12,
        hasNonZeroIncludedLimit: true,
        usesPooledEnterpriseAllowance: true,
      }),
      undefined
    );
    assert.equal(grokBotFromSand({ hasNonZeroIncludedLimit: true }), undefined);
    assert.equal(grokBotFromSand(undefined), undefined);
  });
});

describe("parseFlexibleInt", () => {
  it("accepts numbers, numeric strings, and ignores junk", () => {
    assert.equal(parseFlexibleInt("2421899"), 2_421_899);
    assert.equal(parseFlexibleInt(12.6), 13);
    assert.equal(parseFlexibleInt(null), undefined);
    assert.equal(parseFlexibleInt("nope"), undefined);
  });
});
