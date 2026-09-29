import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  copySummary,
  formatPercent,
  formatUsdFromCents,
  highestPoolPercent,
  statusBarText,
} from "./formatting";
import type { StatusBarMetrics, UsageSnapshot } from "../core/types";

const allOn: StatusBarMetrics = { cursorModels: true, otherModels: true, total: true, grokBot: true };

const base: UsageSnapshot = {
  fetchedAt: "2026-08-19T12:00:00.000Z",
  provider: "cursor",
  membershipType: "pro",
  planDisplayName: "Pro",
  cursorModelsPercentUsed: 68,
  otherModelsPercentUsed: 42,
  totalPercentUsed: 55,
  onDemandEnabled: true,
  onDemandUsedCents: 842,
  billingCycleEnd: "2026-09-03T00:00:00.000Z",
  modelBreakdown: [],
  displayMessages: {},
  freshness: "live",
  dataSource: "cursor-dashboard-api",
};

describe("statusBarText", () => {
  it("shows enabled pools together", () => {
    assert.equal(statusBarText(base, allOn), "Cursor 68% · Other 42% · Total 55%");
  });

  it("honors per-metric toggles", () => {
    assert.equal(
      statusBarText(base, { cursorModels: true, otherModels: false, total: false, grokBot: false }),
      "Cursor 68%"
    );
    assert.equal(
      statusBarText(base, { cursorModels: false, otherModels: true, total: true, grokBot: false }),
      "Other 42% · Total 55%"
    );
    assert.equal(
      statusBarText({ ...base, grokBotPercentUsed: 18 }, allOn),
      "Cursor 68% · Other 42% · Total 55% · Grok 18%"
    );
  });

  it("shows sign-in and error states", () => {
    assert.equal(statusBarText(undefined, allOn), "AI — Sign In");
    assert.equal(
      statusBarText({ ...base, freshness: "unauthenticated" }, allOn),
      "AI — Sign In"
    );
    assert.equal(statusBarText({ ...base, freshness: "stale" }, allOn), "Cursor 68% · Other 42% · Total 55% · stale");
  });

  it("does not print NaN or $undefined", () => {
    assert.equal(formatPercent(Number.NaN), "—");
    assert.equal(formatUsdFromCents(undefined), "—");
    assert.equal(
      statusBarText(
        {
          ...base,
          cursorModelsPercentUsed: undefined,
          otherModelsPercentUsed: undefined,
          totalPercentUsed: undefined,
        },
        allOn
      ),
      "AI Pro"
    );
  });
});

describe("copySummary", () => {
  it("omits credentials and includes pools", () => {
    const text = copySummary(base, new Date("2026-08-19T12:00:00.000Z"));
    assert.match(text, /Cursor Models: 68%/);
    assert.match(text, /Other Models: 42%/);
    assert.match(text, /Total: 55%/);
    assert.match(text, /On-Demand: \$8\.42/);
    assert.match(text, /via AI Meter/);
    assert.doesNotMatch(text, /token|cookie|@/i);
  });
});

describe("highestPoolPercent", () => {
  it("returns the max defined pool", () => {
    assert.equal(highestPoolPercent(base), 68);
  });
});
