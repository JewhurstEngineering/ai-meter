import * as vscode from "vscode";
import type { MeterConfiguration } from "./types";

export class ConfigurationService {
  read(): MeterConfiguration {
    const config = vscode.workspace.getConfiguration("aiMeter");
    return {
      refreshIntervalMinutes: clamp(config.get("refreshIntervalMinutes", 5), 1, 60),
      statusBarEnabled: config.get("statusBar.enabled", true),
      statusBar: {
        cursorModels: config.get("statusBar.cursorModels", true),
        otherModels: config.get("statusBar.otherModels", true),
        total: config.get("statusBar.total", true),
        grokBot: config.get("statusBar.grokBot", true),
      },
      notificationsEnabled: config.get("notifications.enabled", true),
      warningPercent: clamp(config.get("notifications.warningPercent", 85), 1, 100),
      criticalPercent: clamp(config.get("notifications.criticalPercent", 95), 1, 100),
      useFixture: config.get("debug.useFixture", false),
    };
  }
}

function clamp(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) {
    return min;
  }
  return Math.min(max, Math.max(min, value));
}
