import { join } from "node:path";
import * as vscode from "vscode";
import { registerCommands, type MeterCommands } from "./commands/registerCommands";
import { ConfigurationService } from "./core/ConfigurationService";
import { evaluateThresholds } from "./core/NotificationService";
import type { MeterConfiguration, UsageProvider, UsageSnapshot } from "./core/types";
import { UsageService } from "./core/UsageService";
import { CursorApiClient } from "./providers/cursor/CursorApiClient";
import { CursorUsageProvider, errorMessage, isKeepLastError, isUnauthorizedError } from "./providers/cursor/CursorUsageProvider";
import { FixtureUsageProvider } from "./providers/cursor/FixtureUsageProvider";
import { readLocalCursorSession } from "./providers/cursor/LocalCursorSession";
import { SecretStore } from "./storage/SecretStore";
import { NotificationStore, SnapshotStore } from "./storage/SnapshotStore";
import { StatusBarController } from "./ui/StatusBarController";
import { UsageTreeProvider } from "./ui/UsageTreeProvider";
import { Logger } from "./utils/logger";

export async function activate(context: vscode.ExtensionContext): Promise<void> {
  const app = new MeterApp(context);
  context.subscriptions.push(app);
  registerCommands(context, app);
  await app.start();
}

export function deactivate(): void {
  // MeterApp.dispose handles timers and UI.
}

export class MeterApp implements MeterCommands, vscode.Disposable {
  private readonly logger: Logger;
  private readonly config: ConfigurationService;
  private readonly secrets: SecretStore;
  private readonly snapshots: SnapshotStore;
  private readonly notifications: NotificationStore;
  private readonly statusBar: StatusBarController;
  private readonly tree: UsageTreeProvider;
  private readonly usage: UsageService;
  private snapshot: UsageSnapshot | undefined;
  private timer: ReturnType<typeof setInterval> | undefined;
  private lastError: string | undefined;

  constructor(private readonly context: vscode.ExtensionContext) {
    const channel = vscode.window.createOutputChannel("AI Meter");
    this.logger = new Logger(channel);
    this.config = new ConfigurationService();
    this.secrets = new SecretStore(context.secrets);
    this.snapshots = new SnapshotStore(context.globalState);
    this.notifications = new NotificationStore(context.globalState);
    this.statusBar = new StatusBarController();
    this.tree = new UsageTreeProvider();
    this.usage = new UsageService(() => this.provider(), this.logger);

    context.subscriptions.push(
      channel,
      this.statusBar,
      vscode.window.registerTreeDataProvider("aiMeter.usage", this.tree),
      vscode.workspace.onDidChangeConfiguration((event) => {
        if (event.affectsConfiguration("aiMeter")) {
          this.render();
          this.schedule();
        }
      })
    );
  }

  async start(): Promise<void> {
    const cached = this.snapshots.load();
    if (cached) {
      this.snapshot = markStaleIfNeeded(cached, this.config.read());
      this.render();
    } else {
      this.render();
    }
    await this.refresh();
    this.schedule();
  }

  currentSnapshot(): UsageSnapshot | undefined {
    return this.snapshot;
  }

  open(): void {
    void vscode.commands.executeCommand("aiMeter.usage.focus");
  }

  async signIn(): Promise<void> {
    this.logger.info("Sign-in command started");
    const local = await readLocalCursorSession();
    if (local) {
      this.logger.info(`Found local session from ${local.source}`);
      try {
        const me = await new CursorApiClient().validate(local.token);
        await this.secrets.setSessionToken(local.token);
        await this.refresh({ interactive: true });
        const who = me.email ? ` as ${me.email}` : "";
        void vscode.window.showInformationMessage(`Connected from ${local.source}${who}.`);
        return;
      } catch (error) {
        this.logger.warn(`Local session failed: ${errorMessage(error)}`);
      }
    } else {
      this.logger.info("No local Cursor session found");
    }

    const fallback = await vscode.window.showInformationMessage(
      local
        ? "The Cursor login on this Mac didn't work. Paste a token instead?"
        : "Couldn't find a Cursor login on this Mac. Paste a token?",
      { modal: true },
      "Paste token"
    );
    if (fallback === "Paste token") {
      await this.pasteToken();
    }
  }

  async pasteToken(): Promise<void> {
    const token = await vscode.window.showInputBox({
      title: "Cursor session token",
      prompt: "Paste a WorkosCursorSessionToken cookie or a session JWT, then press Enter",
      ignoreFocusOut: true,
      placeHolder: "eyJ... or userId::eyJ...",
    });
    if (!token?.trim()) {
      void vscode.window.showWarningMessage("No token pasted. Sign in cancelled.");
      return;
    }
    await this.secrets.setSessionToken(token);
    this.logger.info("Stored pasted Cursor session in Secret Storage");
    await this.refresh({ interactive: true });
  }

  async disconnect(): Promise<void> {
    await this.secrets.clearSessionToken();
    await this.snapshots.clear();
    await this.notifications.clear();
    this.snapshot = undefined;
    this.lastError = undefined;
    this.logger.info("Disconnected Cursor session");
    this.render();
    void vscode.window.showInformationMessage("Disconnected Cursor from AI Meter.");
  }

  showDiagnostics(): void {
    void this.writeDiagnostics();
  }

  private async writeDiagnostics(): Promise<void> {
    const snapshot = this.snapshot;
    const cfg = this.config.read();
    const hasToken = Boolean(await this.secrets.getSessionToken());
    this.logger.info("---- diagnostics ----");
    this.logger.info(`Provider: ${cfg.useFixture ? "fixture" : "cursor"}`);
    this.logger.info(`Authenticated: ${cfg.useFixture ? "fixture" : hasToken ? "yes" : "no"}`);
    this.logger.info(`Transport: ${snapshot?.dataSource ?? "none"}`);
    this.logger.info(`Last refresh: ${snapshot?.freshness ?? "none"}`);
    this.logger.info(
      `Pools returned: ${
        snapshot
          ? [
              snapshot.cursorModelsPercentUsed,
              snapshot.otherModelsPercentUsed,
              snapshot.totalPercentUsed,
              snapshot.grokBotPercentUsed,
            ].filter(
              (value) => value != null
            ).length
          : 0
      }`
    );
    this.logger.info(`Extension version: ${this.context.extension.packageJSON.version as string}`);
    if (this.lastError) {
      this.logger.warn(`Last error: ${this.lastError}`);
    }
    this.logger.show();
  }

  async refresh(options: { interactive?: boolean } = {}): Promise<void> {
    const cfg = this.config.read();
    try {
      const next = await this.usage.refresh();
      this.snapshot = next;
      this.lastError = undefined;
      await this.snapshots.save(next);
      await this.notifyIfNeeded(next, cfg);
      this.render();
    } catch (error) {
      this.lastError = errorMessage(error);
      this.logger.warn(this.lastError);
      if (isUnauthorizedError(error)) {
        if (this.snapshot) {
          this.snapshot = { ...this.snapshot, freshness: "unauthenticated" };
        }
        this.render();
        if (options.interactive) {
          const action = await vscode.window.showWarningMessage(
            "Cursor session expired or missing. Sign in again?",
            "Sign In"
          );
          if (action === "Sign In") {
            await this.signIn();
          }
        }
        return;
      }
      if (this.snapshot && isKeepLastError(error)) {
        this.snapshot = { ...this.snapshot, freshness: "stale" };
        this.render();
        return;
      }
      if (this.snapshot) {
        this.snapshot = { ...this.snapshot, freshness: "stale" };
        this.render();
      }
      if (options.interactive) {
        void vscode.window.showErrorMessage(this.lastError);
      }
    }
  }

  dispose(): void {
    if (this.timer) {
      clearInterval(this.timer);
    }
    this.statusBar.dispose();
  }

  private provider(): UsageProvider {
    const cfg = this.config.read();
    if (cfg.useFixture) {
      return new FixtureUsageProvider(join(this.context.extensionPath, "fixtures", "cursor"));
    }
    return new CursorUsageProvider(() => this.secrets.getSessionToken());
  }

  private render(): void {
    const cfg = this.config.read();
    const signedIn = Boolean(this.snapshot && this.snapshot.freshness !== "unauthenticated");
    void vscode.commands.executeCommand("setContext", "aiMeter.signedIn", signedIn);
    this.statusBar.render(this.snapshot, cfg);
    this.tree.setSnapshot(this.snapshot);
  }

  private schedule(): void {
    if (this.timer) {
      clearInterval(this.timer);
    }
    const minutes = this.config.read().refreshIntervalMinutes;
    this.timer = setInterval(() => {
      void this.refresh();
    }, minutes * 60_000);
  }

  private async notifyIfNeeded(snapshot: UsageSnapshot, cfg: MeterConfiguration): Promise<void> {
    if (!cfg.notificationsEnabled || snapshot.dataSource === "mock") {
      return;
    }
    const { crossings, nextState } = evaluateThresholds(snapshot, cfg, this.notifications.load());
    await this.notifications.save(nextState);
    for (const crossing of crossings) {
      if (crossing.level === "critical") {
        void vscode.window.showErrorMessage(crossing.message);
      } else {
        void vscode.window.showWarningMessage(crossing.message);
      }
    }
  }
}

function markStaleIfNeeded(snapshot: UsageSnapshot, cfg: MeterConfiguration): UsageSnapshot {
  const fetched = Date.parse(snapshot.fetchedAt);
  if (Number.isNaN(fetched)) {
    return snapshot;
  }
  const maxAgeMs = cfg.refreshIntervalMinutes * 60_000 * 2;
  if (Date.now() - fetched > maxAgeMs) {
    return { ...snapshot, freshness: "stale" };
  }
  return snapshot;
}
