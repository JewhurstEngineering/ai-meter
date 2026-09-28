import * as vscode from "vscode";
import { sanitize } from "./sanitize";

export class Logger {
  private readonly channel: vscode.OutputChannel;

  constructor(channel: vscode.OutputChannel) {
    this.channel = channel;
  }

  info(message: string): void {
    this.channel.appendLine(`[info] ${sanitize(message)}`);
  }

  warn(message: string): void {
    this.channel.appendLine(`[warn] ${sanitize(message)}`);
  }

  error(message: string): void {
    this.channel.appendLine(`[error] ${sanitize(message)}`);
  }

  show(): void {
    this.channel.show(true);
  }
}
