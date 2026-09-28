import type { UsageProvider, UsageSnapshot } from "./types";
import type { Logger } from "../utils/logger";

export class UsageService {
  private inFlight: Promise<UsageSnapshot> | undefined;

  constructor(
    private readonly getProvider: () => UsageProvider,
    private readonly logger: Logger
  ) {}

  async refresh(): Promise<UsageSnapshot> {
    if (this.inFlight) {
      return this.inFlight;
    }
    this.inFlight = this.run();
    try {
      return await this.inFlight;
    } finally {
      this.inFlight = undefined;
    }
  }

  private async run(): Promise<UsageSnapshot> {
    const provider = this.getProvider();
    this.logger.info(`Refreshing usage via ${provider.id}`);
    const snapshot = await provider.refresh();
    this.logger.info(
      `Refresh ${snapshot.freshness} source=${snapshot.dataSource} pools=${poolCount(snapshot)}`
    );
    return snapshot;
  }
}

function poolCount(snapshot: UsageSnapshot): number {
  return [
    snapshot.cursorModelsPercentUsed,
    snapshot.otherModelsPercentUsed,
    snapshot.totalPercentUsed,
    snapshot.grokBotPercentUsed,
  ].filter((value) => value != null).length;
}
