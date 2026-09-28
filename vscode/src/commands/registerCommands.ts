import * as vscode from "vscode";
import type { UsageSnapshot } from "../core/types";
import { DASHBOARD_URL } from "../core/types";
import { copySummary } from "../utils/formatting";

export interface MeterCommands {
  open(): void;
  refresh(options?: { interactive?: boolean }): Promise<void>;
  signIn(): Promise<void>;
  pasteToken(): Promise<void>;
  disconnect(): Promise<void>;
  currentSnapshot(): UsageSnapshot | undefined;
  showDiagnostics(): void;
}

export function registerCommands(context: vscode.ExtensionContext, app: MeterCommands): void {
  context.subscriptions.push(
    vscode.commands.registerCommand("aiMeter.open", () => app.open()),
    vscode.commands.registerCommand("aiMeter.refresh", () => app.refresh({ interactive: true })),
    vscode.commands.registerCommand("aiMeter.signIn", async () => {
      try {
        await app.signIn();
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        void vscode.window.showErrorMessage(`AI Meter sign-in failed: ${message}`);
      }
    }),
    vscode.commands.registerCommand("aiMeter.pasteToken", async () => {
      try {
        await app.pasteToken();
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        void vscode.window.showErrorMessage(`AI Meter paste failed: ${message}`);
      }
    }),
    vscode.commands.registerCommand("aiMeter.openSettings", async () => {
      try {
        const config = vscode.workspace.getConfiguration("aiMeter");
        const options: Array<vscode.QuickPickItem & { key: string }> = [
          {
            label: "Cursor Models",
            description: "Show Cursor pool on the status bar",
            picked: config.get("statusBar.cursorModels", true),
            key: "statusBar.cursorModels",
          },
          {
            label: "Other Models",
            description: "Show Other pool on the status bar",
            picked: config.get("statusBar.otherModels", true),
            key: "statusBar.otherModels",
          },
          {
            label: "Total included",
            description: "Show Total pool on the status bar",
            picked: config.get("statusBar.total", true),
            key: "statusBar.total",
          },
          {
            label: "Grok Bot",
            description: "Show Grok Bot weekly allowance when the plan includes it",
            picked: config.get("statusBar.grokBot", true),
            key: "statusBar.grokBot",
          },
        ];
        const selected = await vscode.window.showQuickPick(options, {
          title: "AI Meter status bar",
          canPickMany: true,
          ignoreFocusOut: true,
          placeHolder: "Toggle which percents appear in the status bar",
        });
        if (!selected) {
          return;
        }
        const enabled = new Set(selected.map((item) => item.key));
        for (const option of options) {
          await config.update(option.key, enabled.has(option.key), vscode.ConfigurationTarget.Global);
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        void vscode.window.showErrorMessage(`Couldn’t open settings: ${message}`);
      }
    }),
    vscode.commands.registerCommand("aiMeter.disconnect", () => app.disconnect()),
    vscode.commands.registerCommand("aiMeter.openDashboard", () => {
      void vscode.env.openExternal(vscode.Uri.parse(DASHBOARD_URL));
    }),
    vscode.commands.registerCommand("aiMeter.copySummary", async () => {
      const snapshot = app.currentSnapshot();
      if (!snapshot) {
        void vscode.window.showInformationMessage("No usage data yet. Sign in and refresh.");
        return;
      }
      await vscode.env.clipboard.writeText(copySummary(snapshot));
      void vscode.window.showInformationMessage("Copied usage summary.");
    }),
    vscode.commands.registerCommand("aiMeter.diagnostics", () => app.showDiagnostics())
  );
}
