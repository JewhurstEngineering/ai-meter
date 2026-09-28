import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export interface LocalCursorSession {
  token: string;
  source: "Cursor IDE" | "Cursor Agent keychain";
}

const READ_TOKEN_PY = `
import sqlite3, sys
path = sys.argv[1]
con = sqlite3.connect("file:" + path + "?mode=ro", uri=True)
row = con.execute("SELECT value FROM ItemTable WHERE key = ?", ("cursorAuth/accessToken",)).fetchone()
sys.stdout.write(row[0] if row and row[0] else "")
`.trim();

export function cursorStateDbPath(platform = process.platform, home = homedir(), appData = process.env.APPDATA): string {
  if (platform === "darwin") {
    return join(home, "Library/Application Support/Cursor/User/globalStorage/state.vscdb");
  }
  if (platform === "win32") {
    return join(appData || home, "Cursor/User/globalStorage/state.vscdb");
  }
  return join(home, ".config/Cursor/User/globalStorage/state.vscdb");
}

export async function readLocalCursorSession(): Promise<LocalCursorSession | undefined> {
  const fromIde = await readIdeAccessToken(cursorStateDbPath());
  if (fromIde) {
    return { token: fromIde, source: "Cursor IDE" };
  }
  if (process.platform === "darwin") {
    const fromAgent = await readAgentKeychainToken();
    if (fromAgent) {
      return { token: fromAgent, source: "Cursor Agent keychain" };
    }
  }
  return undefined;
}

async function readIdeAccessToken(dbPath: string): Promise<string | undefined> {
  if (!existsSync(dbPath)) {
    return undefined;
  }
  for (const bin of ["python3", "python"]) {
    try {
      const { stdout } = await execFileAsync(bin, ["-c", READ_TOKEN_PY, dbPath], {
        timeout: 8000,
        windowsHide: true,
      });
      const token = stdout.trim();
      if (token) {
        return token;
      }
    } catch {
      continue;
    }
  }
  return undefined;
}

async function readAgentKeychainToken(): Promise<string | undefined> {
  try {
    const { stdout } = await execFileAsync(
      "security",
      ["find-generic-password", "-s", "cursor-access-token", "-w"],
      { timeout: 15_000 }
    );
    const token = stdout.trim();
    return token || undefined;
  } catch {
    return undefined;
  }
}
