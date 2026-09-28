import type { MeterConfiguration, UsageSnapshot } from "./types";
import { formatPercent } from "../utils/formatting";

export type ThresholdLevel = "warning" | "critical";

export interface ThresholdCrossing {
  pool: string;
  level: ThresholdLevel;
  percent: number;
  message: string;
}

export interface NotificationState {
  cycleKey: string;
  fired: string[];
}

export function cycleKey(snapshot: UsageSnapshot): string {
  return snapshot.billingCycleEnd ?? snapshot.billingCycleStart ?? "unknown-cycle";
}

export function evaluateThresholds(
  snapshot: UsageSnapshot,
  config: MeterConfiguration,
  state: NotificationState | undefined
): { crossings: ThresholdCrossing[]; nextState: NotificationState } {
  const nextCycle = cycleKey(snapshot);
  const fired = state?.cycleKey === nextCycle ? [...state.fired] : [];
  const crossings: ThresholdCrossing[] = [];

  const pools: Array<{ id: string; label: string; percent?: number }> = [
    { id: "cursorModels", label: "Cursor Models", percent: snapshot.cursorModelsPercentUsed },
    { id: "otherModels", label: "Other Models", percent: snapshot.otherModelsPercentUsed },
    { id: "total", label: "Total included", percent: snapshot.totalPercentUsed },
    { id: "grokBot", label: "Grok Bot", percent: snapshot.grokBotPercentUsed },
  ];

  for (const pool of pools) {
    if (pool.percent == null || !Number.isFinite(pool.percent)) {
      continue;
    }
    const level = levelFor(pool.percent, config);
    if (!level) {
      continue;
    }
    const key = `${pool.id}:${level}`;
    if (fired.includes(key)) {
      continue;
    }
    fired.push(key);
    crossings.push({
      pool: pool.id,
      level,
      percent: pool.percent,
      message: `${pool.label} usage reached ${formatPercent(pool.percent)}.`,
    });
  }

  return { crossings, nextState: { cycleKey: nextCycle, fired } };
}

function levelFor(percent: number, config: MeterConfiguration): ThresholdLevel | undefined {
  if (percent >= config.criticalPercent) {
    return "critical";
  }
  if (percent >= config.warningPercent) {
    return "warning";
  }
  return undefined;
}
