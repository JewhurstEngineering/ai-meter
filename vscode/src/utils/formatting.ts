import type { StatusBarMetrics, UsageSnapshot } from "../core/types";

export function formatPercent(value: number): string {
  if (!Number.isFinite(value)) {
    return "—";
  }
  return `${Math.round(value)}%`;
}

export function formatUsdFromCents(cents: number | undefined): string {
  if (cents == null || !Number.isFinite(cents)) {
    return "—";
  }
  const dollars = cents / 100;
  if (dollars === Math.floor(dollars)) {
    return `$${dollars.toFixed(0)}`;
  }
  return `$${dollars.toFixed(2)}`;
}

export function highestPoolPercent(snapshot: UsageSnapshot): number | undefined {
  const values = [
    snapshot.cursorModelsPercentUsed,
    snapshot.otherModelsPercentUsed,
    snapshot.totalPercentUsed,
    snapshot.grokBotPercentUsed,
  ].filter((value): value is number => value != null && Number.isFinite(value));
  if (values.length === 0) {
    return undefined;
  }
  return Math.max(...values);
}

export function statusBarText(
  snapshot: UsageSnapshot | undefined,
  metrics: StatusBarMetrics
): string {
  if (!snapshot) {
    return "AI — Sign In";
  }
  if (snapshot.freshness === "unauthenticated") {
    return "AI — Sign In";
  }
  if (snapshot.freshness === "unavailable" && snapshot.cursorModelsPercentUsed == null) {
    return "AI ⚠";
  }

  const parts: string[] = [];
  if (metrics.cursorModels && snapshot.cursorModelsPercentUsed != null) {
    parts.push(`Cursor ${formatPercent(snapshot.cursorModelsPercentUsed)}`);
  }
  if (metrics.otherModels && snapshot.otherModelsPercentUsed != null) {
    parts.push(`Other ${formatPercent(snapshot.otherModelsPercentUsed)}`);
  }
  if (metrics.total && snapshot.totalPercentUsed != null) {
    parts.push(`Total ${formatPercent(snapshot.totalPercentUsed)}`);
  }
  if (metrics.grokBot && snapshot.grokBotPercentUsed != null) {
    parts.push(`Grok ${formatPercent(snapshot.grokBotPercentUsed)}`);
  }

  if (parts.length === 0) {
    const fallback = highestPoolPercent(snapshot);
    if (fallback == null) {
      return snapshot.planDisplayName ? `AI ${snapshot.planDisplayName}` : "AI —";
    }
    parts.push(`AI ${formatPercent(fallback)}`);
  }

  let label = parts.join(" · ");
  if (snapshot.freshness === "stale") {
    label += " · stale";
  }
  return label;
}

export function relativeTime(iso: string | undefined, now = new Date()): string {
  if (!iso) {
    return "unknown";
  }
  const then = new Date(iso);
  if (Number.isNaN(then.getTime())) {
    return "unknown";
  }
  const deltaMs = now.getTime() - then.getTime();
  const abs = Math.abs(deltaMs);
  const minutes = Math.round(abs / 60_000);
  if (minutes < 1) {
    return "just now";
  }
  if (minutes < 60) {
    return `${minutes}m ago`;
  }
  const hours = Math.round(minutes / 60);
  if (hours < 48) {
    return `${hours}h ago`;
  }
  const days = Math.round(hours / 24);
  return `${days}d ago`;
}

export function formatResetDate(iso: string | undefined): string {
  if (!iso) {
    return "—";
  }
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) {
    return "—";
  }
  return date.toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

export function daysUntil(iso: string | undefined, now = new Date()): number | undefined {
  if (!iso) {
    return undefined;
  }
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) {
    return undefined;
  }
  const ms = date.getTime() - now.getTime();
  return Math.max(0, Math.ceil(ms / 86_400_000));
}

export function copySummary(snapshot: UsageSnapshot, now = new Date()): string {
  const reset = formatResetDate(snapshot.billingCycleEnd);
  const lines = [
    `Cursor Usage — ${now.toLocaleDateString(undefined, { month: "short", day: "numeric" })}`,
    "",
    `Cursor Models: ${snapshot.cursorModelsPercentUsed == null ? "—" : formatPercent(snapshot.cursorModelsPercentUsed)}`,
    `Other Models: ${snapshot.otherModelsPercentUsed == null ? "—" : formatPercent(snapshot.otherModelsPercentUsed)}`,
    `Total: ${snapshot.totalPercentUsed == null ? "—" : formatPercent(snapshot.totalPercentUsed)}`,
    ...(snapshot.grokBotPercentUsed == null
      ? []
      : [`Grok Bot: ${formatPercent(snapshot.grokBotPercentUsed)}`]),
    `On-Demand: ${formatUsdFromCents(snapshot.onDemandUsedCents)}`,
    `Reset: ${reset}`,
    "",
    "via JamesWare AI Meter",
  ];
  return lines.join("\n");
}

export function planDisplayName(membershipType: string): string {
  switch (membershipType.toLowerCase()) {
    case "free":
      return "Free";
    case "pro":
      return "Pro";
    case "pro_plus":
    case "pro+":
    case "proplus":
      return "Pro+";
    case "ultra":
      return "Ultra";
    default:
      return "Cursor";
  }
}
