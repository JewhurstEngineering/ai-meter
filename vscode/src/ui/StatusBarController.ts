import * as vscode from "vscode";
import type { MeterConfiguration, UsageSnapshot } from "../core/types";
import {
  formatPercent,
  formatResetDate,
  formatUsdFromCents,
  highestPoolPercent,
  relativeTime,
  statusBarText,
} from "../utils/formatting";

export class StatusBarController {
  private readonly item: vscode.StatusBarItem;

  constructor() {
    this.item = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    this.item.command = { command: "aiMeter.signIn", title: "Use This Cursor Login" };
    this.item.name = "AI Meter";
    this.item.tooltip = "Click to connect from this Cursor login";
  }

  dispose(): void {
    this.item.dispose();
  }

  render(snapshot: UsageSnapshot | undefined, config: MeterConfiguration): void {
    if (!config.statusBarEnabled) {
      this.item.hide();
      return;
    }

    this.item.text = `$(dashboard) ${statusBarText(snapshot, config.statusBar)}`;
    this.item.tooltip = tooltip(snapshot);
    this.item.backgroundColor = background(snapshot, config);
    this.item.command = needsSignIn(snapshot)
      ? { command: "aiMeter.signIn", title: "Use This Cursor Login" }
      : { command: "aiMeter.open", title: "Open AI Meter" };
    this.item.show();
  }
}

function tooltip(snapshot: UsageSnapshot | undefined): vscode.MarkdownString {
  const md = new vscode.MarkdownString();
  md.isTrusted = false;
  if (!snapshot) {
    md.appendMarkdown("**AI Meter**\n\nClick to sign in and paste a Cursor session token.");
    return md;
  }
  const lines = [
    `**${snapshot.planDisplayName}**`,
    "",
    `Cursor Models: ${orDash(snapshot.cursorModelsPercentUsed)}`,
    `Other Models: ${orDash(snapshot.otherModelsPercentUsed)}`,
    `Total included: ${orDash(snapshot.totalPercentUsed)}`,
    ...(snapshot.grokBotPercentUsed == null
      ? []
      : [`Grok Bot: ${formatPercent(snapshot.grokBotPercentUsed)}${grokReset(snapshot.grokBotResetsAt)}`]),
    `On-Demand: ${formatUsdFromCents(snapshot.onDemandUsedCents)}`,
    `Reset: ${formatResetDate(snapshot.billingCycleEnd)}`,
    "",
    `_Updated ${relativeTime(snapshot.fetchedAt)}_`,
  ];
  if (snapshot.freshness === "stale") {
    lines.push("_Data may be stale._");
  }
  md.appendMarkdown(lines.join("\n"));
  return md;
}

function needsSignIn(snapshot: UsageSnapshot | undefined): boolean {
  return !snapshot || snapshot.freshness === "unauthenticated";
}

function grokReset(iso: string | undefined): string {
  const label = formatResetDate(iso);
  return label === "—" ? "" : ` · resets ${label}`;
}

function orDash(percent: number | undefined): string {
  return percent == null ? "—" : formatPercent(percent);
}

function background(
  snapshot: UsageSnapshot | undefined,
  config: MeterConfiguration
): vscode.ThemeColor | undefined {
  if (!snapshot) {
    return undefined;
  }
  const percent = highestPoolPercent(snapshot);
  if (percent == null) {
    return undefined;
  }
  if (percent >= config.criticalPercent) {
    return new vscode.ThemeColor("statusBarItem.errorBackground");
  }
  if (percent >= config.warningPercent) {
    return new vscode.ThemeColor("statusBarItem.warningBackground");
  }
  return undefined;
}
