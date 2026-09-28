export type ProviderId = "cursor" | "fixture";

export type Freshness = "live" | "cached" | "stale" | "unavailable" | "unauthenticated";

export interface ModelCost {
  model: string;
  totalCents: number;
  tier?: number;
  inputTokens?: number;
  outputTokens?: number;
  cacheWriteTokens?: number;
  cacheReadTokens?: number;
}

export interface UsageSnapshot {
  fetchedAt: string;
  provider: ProviderId;
  membershipType: string;
  planDisplayName: string;
  billingCycleStart?: string;
  billingCycleEnd?: string;
  cursorModelsPercentUsed?: number;
  otherModelsPercentUsed?: number;
  totalPercentUsed?: number;
  /** Grok Bot weekly allowance. Absent when the plan does not include one. */
  grokBotPercentUsed?: number;
  grokBotResetsAt?: string;
  planUsedCents?: number;
  planLimitCents?: number;
  planRemainingCents?: number;
  includedCents?: number;
  bonusCents?: number;
  onDemandEnabled: boolean;
  onDemandUsedCents?: number;
  onDemandLimitCents?: number;
  modelBreakdown: ModelCost[];
  totalModelCostCents?: number;
  displayMessages: {
    cursorModels?: string;
    otherModels?: string;
  };
  freshness: Freshness;
  dataSource: "cursor-dashboard-api" | "mock";
}

export interface UsageProvider {
  readonly id: ProviderId;
  refresh(): Promise<UsageSnapshot>;
}

export interface StatusBarMetrics {
  cursorModels: boolean;
  otherModels: boolean;
  total: boolean;
  grokBot: boolean;
}

export interface MeterConfiguration {
  refreshIntervalMinutes: number;
  statusBarEnabled: boolean;
  statusBar: StatusBarMetrics;
  notificationsEnabled: boolean;
  warningPercent: number;
  criticalPercent: number;
  useFixture: boolean;
}

export const SECRET_KEY = "aiMeter.cursor.sessionToken";
export const SNAPSHOT_STATE_KEY = "aiMeter.lastSnapshot";
export const NOTIFICATION_STATE_KEY = "aiMeter.notificationState";
export const DASHBOARD_URL = "https://cursor.com/dashboard?tab=usage";
