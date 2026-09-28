import * as vscode from "vscode";
import { SECRET_KEY } from "../core/types";

export class SecretStore {
  constructor(private readonly secrets: vscode.SecretStorage) {}

  async getSessionToken(): Promise<string | undefined> {
    const token = await this.secrets.get(SECRET_KEY);
    const trimmed = token?.trim();
    return trimmed ? trimmed : undefined;
  }

  async setSessionToken(token: string): Promise<void> {
    await this.secrets.store(SECRET_KEY, token.trim());
  }

  async clearSessionToken(): Promise<void> {
    await this.secrets.delete(SECRET_KEY);
  }
}
