import * as vscode from "vscode";
import { NOTIFICATION_STATE_KEY, SNAPSHOT_STATE_KEY, type UsageSnapshot } from "../core/types";
import type { NotificationState } from "../core/NotificationService";

export class SnapshotStore {
  constructor(private readonly state: vscode.Memento) {}

  load(): UsageSnapshot | undefined {
    const raw = this.state.get<UsageSnapshot>(SNAPSHOT_STATE_KEY);
    if (!raw || typeof raw !== "object") {
      return undefined;
    }
    return { ...raw, freshness: "cached" };
  }

  async save(snapshot: UsageSnapshot): Promise<void> {
    const stored: UsageSnapshot = {
      ...snapshot,
      freshness: snapshot.freshness === "unauthenticated" ? snapshot.freshness : "cached",
    };
    await this.state.update(SNAPSHOT_STATE_KEY, stored);
  }

  async clear(): Promise<void> {
    await this.state.update(SNAPSHOT_STATE_KEY, undefined);
  }
}

export class NotificationStore {
  constructor(private readonly state: vscode.Memento) {}

  load(): NotificationState | undefined {
    return this.state.get<NotificationState>(NOTIFICATION_STATE_KEY);
  }

  async save(next: NotificationState): Promise<void> {
    await this.state.update(NOTIFICATION_STATE_KEY, next);
  }

  async clear(): Promise<void> {
    await this.state.update(NOTIFICATION_STATE_KEY, undefined);
  }
}
