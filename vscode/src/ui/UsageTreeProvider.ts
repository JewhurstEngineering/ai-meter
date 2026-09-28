import * as vscode from "vscode";
import type { UsageSnapshot } from "../core/types";
import {
  formatPercent,
  formatResetDate,
  formatUsdFromCents,
  relativeTime,
} from "../utils/formatting";

type TreeNode = vscode.TreeItem & { children?: TreeNode[] };

export class UsageTreeProvider implements vscode.TreeDataProvider<TreeNode> {
  private snapshot: UsageSnapshot | undefined;
  private readonly onDidChange = new vscode.EventEmitter<void>();
  readonly onDidChangeTreeData = this.onDidChange.event;

  setSnapshot(snapshot: UsageSnapshot | undefined): void {
    this.snapshot = snapshot;
    this.onDidChange.fire();
  }

  getTreeItem(element: TreeNode): vscode.TreeItem {
    return element;
  }

  getChildren(element?: TreeNode): TreeNode[] {
    if (element) {
      return element.children ?? [];
    }
    return this.root();
  }

  private root(): TreeNode[] {
    const snapshot = this.snapshot;
    if (!snapshot || snapshot.freshness === "unauthenticated") {
      return [connectLeaf(), pasteLeaf()];
    }

    const pools = [
      leaf("Cursor Models", orDash(snapshot.cursorModelsPercentUsed)),
      leaf("Other Models", orDash(snapshot.otherModelsPercentUsed)),
      leaf("Total included", orDash(snapshot.totalPercentUsed)),
    ];
    if (snapshot.grokBotPercentUsed != null) {
      const reset = formatResetDate(snapshot.grokBotResetsAt);
      const value = formatPercent(snapshot.grokBotPercentUsed);
      pools.push(leaf("Grok Bot", reset === "—" ? value : `${value} · resets ${reset}`));
    }
    pools.push(
      leaf("On-Demand", formatUsdFromCents(snapshot.onDemandUsedCents)),
      leaf("Reset", formatResetDate(snapshot.billingCycleEnd))
    );
    const cursor = section("CURSOR", pools);

    const account = section("ACCOUNT", [
      leaf("Plan", snapshot.planDisplayName),
      leaf("Updated", relativeTime(snapshot.fetchedAt)),
      leaf("Source", snapshot.dataSource === "mock" ? "fixture (debug)" : snapshot.dataSource),
      settingsLeaf(),
    ]);

    const models = snapshot.modelBreakdown.slice(0, 8).map((row) =>
      leaf(row.model, formatUsdFromCents(row.totalCents))
    );

    const nodes = [cursor, account];
    if (models.length > 0) {
      nodes.push(section("MODELS THIS PERIOD", models));
    }
    if (snapshot.freshness === "stale") {
      nodes.unshift(leaf("Stale", "Last known numbers — refresh failed or you are offline"));
    }
    return nodes;
  }
}

function section(label: string, children: TreeNode[]): TreeNode {
  const item = new vscode.TreeItem(label, vscode.TreeItemCollapsibleState.Expanded) as TreeNode;
  item.children = children;
  return item;
}

function connectLeaf(): TreeNode {
  const item = new vscode.TreeItem("Use this Cursor login", vscode.TreeItemCollapsibleState.None) as TreeNode;
  item.description = "One click — no token hunting";
  item.tooltip = "Read the session already stored by Cursor on this Mac";
  item.iconPath = new vscode.ThemeIcon("sign-in");
  item.command = { command: "aiMeter.signIn", title: "Use This Cursor Login" };
  return item;
}

function pasteLeaf(): TreeNode {
  const item = new vscode.TreeItem("Paste a token instead", vscode.TreeItemCollapsibleState.None) as TreeNode;
  item.description = "Escape hatch";
  item.iconPath = new vscode.ThemeIcon("key");
  item.command = { command: "aiMeter.pasteToken", title: "Paste Token" };
  return item;
}

function settingsLeaf(): TreeNode {
  const item = new vscode.TreeItem("Status bar metrics", vscode.TreeItemCollapsibleState.None) as TreeNode;
  item.description = "Status bar metrics";
  item.iconPath = new vscode.ThemeIcon("list-flat");
  item.command = { command: "aiMeter.openSettings", title: "Status Bar Metrics" };
  return item;
}

function leaf(label: string, description: string): TreeNode {
  const item = new vscode.TreeItem(label, vscode.TreeItemCollapsibleState.None) as TreeNode;
  item.description = description;
  return item;
}

function orDash(percent: number | undefined): string {
  return percent == null ? "—" : formatPercent(percent);
}
