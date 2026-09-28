import type { ModelCost, UsageSnapshot } from "../../core/types";
import { planDisplayName } from "../../utils/formatting";
import type {
  AggregatedUsageResponse,
  AuthStripeResponse,
  SandUsageStatus,
  UsageSummaryResponse,
} from "./CursorTypes";
import { parseFlexibleInt } from "./CursorTypes";

export function parseCursorDate(value: string | undefined): string | undefined {
  if (!value) {
    return undefined;
  }
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? undefined : date.toISOString();
}

/** A personal Grok Bot meter exists only when the plan includes an allowance and reports a percent used. */
export function grokBotFromSand(
  sand: SandUsageStatus | undefined
): { percent: number; resetsAt?: string } | undefined {
  if (!sand) {
    return undefined;
  }
  if (sand.usesPooledEnterpriseAllowance === true || sand.includedLimitZero === true) {
    return undefined;
  }
  if (sand.hasNonZeroIncludedLimit !== true) {
    return undefined;
  }
  const raw = typeof sand.usagePercent === "string" ? Number(sand.usagePercent) : sand.usagePercent;
  const percent = finiteNumber(raw);
  if (percent == null) {
    return undefined;
  }
  return {
    percent: Math.min(100, Math.max(0, percent)),
    resetsAt: parseSandReset(sand.nextResetTimestampUtc ?? sand.nextResetTimestamp),
  };
}

export function mapCursorSnapshot(input: {
  summary: UsageSummaryResponse;
  stripe?: AuthStripeResponse;
  aggregated?: AggregatedUsageResponse;
  sand?: SandUsageStatus;
  fetchedAt?: Date;
  freshness?: UsageSnapshot["freshness"];
}): UsageSnapshot {
  const { summary, stripe, aggregated } = input;
  const membership =
    summary.membershipType ??
    stripe?.individualMembershipType ??
    stripe?.membershipType ??
    "unknown";
  const plan = summary.individualUsage?.plan;
  const onDemand = summary.individualUsage?.onDemand;
  const cursorPct = firstFinite(
    plan?.autoPercentUsed,
    plan?.cursorModelsPercentUsed,
    plan?.firstPartyPercentUsed
  );
  const otherPct = firstFinite(
    plan?.apiPercentUsed,
    plan?.apiModelsPercentUsed,
    plan?.otherModelsPercentUsed
  );
  const grok = grokBotFromSand(input.sand);

  const models: ModelCost[] = (aggregated?.aggregations ?? [])
    .flatMap((row) => {
      if (!row.modelIntent || row.totalCents == null) {
        return [];
      }
      return [
        {
          model: row.modelIntent,
          totalCents: row.totalCents,
          tier: row.tier,
          inputTokens: parseFlexibleInt(row.inputTokens),
          outputTokens: parseFlexibleInt(row.outputTokens),
          cacheWriteTokens: parseFlexibleInt(row.cacheWriteTokens),
          cacheReadTokens: parseFlexibleInt(row.cacheReadTokens),
        },
      ];
    })
    .sort((a, b) => b.totalCents - a.totalCents);

  return {
    fetchedAt: (input.fetchedAt ?? new Date()).toISOString(),
    provider: "cursor",
    membershipType: membership,
    planDisplayName: planDisplayName(membership),
    billingCycleStart: parseCursorDate(summary.billingCycleStart),
    billingCycleEnd: parseCursorDate(summary.billingCycleEnd),
    cursorModelsPercentUsed: cursorPct,
    otherModelsPercentUsed: otherPct,
    totalPercentUsed: finiteNumber(plan?.totalPercentUsed),
    grokBotPercentUsed: grok?.percent,
    grokBotResetsAt: grok?.resetsAt,
    planUsedCents: finiteNumber(plan?.used),
    planLimitCents: finiteNumber(plan?.limit),
    planRemainingCents: finiteNumber(plan?.remaining),
    includedCents: finiteNumber(plan?.breakdown?.included),
    bonusCents: finiteNumber(plan?.breakdown?.bonus),
    onDemandEnabled: onDemand?.enabled ?? false,
    onDemandUsedCents: finiteNumber(onDemand?.used),
    onDemandLimitCents: finiteNumber(onDemand?.limit),
    modelBreakdown: models,
    totalModelCostCents: aggregated?.totalCostCents,
    displayMessages: {
      cursorModels: summary.autoModelSelectedDisplayMessage,
      otherModels: summary.namedModelSelectedDisplayMessage,
    },
    freshness: input.freshness ?? "live",
    dataSource: "cursor-dashboard-api",
  };
}

function parseSandReset(value: string | number | undefined): string | undefined {
  if (value == null || value === "") {
    return undefined;
  }
  if (typeof value === "number" && Number.isFinite(value) && value > 0) {
    const ms = value > 1_000_000_000_000 ? value : value * 1000;
    return new Date(ms).toISOString();
  }
  if (typeof value === "string") {
    const asNumber = Number(value);
    if (value.trim() !== "" && Number.isFinite(asNumber) && asNumber > 1_000_000_000) {
      return parseSandReset(asNumber);
    }
    return parseCursorDate(value);
  }
  return undefined;
}

function finiteNumber(value: number | null | undefined): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function firstFinite(...values: Array<number | null | undefined>): number | undefined {
  for (const value of values) {
    const n = finiteNumber(value);
    if (n != null) {
      return n;
    }
  }
  return undefined;
}

