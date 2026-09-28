import { readFileSync } from "node:fs";
import { join } from "node:path";
import type { UsageProvider, UsageSnapshot } from "../../core/types";
import type {
  AggregatedUsageResponse,
  AuthStripeResponse,
  SandUsageStatus,
  UsageSummaryResponse,
} from "./CursorTypes";
import { mapCursorSnapshot } from "./CursorNormalizer";

export class FixtureUsageProvider implements UsageProvider {
  readonly id = "fixture" as const;

  constructor(private readonly fixturesDir: string) {}

  async refresh(): Promise<UsageSnapshot> {
    const summary = readJson<UsageSummaryResponse>(this.fixturesDir, "usage_summary_mock.json");
    const stripe = readJson<AuthStripeResponse>(this.fixturesDir, "auth_stripe_ultra.json");
    const aggregated = readJson<AggregatedUsageResponse>(
      this.fixturesDir,
      "aggregated_usage_ultra.json"
    );
    const sand = readJson<SandUsageStatus>(this.fixturesDir, "sand_usage_mock.json");
    const snapshot = mapCursorSnapshot({
      summary,
      stripe,
      aggregated,
      sand,
      freshness: "live",
    });
    snapshot.provider = "fixture";
    snapshot.dataSource = "mock";
    return snapshot;
  }
}

function readJson<T>(dir: string, name: string): T {
  const text = readFileSync(join(dir, name), "utf8");
  return JSON.parse(text) as T;
}
