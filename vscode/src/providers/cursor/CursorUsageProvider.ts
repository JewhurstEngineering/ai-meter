import type { UsageProvider, UsageSnapshot } from "../../core/types";
import { CursorApiClient, PersonalApiError } from "./CursorApiClient";
import { mapCursorSnapshot } from "./CursorNormalizer";
import { SessionAuthError } from "./SessionCookie";

export class UnauthenticatedError extends Error {
  constructor() {
    super("Not signed in to Cursor");
    this.name = "UnauthenticatedError";
  }
}

export class CursorUsageProvider implements UsageProvider {
  readonly id = "cursor" as const;

  constructor(
    private readonly getToken: () => Promise<string | undefined>,
    private readonly client = new CursorApiClient()
  ) {}

  async refresh(): Promise<UsageSnapshot> {
    const token = await this.getToken();
    if (!token) {
      throw new UnauthenticatedError();
    }
    try {
      const payload = await this.client.fetchUsage(token);
      return mapCursorSnapshot({
        summary: payload.summary,
        stripe: payload.stripe,
        aggregated: payload.aggregated,
        sand: payload.sand,
        freshness: "live",
      });
    } catch (error) {
      if (error instanceof SessionAuthError) {
        throw new UnauthenticatedError();
      }
      throw error;
    }
  }
}

export function isKeepLastError(error: unknown): boolean {
  return error instanceof PersonalApiError && error.keepsLastNumbers;
}

export function isUnauthorizedError(error: unknown): boolean {
  return (
    error instanceof UnauthenticatedError ||
    (error instanceof PersonalApiError && error.kind === "unauthorized")
  );
}

export function errorMessage(error: unknown): string {
  if (error instanceof PersonalApiError) {
    return error.userMessage;
  }
  if (error instanceof UnauthenticatedError) {
    return "Sign in with a Cursor session token.";
  }
  if (error instanceof Error) {
    return error.message;
  }
  return "Usage refresh failed.";
}
