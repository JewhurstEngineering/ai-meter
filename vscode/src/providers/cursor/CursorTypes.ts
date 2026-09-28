/** Loose DTOs for Cursor dashboard endpoints verified in AIMeterCore. */

export interface AuthMeResponse {
  email?: string;
  name?: string;
  sub?: string;
  id?: number;
}

export interface UsageSummaryResponse {
  billingCycleStart?: string;
  billingCycleEnd?: string;
  membershipType?: string;
  autoModelSelectedDisplayMessage?: string;
  namedModelSelectedDisplayMessage?: string;
  individualUsage?: {
    plan?: PlanUsage;
    onDemand?: OnDemandUsage;
  };
}

export interface PlanUsage {
  enabled?: boolean;
  used?: number;
  limit?: number;
  remaining?: number;
  breakdown?: {
    included?: number;
    bonus?: number;
    total?: number;
  };
  autoPercentUsed?: number;
  apiPercentUsed?: number;
  totalPercentUsed?: number;
  cursorModelsPercentUsed?: number;
  firstPartyPercentUsed?: number;
  apiModelsPercentUsed?: number;
  otherModelsPercentUsed?: number;
}

/** Cursor calls Grok Bot "Sand". Weekly allowance, separate from the billing-cycle pools. */
export interface SandUsageStatus {
  usagePercent?: number | string;
  hasNonZeroIncludedLimit?: boolean;
  includedLimitZero?: boolean;
  usesPooledEnterpriseAllowance?: boolean;
  nextResetTimestampUtc?: string | number;
  nextResetTimestamp?: string | number;
  grokPlanLabel?: string;
}

export interface OnDemandUsage {
  enabled?: boolean;
  used?: number;
  limit?: number | null;
  remaining?: number | null;
}

export interface AuthStripeResponse {
  membershipType?: string;
  subscriptionStatus?: string;
  individualMembershipType?: string;
  lastPaymentFailed?: boolean;
  pendingCancellationDate?: string | null;
  isYearlyPlan?: boolean;
  customerBalance?: number;
  isOnStudentPlan?: boolean;
  isTeamMember?: boolean;
}

export interface AggregatedUsageResponse {
  aggregations?: AggregationRow[];
  totalCostCents?: number;
  totalInputTokens?: unknown;
  totalOutputTokens?: unknown;
  totalCacheWriteTokens?: unknown;
  totalCacheReadTokens?: unknown;
}

export interface AggregationRow {
  modelIntent?: string;
  totalCents?: number;
  tier?: number;
  inputTokens?: unknown;
  outputTokens?: unknown;
  cacheWriteTokens?: unknown;
  cacheReadTokens?: unknown;
}

export function parseFlexibleInt(value: unknown): number | undefined {
  if (value == null) {
    return undefined;
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.round(value);
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? Math.round(parsed) : undefined;
  }
  return undefined;
}
